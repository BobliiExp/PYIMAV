//
//  PYIMVideoController.m
//  PYIMAV
//
//  Created by 002 on 2018/5/16.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYIMVideoController.h"
#import "PYIMQueue.h"
#import "PYIMVideoConverter.h"

typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);

static NSInteger kAudioPlayerRequireEmptyTimes = 0; /// 如果有语音重置为0，否则递增，当达到50*5（每秒50个包）时视作对方下线

/**
 同步方案：
 1.连接成功时间（毫秒）记录为数据开始时间，此时间点最近出来的音视频数据相对此时间计算同步差值
 2.采集时记录采集开始与结束的时间戳，精确到毫秒
 3.接收方接收后进行缓冲，音视频任何一方出现无数据播放情况，立刻停止对方播放（即出现卡顿），待缓冲到一定数据后（双方都达到最低缓冲要求），启动播放
 4.接收方播放数据根据即将播放数据的起止时间节点，判断语音与视频播放的同步间隔时间（通过停止、恢复控制同步）
 5.接收方一旦建立连接，音视频都达到缓冲要求后，进入准备播放阶段（此阶段为处理同步时间差）
 
 **.创建播放子线程，并且开启runloop，控制循环播放流程
 
 */
@interface PYIMVideoController() <AVCaptureVideoDataOutputSampleBufferDelegate> {
    dispatch_queue_t queueOutput;
    
    AVCaptureSession *session;
    AVCaptureConnection* connection;
    
    AVCaptureDevice *cameraDeviceB;     // 后置
    AVCaptureDevice *cameraDeviceF;     // 前置
    BOOL cameraFront;
    
    // 缓冲起来避免每次充值session
    AVCaptureDeviceInput *input; // 录制输入设备
    AVCaptureVideoDataOutput *output; // 播放接收数据
    
    PYIMQueue *queueRec;
    
    dispatch_queue_t queuePlayer;
    
    NSThread *threadRender;
    NSTimer *timerRender;
}



#pragma mark - 如果要切换视频展示layer，只需要将layer添加到对应view上就行，其他不用动；layer的frame受外部控制
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *recordLayer; ///< 本地摄像头预览
@property (nonatomic, strong) STMGLView *viewPlay; ///< 展示接收数据
@property (nonatomic, weak) UIView *viewbg, *viewfront;
@property (nonatomic, copy) void(^recordEnd)(PYIMModeVideo* mdeia);    ///< 录制视频回调
@property (nonatomic, copy) void(^playEnd)(PYIMMediaState state);
@property (nonatomic, assign) PYIMMediaState state;
@property (weak, nonatomic) UIImageView *focusCursor; //聚焦光标

@end

/**
 android 默认配置
 public static int initial_width = 320;// 320;//192;//144;//176;
 public static int initial_height = 240;// 240;//240;//192;//144;
 public static int width = initial_width;
 public static int height = initial_height;
 public static int format = PixelFormat.UNKNOWN; // 后面转向通用编码NV21
 public static int nInFPS = 8;
 public static int bitrate = 128;
 */

@implementation PYIMVideoController

- (instancetype)initWithBGView:(UIView*)viewbg front:(UIView*)viewfront {
    self = [super init];
    if(self){
        _viewbg = viewbg;
        // 初始化 focusCursor 添加到viewbg中
        
        _viewfront = viewfront;
        queueOutput = dispatch_queue_create("PYIMVideoController", DISPATCH_QUEUE_SERIAL); // 串行，逐个获取
        queuePlayer = dispatch_queue_create("videoplay", DISPATCH_QUEUE_CONCURRENT); // 控制视频播放的queue，顺序播放，采用semaphore控制
        
        queueRec = [[PYIMQueue alloc] initWithCapcity:5];
        cameraFront = YES;
        
        [self setupCaptureSession];
        [self setupCamera];
        [session startRunning];
    }
    
    return self;
}

- (void)adjustDisplay {
    _recordLayer.frame = _viewbg.layer.bounds;
}

