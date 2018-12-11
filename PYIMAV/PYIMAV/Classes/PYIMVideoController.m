//
//  PYIMVideoController.m
//  PYIMAV
//
//  Created by Bob Lee on 2018/5/16.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYIMVideoController.h"
#import "PYIMQueue.h"
#import "PYIMVideoConverter.h"

#import <GPUImage/GPUImage.h>
#import "GPUImageBeautifyFilter.h"

#import <GLKit/GLKit.h>

#import <objc/message.h>

#import <CoreImage/CoreImage.h>

#import <YUCIHighPassSkinSmoothing.h>

#import "DotEnginePixelBuffer.h"

void cleanSelf(id self, SEL _cmd){
    NSLog(@"貌似您没有实现cleanSelf方法，这里是动态添加的处理逻辑");
}

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
    NSTimer *timerRender;
    
    int fps_balance;
    int fps_adapt; // 优先适配的帧率来自对方
    
    // 下面采用GPUImage实现美化采集，以上是通过原始采集方案
    GPUImageVideoCamera *gpuCamera;
    GPUImageBeautifyFilter *beautifyFilter;
    UIView *gpuPreview;
    CIContext *coreImageContext;
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
        queueRec = [[PYIMQueue alloc] initWithCapcity:5];
        
        // 原始采集
        queueOutput = dispatch_queue_create("PYIMVideoController", DISPATCH_QUEUE_SERIAL); // 串行，逐个获取
        queuePlayer = dispatch_queue_create("videoplay", DISPATCH_QUEUE_CONCURRENT); // 控制视频播放的queue，顺序播放，采用semaphore控制
        cameraFront = YES;
        [self setupCaptureSession];
        [self setupCamera];
        [session startRunning];
        coreImageContext = [CIContext contextWithOptions:nil];
        // end
        
        // GPUImage 采集
        //        [self setupGPUCapture];
        //        EAGLContext *glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        //        GLKView *glView = [[GLKView alloc] initWithFrame:CGRectMake(0.0, 0.0, 360.0, 480.0) context:glContext];
        //        coreImageContext = [CIContext contextWithEAGLContext:glView.context];
        // end
        
    }
    
    return self;
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
    
    // 创建输出配置
    output = [[AVCaptureVideoDataOutput alloc] init];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    
    // Since we will use CIImage and CIFilter to apply filter to video output, we need to change the output format to kCVPixelFormatType_32BGRA which can be used by CIImage.
    NSNumber* val = [NSNumber numberWithUnsignedInt:_isFilter?kCVPixelFormatType_32BGRA:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]; //kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
    output.videoSettings = videoSettings;
    [output setSampleBufferDelegate:self queue:queueOutput];
    output.alwaysDiscardsLateVideoFrames = YES;
    
    // 关联输出与展示
    connection = [output connectionWithMediaType:AVMediaTypeVideo];
    if ([session canAddOutput:output]) {
        [session addOutput:output];
    }
    
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    // 本地预览layer
    _recordLayer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    [_recordLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    _recordLayer.frame = [[UIScreen mainScreen] bounds];
    [self.viewbg.layer addSublayer:_recordLayer];
    
    // 接收播放layer
    CGFloat width = MIN(CGRectGetWidth(self.viewfront.bounds), CGRectGetHeight(self.viewfront.bounds));
    _viewPlay = [[STMGLView alloc] initWithFrame:CGRectMake(-(width-CGRectGetWidth(_viewfront.bounds))/2, -(width-CGRectGetHeight(_viewfront.bounds))/2, width, width) videoFrameSize:CGSizeMake(ENCODE_FRMAE_WIDTH, ENCODE_FRMAE_HEIGHT) videoFrameFormat:STMVideoFrameFormatYUV];
    [self.viewfront addSubview:_viewPlay];
    
    self.viewbg.layer.masksToBounds = YES;
    self.viewfront.clipsToBounds = YES;
}

- (void)setupCamera {
    [session beginConfiguration];
    
    [session removeInput:input];
    NSError *error;
    AVCaptureDeviceInput *temp = [AVCaptureDeviceInput deviceInputWithDevice:cameraFront?cameraDeviceF:cameraDeviceB error:&error];
    if([session canAddInput:temp]){
        [session addInput:temp];
        input = temp;
        [self setupFPS];
    }
    
    [session commitConfiguration];
}

