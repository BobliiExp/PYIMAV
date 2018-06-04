//
//  PYVCChatVideo.m
//  PYIMAV
//
//  Created by Administrator on 2018/4/23.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYVCChatVideo.h"
#import "UIApplication+Permissions.h"
#import "PYIMVideoController.h"
#import "PYIMAudioController.h"
#import "PYIMAccount.h"
#import "UIView+Toast.h"
#import "PYIMAPIChat.h"

#import "c2c.h"

@interface PYVCChatVideo () {
    uint64_t timeRecord; // 开始录制时间
    NSTimer *timerRequest;
}

@property (weak, nonatomic) IBOutlet UIView *viewBg;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *laycBgTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *laycNameTop;
@property (weak, nonatomic) IBOutlet UIImageView *imgVAvatar;
@property (weak, nonatomic) IBOutlet UILabel *labName;
@property (weak, nonatomic) IBOutlet UIButton *btnAudio;
@property (weak, nonatomic) IBOutlet UIButton *btnCancel;
@property (weak, nonatomic) IBOutlet UIView *viewFront;
@property (weak, nonatomic) IBOutlet UILabel *labDesc;

@property (nonatomic, strong) PYIMVideoController *videoController;
@property (nonatomic, strong) PYIMAudioController *audioController;

@property (nonatomic, weak) PYIMModeNetwork *taskGetAccount;  ///< 任务

@end

@implementation PYVCChatVideo

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.laycBgTop.constant = [UIApplication sharedApplication].statusBarFrame.size.height+10;
    self.laycNameTop.constant = [UIApplication sharedApplication].statusBarFrame.size.height+15;
    [self.view layoutIfNeeded];
    
    self.viewFront.hidden = YES;
    
    kPermissionAccess acc = [[UIApplication sharedApplication] hasAccessToCamera];
    if(acc == kPermissionAccessGranted){
        [self checkMicrophone];
    }else {
        if(acc == kPermissionAccessDenied){
            [self caneclWithError:[[PYIMError alloc] initWithError:@"您已拒绝访问摄像头，将无法开启视频通话功能！"] isLocal:YES];
        }else {
            [[UIApplication sharedApplication] requestAccessToCameraWithSuccess:^{
                [self checkMicrophone];
            } andFailure:^{
                [self caneclWithError:[[PYIMError alloc] initWithError:@"无法访问摄像头，请检查权限设置！"] isLocal:YES];
            }];
        }
    }
}

- (void)checkMicrophone {
    kPermissionAccess acc = [[UIApplication sharedApplication] hasAccessToMicrophone];
    if(acc == kPermissionAccessGranted){
        [self setupData];
    }else {
        if(acc == kPermissionAccessDenied){
            [self caneclWithError:[[PYIMError alloc] initWithError:@"您已拒绝访问话筒，将无法开启语音通话功能！"] isLocal:YES];
        }else {
            [[UIApplication sharedApplication] requestAccessToMicrophoneWithSuccess:^{
                [self setupData];
            } andFailure:^{
                [self caneclWithError:[[PYIMError alloc] initWithError:@"无法访问话筒，请检查权限设置！"] isLocal:YES];
            }];
        }
    }
}