- (void)setupCaptureSession {
    // 获取摄像头，默认前置摄像头
    NSArray *cameraDevice = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in cameraDevice) {
        if (device.position == AVCaptureDevicePositionFront) {
            cameraDeviceF = device;
        }else if(device.position == AVCaptureDevicePositionBack) {
            cameraDeviceB = device;
        }
    }
    
    // 创建session， 配置分辨率（bitrate）
    session = [[AVCaptureSession alloc] init];
    if([session canSetSessionPreset:AVCaptureSessionPreset640x480])
        [session setSessionPreset:AVCaptureSessionPreset640x480];
    
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone){
//        if([session canSetSessionPreset:AVCaptureSessionPreset640x480])
//            [session setSessionPreset:AVCaptureSessionPreset640x480];
//    } else {
//        if([session canSetSessionPreset:AVCaptureSessionPresetPhoto])
//            [session setSessionPreset:AVCaptureSessionPresetPhoto];
//    }
    
    // 创建输出配置
    output = [[AVCaptureVideoDataOutput alloc] init];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* val = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
    output.videoSettings = videoSettings;
    [output setSampleBufferDelegate:self queue:queueOutput];
    
    // 关联输出与展示
    connection = [output connectionWithMediaType:AVMediaTypeVideo];
    if ([session canAddOutput:output]) {
        [session addOutput:output];
    }
    
    // 本地预览layer
    _recordLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    [_recordLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    _recordLayer.frame = [[UIScreen mainScreen] bounds];
    [self.viewbg.layer addSublayer:_recordLayer];
    
    // 接收播放layer
    CGFloat width = MAX(CGRectGetWidth(self.viewfront.bounds), CGRectGetHeight(self.viewfront.bounds));
    _viewPlay = [[STMGLView alloc] initWithFrame:CGRectMake(-(width-CGRectGetWidth(_viewfront.bounds))/2, -(width-CGRectGetHeight(_viewfront.bounds))/2, width, width) videoFrameSize:CGSizeMake(ENCODE_FRMAE_WIDTH, ENCODE_FRMAE_HEIGHT) videoFrameFormat:STMVideoFrameFormatYUV];
    _viewPlay.layer.borderWidth = 3;
    _viewPlay.layer.borderColor = [UIColor blueColor].CGColor;
    [self.viewfront addSubview:_viewPlay];
}

- (void)setupCamera {
    [session beginConfiguration];
    
    [session removeInput:input];
    NSError *error;
    AVCaptureDeviceInput *temp = [AVCaptureDeviceInput deviceInputWithDevice:cameraFront?cameraDeviceF:cameraDeviceB error:&error];
    if([session canAddInput:temp]){
        [session addInput:temp];
        input = temp;
    }
    
    [session commitConfiguration];
}

/// deprecated 设置视频帧间隔，越大效果越差，采用默认
- (void)setupFPS {
    AVCaptureDeviceFormat *bestFormat = nil;
    AVFrameRateRange *bestFrameRateRange = nil;
    AVCaptureDevice *device = cameraFront?cameraDeviceF:cameraDeviceB;
    
    for ( AVCaptureDeviceFormat *format in [device formats] ) {
        for ( AVFrameRateRange *range in format.videoSupportedFrameRateRanges ) {
            if ( range.maxFrameRate > bestFrameRateRange.maxFrameRate ) {
                bestFormat = format;
                bestFrameRateRange = range;
            }
        }
    }
    if ( bestFormat) {
        if ( [device lockForConfiguration:NULL] == YES ) {
            device.activeFormat = bestFormat;
            device.activeVideoMinFrameDuration = CMTimeMake(1,VIDEO_FPS);
            device.activeVideoMaxFrameDuration = CMTimeMake(1,VIDEO_FPS);
            [device unlockForConfiguration];
        }
    }
}

- (BOOL)isPlaying {
    return self.state == EMediaState_Playing;
}

- (void)setState:(PYIMMediaState)state {
    _state = state;
    
    if(self.playEnd)
        self.playEnd(state);
}
#pragma mark - 相关操作

- (void)switchPlayWindow {
    if([_viewbg.subviews containsObject:_viewPlay]){
        CGFloat width = MAX(CGRectGetWidth(_viewfront.bounds), CGRectGetHeight(_viewfront.bounds));
        _viewPlay.frame = CGRectMake(-(width-CGRectGetWidth(_viewfront.bounds))/2, -(width-CGRectGetHeight(_viewfront.bounds))/2, width, width);
        [_viewfront addSubview:_viewPlay];
        
        _recordLayer.frame = _viewbg.bounds;
        [_viewbg.layer addSublayer:_recordLayer];
    }else {
        CGFloat width = MAX(CGRectGetWidth(_viewbg.bounds), CGRectGetHeight(_viewbg.bounds));
        _viewPlay.frame = CGRectMake(-(width-CGRectGetWidth(_viewbg.bounds))/2, -(width-CGRectGetHeight(_viewbg.bounds))/2, width, width);
        [_viewbg addSubview:_viewPlay];
        
        _recordLayer.frame = _viewfront.bounds;
        [_viewfront.layer addSublayer:_recordLayer];
    }
}

- (void)switchCamera {
    if (session.isRunning) {
        cameraFront = !cameraFront;
        [session stopRunning];
        [self setupCamera];
        [session startRunning];
    }
}

- (void)pause {
    [self pauseUntil:0];
}

- (void)pauseUntil:(NSTimeInterval)timespan {
    self.state = EMediaState_Paused;
}

- (void)resume {
    self.state = EMediaState_Playing;
    
}

- (void)stop {
    self.playEnd = nil;
    self.recordEnd = nil;
    
    self.state = EMediaState_Stoped;
    [session stopRunning];
    
    if(timerRender){
        [timerRender invalidate];
        timerRender = nil;
    }
    
    if(_viewPlay){
        [_viewPlay cleanSelf];
        [_viewPlay removeFromSuperview];
        _viewPlay = nil;
    }
    
    if(_recordLayer){
        [_recordLayer removeFromSuperlayer];
        _recordLayer = nil;
    }
}

- (void)start:(void(^)(PYIMMediaState state))block {
    _state = EMediaState_Playing; // 默认只有收到数据就开始播放
    _playEnd = block;
    
    timerRender = [NSTimer scheduledTimerWithTimeInterval:1.0/VIDEO_FPS target:self selector:@selector(playLoop) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timerRender forMode:NSRunLoopCommonModes];
    return;
    
    threadRender = [[NSThread alloc] initWithTarget:self
                                           selector:@selector(threadRenderFunc)
                                             object:nil];
    [threadRender start];
}

#pragma mark - 录制播放处理

- (void)playMedia:(PYIMModeVideo *)media {
    dispatch_barrier_async(queuePlayer, ^{
        [queueRec push:media];
    });
}

- (void)recordMedia:(void (^)(PYIMModeVideo *))block {
    self.recordEnd = block;
}

// 子线程runloop循环渲染，可以考虑放到主线程runloop处理，不过可能导致UI卡顿（如果要像微信那样缩小后进行其他功能操作，就必须放到子线程了）
- (void)threadRenderFunc {
    @autoreleasepool {
        // 这里的时间是控制渲染速度的
        timerRender = [NSTimer scheduledTimerWithTimeInterval:1.0/VIDEO_FPS target:self selector:@selector(playLoop) userInfo:nil repeats:YES];
        // 开启runloop，控制线程循环执行
        [[NSRunLoop currentRunLoop] run];
    }
}

/// 如果收到信息增加信号量，播放队列启动
- (void)playLoop {
    PYIMModeVideo *video = [queueRec pop];
    if(video && video.media){
        kAudioPlayerRequireEmptyTimes = 0;
        if(_state!=EMediaState_Playing)
            _state = EMediaState_Playing;
        
        [PYIMVideoConverter convertYUV:self.viewPlay video:video];
    }else {
        kAudioPlayerRequireEmptyTimes++;
        if(kAudioPlayerRequireEmptyTimes==VIDEO_FPS*2){
            self.state = EMediaState_Paused; // 先暂时这样控制，后期需要同步处理细节问题
        }
    }
}

#pragma mark - 回调处理

/// 录制一定的样本针就会回调，CMSampleBufferRef中可以获得相关sample信息
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSData *record = [PYIMVideoConverter convertSample:sampleBuffer];
    if(record && self.recordEnd){
        PYIMModeVideo *video = [[PYIMModeVideo alloc] init];
        video.media = record;
        video.mirror = cameraFront;
        video.angle = 0; // 默认只支持竖屏
        video.width = ENCODE_FRMAE_WIDTH;
        video.height = ENCODE_FRMAE_HEIGHT;
        video.fps = VIDEO_FPS;
        video.bitrate = VIDEO_BITRATE;
        
        if(_state == EMediaState_Playing)
            self.recordEnd(video);
    }
}