/// deprecated 设置视频帧间隔，越大效果越差，采用默认
- (void)setupFPS {
    AVCaptureDeviceFormat *bestFormat = nil;
    AVFrameRateRange *bestFrameRateRange = nil;
    AVCaptureDevice *device = gpuCamera?gpuCamera.inputCamera:(cameraFront?cameraDeviceF:cameraDeviceB);
    
    for ( AVCaptureDeviceFormat *format in [device formats] ) {
        for ( AVFrameRateRange *range in format.videoSupportedFrameRateRanges ) {
            if ( range.maxFrameRate > bestFrameRateRange.maxFrameRate) {
                bestFormat = format;
                bestFrameRateRange = range;
            }
        }
    }
    
    // 这里获取到相机最佳fsp与format
    if (bestFormat) {
        int fps = bestFrameRateRange.minFrameRate+(bestFrameRateRange.maxFrameRate-bestFrameRateRange.minFrameRate)/2;
        fps = MAX(fps, 10);
        fps = MIN(fps, 30);
        [self updataCameraFps:fps_adapt>0?fps_adapt:fps format:bestFormat];
    }
}

/// 可动态适配帧率
- (void)updataCameraFps:(int)fps format:(AVCaptureDeviceFormat*)format {
    fps_balance = fps;
    AVCaptureDevice *device = gpuCamera?gpuCamera.inputCamera:(cameraFront?cameraDeviceF:cameraDeviceB);
    
    if ([device lockForConfiguration:NULL] == YES ) {
        if(format)
            device.activeFormat = format;
        
        device.activeVideoMinFrameDuration = CMTimeMake(1,fps_balance);
        device.activeVideoMaxFrameDuration = CMTimeMake(1,fps_balance);
        [device unlockForConfiguration];
    }
}

- (BOOL)isPlaying {
    return self.playEnd!=nil;
}

- (void)setState:(PYIMMediaState)state {
    _state = state;
    
    if(self.playEnd)
        self.playEnd(state);
}