- (void)setupData {
    // 添加监听 - 消息通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleResponseServer:)
                                                 name:kNotificationPY_ResponseServer
                                               object:nil];
    
    self.videoController = [[PYIMVideoController alloc] initWithBGView:self.viewBg front:self.viewFront];
    self.videoController.isLocal = self.isLocal;
    self.videoController.isCompress = self.isCompress;
    
    self.audioController = [[PYIMAudioController alloc] init];
    self.audioController.isLocal = self.isLocal;
    self.audioController.isCompress = self.isCompress;
    self.audioController.is8kTo8k = self.is8kTo8k;
    
    self.viewBg.userInteractionEnabled = YES;
    UITapGestureRecognizer *tapG = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGuesture:)];
    tapG.numberOfTapsRequired = 2;
    [self.viewBg addGestureRecognizer:tapG];
    
    self.viewFront.userInteractionEnabled = YES;
    tapG = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGuesture:)];
    tapG.numberOfTapsRequired = 2;
    [self.viewFront addGestureRecognizer:tapG];
    
    if(self.isLocal){
        kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_VIDEO);
        kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_AUDIO);
        [self startPlay];
        return;
    }
    
    @weakify(self);
    if(self.isRequest){
        [PYIMAPIChat chatC2CRequestAccept:YES callback:^(PYIMError *error) {
            @strongify(self);
            if(self && error.success){
                NSLog(@"C2C_REQUEST_RSP 发送成功");
                [self startPlay];
            }
        }];
    }else {
        self.taskGetAccount = [PYIMAPIChat chatGetAccount:self.toAccount type:P2P_CHAT_TYPE_VIDEO callback:^(PYIMError *error) {
            @strongify(self);
            if(self==nil)return;
            
            if(error.success){
                NSLog(@"C2S_HOLE 打洞成功");
                
                [PYIMAPIChat chatC2CHole:^(PYIMError *error) {
                    if(error.success){
                        NSLog(@"C2C_HOLE 打洞发送成功");
                    }
                }];
                
                [NSThread sleepForTimeInterval:0.01];
                
                [PYIMAPIChat chatC2CRequest:^(PYIMError *error) {
                    if(error.success){
                        NSLog(@"C2C_REQUEST 请求发送成功");
                    }
                }];
            }else {
                [self caneclWithError:error isLocal:YES];
            }
        }];
        
        self.taskGetAccount.media.resentCount = 3; // 30秒都没有成功可能对方不在线
        
        // 启动timer
        timerRequest = [NSTimer timerWithTimeInterval:self.taskGetAccount.media.timeOutSpan*2 target:self selector:@selector(requestSlowly) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:timerRequest forMode:NSRunLoopCommonModes];
    }
}

- (void)requestSlowly {
    [self.view makeToast:@"对方手机可能不在身边"];
}

- (void)startPlay {
    if(self.audioController.isPlaying)return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.videoController switchPlayWindow];
    });
    
    kAccount.chatState = 1;
    self.viewFront.hidden = NO;
    
    self.labDesc.text = nil;
    self.labName.text = [NSString stringWithFormat:@"%lld", kAccount.toAccount];
    
    timeRecord = [[NSDate date] timeIntervalSince1970]*1000;
    
    if(!self.audioController.isPlaying){
        NSLog(@"开启语音模块");
        
        __weak typeof(self) weakSelf = self;
        
        // 注意此处在录制子线程执行；录制中途是不会断开的，所以时间上也是连续的；不支持暂停，要么通话要么断开
        [self.audioController recordAudio:^(NSData *media) {
            __strong typeof(self) strongSelf = weakSelf;
            if(strongSelf){
                PYIMModeAudio *audio = [[PYIMModeAudio alloc] init];
                audio.media = media;
                audio.timeRecordStart = timeRecord;
                audio.timeRecordEnd = [[NSDate date] timeIntervalSince1970]*1000;
                audio.is8kTo8k = self.is8kTo8k;
                
                if(strongSelf.isLocal){
                    [strongSelf.audioController playAudio:audio];
                    return;
                }
                
                [PYIMAPIChat chatC2CSendMedia:audio callback:nil];
            }
        }];
        
        [self.audioController startAudio:^(PYIMMediaState state) {
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(self) strongSelf = weakSelf;
                if(strongSelf){
                    if(state == EMediaState_Stoped)
                        [strongSelf btnCancelClicked:nil];
                    else {
                        strongSelf.labDesc.text = [NSString stringWithFormat:@"语音%@", state==EMediaState_Paused?@"已暂停":@"播放中"];
                    }
                }
            });
        }];
    }
    
    if(!self.videoController.isPlaying){
        NSLog(@"开启视频模块");
        @weakify(self);
        [self.videoController recordMedia:^(PYIMModeVideo *media) {
            @strongify(self);
            if(self){
                if(self.isLocal){
                    [self.videoController playMedia:media];
                    return;
                }
                
                media.timeRecordStart = timeRecord;
                media.timeRecordEnd = [[NSDate date] timeIntervalSince1970]*1000;
                
                [PYIMAPIChat chatC2CSendMedia:media callback:nil];
            }
        }];
        
        [self.videoController start:^(PYIMMediaState state) {
            @strongify(self);
            if(self)
                [self.view makeToast:[NSString stringWithFormat:@"视频%@", state==EMediaState_Paused?@"已暂停":@"播放中"]];
        }];
    }
}