#pragma mark -  方向设置

#if TARGET_OS_IPHONE
- (void)handleStatusBarOrientationDidChange:(NSNotification*)notification {
    [self setRelativeVideoOrientation];
}

- (void)setRelativeVideoOrientation {
    switch ([[UIDevice currentDevice] orientation]) {
        case UIInterfaceOrientationPortrait:
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
        case UIInterfaceOrientationUnknown:
#endif
            _recordLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            _recordLayer.connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            _recordLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            _recordLayer.connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        default:
            break;
    }
}
#endif

#pragma mark - 私有方法
/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position]==position) {
            return camera;
        }
    }
    return nil;
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
- (void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [input device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

/**
 *  设置闪光灯模式
 *
 *  @param flashMode 闪光灯模式
 */
- (void)setFlashMode:(AVCaptureFlashMode )flashMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFlashModeSupported:flashMode]) {
            [captureDevice setFlashMode:flashMode];
        }
    }];
}

/**
 *  设置聚焦模式
 *
 *  @param focusMode 聚焦模式
 */
- (void)setFocusMode:(AVCaptureFocusMode )focusMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:focusMode];
        }
    }];
}

/**
 *  设置曝光模式
 *
 *  @param exposureMode 曝光模式
 */
- (void)setExposureMode:(AVCaptureExposureMode)exposureMode{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:exposureMode];
        }
    }];
}