- (void)dealloc {
    NSLog(@"dealloc %@", self);
    [self stop];
}
#pragma mark - GPUImage
/// deprecated 因为这里通过RGBA 转到 YUV后会导致图像色彩变化，具体原因未细究
- (void)setupGPUCapture {
    // 创建视频源
    // SessionPreset:屏幕分辨率，AVCaptureSessionPresetHigh会自适应高分辨率
    // cameraPosition:摄像头方向
    // 最好使用AVCaptureSessionPresetHigh，会自动识别，如果用太高分辨率，当前设备不支持会直接报错
    GPUImageVideoCamera *videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh cameraPosition:AVCaptureDevicePositionFront];
    videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    gpuCamera = videoCamera;
    
    //    videoCamera.delegate = self; // 设置委托回调的sample就是采集的原始帧数据
    
    // 创建最终预览View
    GPUImageView *captureVideoPreview = [[GPUImageView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    captureVideoPreview.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    [self.viewbg addSubview:captureVideoPreview];
    gpuPreview = captureVideoPreview;
    
    // 接收播放layer
    CGFloat width = MIN(CGRectGetWidth(self.viewfront.bounds), CGRectGetHeight(self.viewfront.bounds));
    _viewPlay = [[STMGLView alloc] initWithFrame:CGRectMake(-(width-CGRectGetWidth(_viewfront.bounds))/2, -(width-CGRectGetHeight(_viewfront.bounds))/2, width, width) videoFrameSize:CGSizeMake(ENCODE_FRMAE_WIDTH, ENCODE_FRMAE_HEIGHT) videoFrameFormat:STMVideoFrameFormatYUV];
    [self.viewfront addSubview:_viewPlay];
    
    self.viewbg.layer.masksToBounds = YES;
    self.viewfront.clipsToBounds = YES;
    
    //这里我在GPUImageBeautifyFilter中增加个了初始化方法用来设置美颜程度intensity
    beautifyFilter = [[GPUImageBeautifyFilter alloc] init];
    [videoCamera addTarget:beautifyFilter];
    [beautifyFilter addTarget:captureVideoPreview];
    
    CGSize outputSize = {ENCODE_FRMAE_WIDTH, ENCODE_FRMAE_HEIGHT}; //基于GPUImage输出的视频流格式为RGBA，我这边需要对接Android格式YUV，所以要么转换，要么就只能从原始Sample输出进行filter处理
    GPUImageRawDataOutput *rawDataOutput = [[GPUImageRawDataOutput alloc] initWithImageSize:CGSizeMake(outputSize.width, outputSize.height) resultsInBGRAFormat:NO];
    [beautifyFilter addTarget:rawDataOutput];
    
    __weak GPUImageRawDataOutput *weakOutput = rawDataOutput;
    __weak typeof(self) weakSelf = self;
    [rawDataOutput setNewFrameAvailableBlock:^{
        __strong GPUImageRawDataOutput *strongOutput = weakOutput;
        __strong typeof(self) strongSelf = weakSelf;
        if(strongSelf && strongOutput && strongSelf.recordEnd){
            [strongOutput lockFramebufferForReading];
            
            // 这里就可以获取到添加滤镜的数据了
            GLubyte *outputBytes = [strongOutput rawBytesForImage];
            NSInteger bytesPerRow = [strongOutput bytesPerRowInOutput];
            CVPixelBufferRef pixelBuffer = NULL;
            CVPixelBufferCreateWithBytes(kCFAllocatorDefault, outputSize.width, outputSize.height, kCVPixelFormatType_32BGRA /*这里直接填写kCVPixelFormatType_420YpCbCr8BiPlanarFullRange得不到UV数据*/, outputBytes, bytesPerRow, nil, nil, nil, &pixelBuffer);
            
            // RGBA to YUV
            pixelBuffer = [DotEnginePixelBuffer convertPixelBuffer:pixelBuffer];
            
            // 之后可以利用VideoToolBox进行硬编码再结合rtmp协议传输视频流了
            [weakSelf actionCaptureOutEx:pixelBuffer];
            
            [strongOutput unlockFramebufferAfterReading];
            CFRelease(pixelBuffer);
        }
    }];
    
    // 调整摄像头采样率
    [self setupFPS];
    
    // 必须调用startCameraCapture，底层才会把采集到的视频源，渲染到GPUImageView中，就能显示了。
    // 开始采集视频
    [videoCamera startCameraCapture];
}

#pragma mark - 相关操作

- (void)switchPlayWindow {
    // 控制切换动画，有动画效果不好
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    if([_viewbg.subviews containsObject:_viewPlay]){
        CGFloat width = MIN(CGRectGetWidth(_viewfront.bounds), CGRectGetHeight(_viewfront.bounds));
        _viewPlay.frame = CGRectMake(-(width-CGRectGetWidth(_viewfront.bounds))/2, -(width-CGRectGetHeight(_viewfront.bounds))/2, width, width);
        [_viewfront addSubview:_viewPlay];
        
        if(gpuCamera){
            gpuPreview.frame = _viewbg.bounds;
            [_viewbg addSubview:gpuPreview];
        } else {
            _recordLayer.frame = _viewbg.bounds;
            [_viewbg.layer addSublayer:_recordLayer];
        }
    }else {
        CGFloat width = MIN(CGRectGetWidth(_viewbg.bounds), CGRectGetHeight(_viewbg.bounds));
        _viewPlay.frame = CGRectMake(-(width-CGRectGetWidth(_viewbg.bounds))/2, -(width-CGRectGetHeight(_viewbg.bounds))/2, width, width);
        [_viewbg addSubview:_viewPlay];
        
        if(gpuCamera){
            gpuPreview.frame = _viewfront.bounds;
            [_viewfront addSubview:gpuPreview];
        } else {
            _recordLayer.frame = _viewfront.bounds;
            [_viewfront.layer addSublayer:_recordLayer];
        }
    }
    [CATransaction commit];
}

- (void)switchCamera {
    if(gpuCamera){
        [gpuCamera rotateCamera];
    }else {
        if (session.isRunning) {
            cameraFront = !cameraFront;
            [session stopRunning];
            [self setupCamera];
            [session startRunning];
        }
    }
}

- (void)pause {
    [self pauseUntil:0];
}

- (void)pauseUntil:(NSTimeInterval)timespan {
    if(gpuCamera)
        [gpuCamera pauseCameraCapture];
    
    self.state = EMediaState_Paused;
}

- (void)resume {
    if(gpuCamera)
        [gpuCamera resumeCameraCapture];
    
    self.state = EMediaState_Playing;
}

- (void)stop {
    if(self.playEnd==nil)
        return;
    
    self.playEnd = nil;
    self.recordEnd = nil;
    
    self.state = EMediaState_Stoped;
    if(session)
        [session stopRunning];
    
    if(gpuCamera){
        [gpuCamera stopCameraCapture];
        
        [gpuCamera stopCameraCapture];
        [gpuCamera removeInputsAndOutputs];
        [gpuCamera removeAllTargets];
        [beautifyFilter removeAllTargets];
    }
    
    if(coreImageContext){
        coreImageContext = nil;
    }
    
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
    
    // 主线程操作OpenGLES绘制
    
}

#pragma mark - 录制播放处理

- (void)playMedia:(PYIMModeVideo *)media {
    // check whether fps need to be config
    if(media.fps != fps_adapt && media.client==1){
        fps_adapt = media.fps;
        if(fps_adapt!=fps_balance){
            NSLog(@"接收到对方fps");
            [self updataCameraFps:fps_adapt format:nil];
        }
    }
    
    [queueRec push:media];
    
    // dispatch_after 不准确后期优化
    dispatch_time_t timer = dispatch_time(DISPATCH_TIME_NOW, 1.000000/media.fps * NSEC_PER_SEC);
    dispatch_after(timer, dispatch_get_main_queue(), ^{
        [self playLoop];
    });
}

- (void)recordMedia:(void (^)(PYIMModeVideo *))block {
    self.recordEnd = block;
}

// duplicate 子线程runloop循环渲染，可以考虑放到主线程runloop处理，不过可能导致UI卡顿（如果要像微信那样缩小后进行其他功能操作，就必须放到子线程了）
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
    [self actionCaptureOut:sampleBuffer];
}