/// 处理相关消息通知
- (void)handleResponseServer:(NSNotification*)sender {
    if(sender.object){
        PYIMError *error = sender.object;
        if(error.cmdID == C2C_REQUEST_RSP){
            if(self.audioController.isPlaying) return;
            if(!error.success) { [self caneclWithError:error isLocal:YES]; } return;
            
            if(kAccount.chatState==1){
                // 对方接受了，自己在打洞一次
                [PYIMAPIChat chatC2CHole:^(PYIMError *error) {
                    if(error.success){
                        NSLog(@"C2C_HOLE 再次打洞发送成功");
                    }
                }];
                
                [self startPlay];
            }else {
                // 对方拒绝了
                error.errDesc = @"对方拒绝通话";
                [self caneclWithError:error isLocal:NO];
            }
        }else if(error.cmdID == C2C_AUDIO_FRAME){
            if(kAccount.chatSave==0)return;
            
            // 如果已经收到了别人的消息了，说明相关操作已成功；1有可能自己同意请求回复没收到，2.自己打洞回复未收到
            if(!self.audioController.isPlaying)
                [self startPlay];
            
            [self.audioController playAudio:error.mode];
            
        }else if(error.cmdID == C2C_VIDEO_FRAME ||
                 error.cmdID == C2C_VIDEO_FRAME_EX){
            if(kAccount.chatSave==0)return;
            
            // 如果已经收到了别人的消息了，说明相关操作已成功；1有可能自己同意请求回复没收到，2.自己打洞回复未收到
            if(!self.audioController.isPlaying)
                [self startPlay];
            
            [self.videoController playMedia:(PYIMModeVideo*)error.mode];
            
        }else if(error.cmdID == C2C_CLOSE ||
                 error.cmdID == C2C_CANCEL_REQUEST){
            error.errDesc = @"对方取消了通话";
            [self caneclWithError:error isLocal:NO];
            
        }else if(error.cmdID == C2C_PAUSE){
            
        }else if(error.cmdID == C2C_SWITCH){
            [self.videoController stop];
        }
    }
}

- (void)tapGuesture:(UITapGestureRecognizer*)sender {
    if([sender.view isEqual:self.viewBg])
        [self.videoController switchCamera];
    else if([sender.view isEqual:self.viewFront])
        [self.videoController switchPlayWindow];
}

- (IBAction)btnCancelClicked:(id)sender {
    [self caneclWithError:nil isLocal:YES];
}

- (IBAction)btnAudioClicked:(id)sender {
    if(self.videoController.isPlaying){
        [PYIMAPIChat chatC2CRequestOpr:C2C_SWITCH callback:^(PYIMError *error) {
            if(error.success){
                [self.videoController stop];
                [self.videoController performSelector:@selector(cleanSelf)]; // test for runtime method undefine
            }
        }];
    }else {
        [self.view makeToast:@"已经切换"];
    }
}

- (void)caneclWithError:(PYIMError*)error isLocal:(BOOL)isLocal {
    if(self.videoController==nil)return;
    
    if(timerRequest){
        [timerRequest invalidate];
        timerRequest = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if(self.taskGetAccount){
        [PYIMAPIChat cancelTask:@[self.taskGetAccount]];
    }
    
    if(isLocal && !self.isLocal && self.taskGetAccount==nil){
        [PYIMAPIChat chatC2CRequestOpr:self.videoController.isPlaying ? C2C_CLOSE: C2C_CANCEL_REQUEST callback:nil];
    }
    
    if(self.isLocal){
        kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
        kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
        kAccount.chatState = 0;
    }
    
    if(self.audioController){
        [self.audioController stopAudio];
        self.audioController = nil;
    }
    
    if(self.videoController){
        [self.videoController stop];
        self.videoController = nil;
    }
    
    if(error && error.errDesc){
        [self.view makeToast:error.errDesc];
        @weakify(self);
        [self.view addToastCallback:^{
            @strongify(self);
            [self cleanSelf];
        }];
    }else {
        [self cleanSelf];
    }
}

- (void)cleanSelf {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    NSLog(@"dealloc %@", self);
}

@end