/**
 *  设置聚焦点
 *
 *  @param point 聚焦点
 */
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point{
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        if ([captureDevice isFocusModeSupported:focusMode]) {
            [captureDevice setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        if ([captureDevice isFocusPointOfInterestSupported]) {
            [captureDevice setFocusPointOfInterest:point];
        }
        if ([captureDevice isExposureModeSupported:exposureMode]) {
            [captureDevice setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        if ([captureDevice isExposurePointOfInterestSupported]) {
            [captureDevice setExposurePointOfInterest:point];
        }
    }];
}

/**
 *  添加点按手势，点按时聚焦
 */
- (void)addGenstureRecognizer{
    UITapGestureRecognizer *tapGesture=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(tapScreen:)];
    [self.viewbg addGestureRecognizer:tapGesture];
}

- (void)tapScreen:(UITapGestureRecognizer *)tapGesture{
    CGPoint point= [tapGesture locationInView:self.viewbg];
    //将UI坐标转化为摄像头坐标
    CGPoint cameraPoint= [self.recordLayer captureDevicePointOfInterestForPoint:point];
    [self setFocusCursorWithPoint:point];
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
}

/**
 *  设置聚焦光标位置
 *
 *  @param point 光标位置
 */
- (void)setFocusCursorWithPoint:(CGPoint)point{
    self.focusCursor.center=point;
    self.focusCursor.transform=CGAffineTransformMakeScale(1.5, 1.5);
    self.focusCursor.alpha=1.0;
    [UIView animateWithDuration:1.0 animations:^{
        self.focusCursor.transform=CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        self.focusCursor.alpha=0;
        
    }];
}

@end