- (void)actionCaptureOut:(CMSampleBufferRef)sampleBuffer {
    if(self.recordEnd==nil)return;
    if(_isFilter){
        @autoreleasepool{
            CFAbsoluteTime t0 = CFAbsoluteTimeGetCurrent();
            CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
            CIImage *filteredImage = nil;
            
            /* 美颜效果 - 但是不生效
             YUCIHighPassSkinSmoothing *fiter = [[YUCIHighPassSkinSmoothing alloc] init];
             fiter.inputImage = ciImage;
             fiter.inputAmount = @0.7;
             fiter.inputRadius = @(5);
             CIImage *filteredImage = [fiter outputImage];
             */
            
            /* 滤镜蒙版效果
             CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:pixelBuffer options:nil];
             CGRect sourceExtent = sourceImage.extent;
             
             // Image processing
             CIFilter * vignetteFilter = [CIFilter filterWithName:@"CIVignetteEffect"];
             [vignetteFilter setValue:sourceImage forKey:kCIInputImageKey];
             [vignetteFilter setValue:[CIVector vectorWithX:sourceExtent.size.width/2 Y:sourceExtent.size.height/2] forKey:kCIInputCenterKey];
             [vignetteFilter setValue:@(sourceExtent.size.width/2) forKey:kCIInputRadiusKey];
             CIImage *filteredImage = [vignetteFilter outputImage];
             
             CIFilter *effectFilter = [CIFilter filterWithName:@"CIPhotoEffectInstant"];
             [effectFilter setValue:filteredImage forKey:kCIInputImageKey];
             filteredImage = [effectFilter valueForKey:kCIOutputImageKey]; // 取出渲染后图片
             */
            
            //     手动调整控制光效等 - 待调试
            CIFilter *fiter = [CIFilter filterWithName:@"CIFaceBalance"];
            [fiter setValue:ciImage forKey:@"inputImage"];
            [fiter setValue:@1 forKey:@"inputStrength"];
            filteredImage = [fiter valueForKey:kCIOutputImageKey];
            
            NSLog(@"%@", [[CIFilter filterWithName:@"CIFaceBalance"] attributes]);
            ////
            //    [filter setValue:outImage forKey:kCIInputImageKey]; // 设置输入图片
            //    [filter setDefaults];
            //    [filter setValue:@0.7 forKey:@"inputAmount"]; //设置滤镜参数 - 饱和度 0~2
            //    [filter setValue:@1.1 forKey:@"inputSaturation"]; //设置滤镜参数 - 饱和度 0~2
            //    [filter setValue:@0 forKey:@"inputBrightness"]; // 亮度 -1~1
            //    [filter setValue:@1.2 forKey:@"inputContrast"]; // 对比度 0~2
            
            //    outImage = [filter valueForKey:kCIOutputImageKey]; // 取出渲染后图片
            //
            
            [coreImageContext render:filteredImage toCVPixelBuffer:pixelBuffer];
            
            // BGRA to YUV
            pixelBuffer = [DotEnginePixelBuffer convertPixelBuffer:pixelBuffer];
            
            CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
            NSLog(@"dur to ciimage: %@", @(t1-t0));
            [self actionCaptureOutEx:pixelBuffer];
            ciImage = nil;
            filteredImage = nil;
            fiter = nil;
            free(pixelBuffer);
        }
        
    }else {
        PYIMModeVideo *video = [PYIMVideoConverter convertSample:sampleBuffer];
        if(video.media){
            video.mirror = gpuCamera?gpuCamera.frontFacingCameraPresent:cameraFront;
            video.angle = 90; // 默认只支持竖屏
            video.fps = fps_balance;
            video.bitrate = VIDEO_BITRATE;
            
            if(_state == EMediaState_Playing)
                self.recordEnd(video);
        }
    }
}

- (void)actionCaptureOutEx:(CVPixelBufferRef)sampleBuffer {
    if(self.recordEnd==nil)return;
    
    PYIMModeVideo *video = [PYIMVideoConverter convertSampleEx:sampleBuffer];
    if(video.media){
        video.mirror = gpuCamera?gpuCamera.frontFacingCameraPresent:cameraFront;
        video.angle = 90; // 默认只支持竖屏
        video.fps = fps_balance;
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

#pragma mark - runtime add methods

/// 第一次尝试，尝试处理未实现的消息转发，如果本地有处理返回YES，否则将进行其他方式处理
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    //    return [super resolveInstanceMethod:sel];
    
    if(sel == @selector(cleanSelf)){
        // 动态添加cleanSelf方法
        // 第一个参数：给哪个类添加方法
        // 第二个参数：添加方法的方法编号
        // 第三个参数：添加方法的函数实现（函数地址）
        // 第四个参数：函数的类型，(返回值+参数类型) v:void @:对象->self :表示SEL->_cmd
        class_addMethod(self, @selector(cleanSelf), (IMP)cleanSelf, "v@:");
        return YES;
    }
    
    return [super resolveInstanceMethod:sel];
}

/// 第二次尝试
- (id)forwardingTargetForSelector:(SEL)aSelector {
    //    return [super forwardingTargetForSelector:aSelector];
    
    // 动态创建类处理
    NSString *selectorStr = NSStringFromSelector(aSelector);
    // 做一次类的判断，只对 UIResponder 和 NSNull 有效
    if ([[self class] isSubclassOfClass: NSClassFromString(@"UIResponder")] ||
        [self isKindOfClass:[NSObject class]] ||
        [self isKindOfClass: [NSNull class]])
    {
        NSLog(@"PROTECTOR: -[%@ %@]", [self class], selectorStr);
        NSLog(@"PROTECTOR: unrecognized selector \"%@\" sent to instance: %p", selectorStr, self);
        // 查看调用栈
        NSLog(@"PROTECTOR: call stack: %@", [NSThread callStackSymbols]);
        
        // 对保护器插入该方法的实现
        Class protectorCls = NSClassFromString(@"Protector");
        if (!protectorCls)
        {
            protectorCls = objc_allocateClassPair([NSObject class], "Protector", 0);
            objc_registerClassPair(protectorCls);
        }
        
        // 动态添加方法
        class_addMethod(protectorCls, aSelector, [self safeImplementation:aSelector],
                        [selectorStr UTF8String]);
        
        Class Protector = [protectorCls class];
        id instance = [[Protector alloc] init];
        
        return instance;
    }
    
    return [super forwardingTargetForSelector:aSelector];
}

- (IMP)safeImplementation:(SEL)aSelector
{
    IMP imp = imp_implementationWithBlock(^()
                                          {
                                              NSLog(@"PROTECTOR: %@ Done", NSStringFromSelector(aSelector));
                                          });
    return imp;
}

/// 第三次尝试
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature* signature = [super methodSignatureForSelector:aSelector];
    if (!signature) {
        return [queueRec methodSignatureForSelector:aSelector];
    }
    
    return [super methodSignatureForSelector:aSelector];
}

-(void)forwardInvocation:(NSInvocation *)anInvocation {
    SEL selector = [anInvocation selector];
    if ([queueRec respondsToSelector:selector]) {
        [anInvocation invokeWithTarget:queueRec];
    }
}


@end
