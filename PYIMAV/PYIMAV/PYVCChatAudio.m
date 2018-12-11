//
//  PYVCChatAudio.m
//  PYIMAV
//
//  Created by Administrator on 2018/4/23.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYVCChatAudio.h"
#import "PYIMAccount.h"
#import "PYIMAudioController.h"
#import "PYIMAPIChat.h"
#import "UIApplication+Permissions.h"
#import "UIView+Toast.h"

#import "adpcm.h"
#import "c2c.h"
#import "c2s.h"

/**
 TODO:增加一个timer，如果走到了等待对方接受请求逻辑，就开起来，timer完了提示对方手机不在身边或不在线
 */
@interface PYVCChatAudio () {
    uint64_t timeRecord; // 开始录制时间
}

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *laycCloseTop;
@property (weak, nonatomic) IBOutlet UIButton *btnClose;
@property (weak, nonatomic) IBOutlet UIButton *btnCancel;
@property (weak, nonatomic) IBOutlet UIImageView *imgVBg;
@property (weak, nonatomic) IBOutlet UIImageView *imgVAvatar;
@property (weak, nonatomic) IBOutlet UIView *viewSmall;
@property (weak, nonatomic) IBOutlet UIView *viewFull;
@property (weak, nonatomic) IBOutlet UILabel *labDesc;
@property (weak, nonatomic) IBOutlet UILabel *labName;

@property (nonatomic, strong) PYIMAudioController *audioController; ///< 语音模块
@property (nonatomic, weak) PYIMModeNetwork *taskGetAccount;  ///< 任务

@end

@implementation PYVCChatAudio

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.btnCancel.layer.cornerRadius = CGRectGetHeight(self.btnCancel.frame)/2;
    self.btnCancel.layer.masksToBounds = YES;
    
    self.laycCloseTop.constant = [UIApplication sharedApplication].statusBarFrame.size.height+10;
    [self.view layoutIfNeeded];
    
    self.viewSmall.userInteractionEnabled = YES;
    [self.viewSmall addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapView:)]];
    
    
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
    
    // 添加监听 - 网络环境变化
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNetworkChanged:)
                                                 name:kNotificationPY_NetworkStatusChanged
                                               object:nil];
    
    
    // 添加监听 - 消息通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleResponseServer:)
                                                 name:kNotificationPY_ResponseServer
                                               object:nil];
    
}

- (void)setupData {
    self.audioController = [[PYIMAudioController alloc] init];
    self.audioController.isLocal = self.isLocal;
    self.audioController.isCompress = self.isCompress;
    self.audioController.is8kTo8k = self.is8kTo8k;
    
    if(self.isLocal){
        kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_AUDIO);
        [self audioControll:YES];
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    if(self.isRequest){
        [PYIMAPIChat chatC2CRequestAccept:YES callback:^(PYIMError *error) {
            __strong typeof(self) strongSelf = weakSelf;
            if(error.success && strongSelf){
                NSLog(@"C2C_REQUEST_RSP 发送成功");
                [strongSelf audioControll:YES];
            }
        }];
    }else {
        self.taskGetAccount = [PYIMAPIChat chatGetAccount:self.toAccount type:P2P_CHAT_TYPE_AUDIO callback:^(PYIMError *error) {
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
                [self caneclWithError:error isLocal:NO];
            }
        }];
        
        self.taskGetAccount.media.resentCount = 3; // 30秒都没有成功可能对方不在线
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
                
                [self audioControll:YES];
            }else {
                // 对方拒绝了
                error.errDesc = @"对方拒绝通话";
                [self caneclWithError:error isLocal:NO];
            }
        }else if(error.cmdID == C2C_AUDIO_FRAME){
            if(kAccount.chatSave==0)return;
            
            // 如果已经收到了别人的消息了，说明相关操作已成功；1有可能自己同意请求回复没收到，2.自己打洞回复未收到
            if(!self.audioController.isPlaying)
                [self audioControll:YES];
            
            [self.audioController playAudio:error.mode];
            
        }else if(error.cmdID == C2C_CLOSE ||
                 error.cmdID == C2C_CANCEL_REQUEST){
            error.errDesc = @"对方取消了通话";
            [self caneclWithError:error isLocal:NO];
            
        }else if(error.cmdID == C2C_PAUSE){
            
        }
    }
}

- (void)handleNetworkChanged:(NSNotification*)sender {
    if(sender.object){
        NSDictionary *dic = sender.object;
        //        BOOL local = [dic boolForKey:@"local"];
        //        PYServerType sType = [dic integerForKey:@"server"];
        //        PYNetworkSocketState quality = [dic integerForKey:@"state"];
        
        NSString *desc = [dic stringForKey:@"desc"];
        if(desc.length>0){
            [self.view makeToast:desc];
        }
    }
}

/// 准备工作就绪，语音播放挂接
- (void)audioControll:(BOOL)play {
    if(self.audioController.isPlaying==play)return;
    NSLog(@"开启语音模块");
    
    self.labDesc.text = play?@"":@"正在等待对方接受邀请...";
    self.labName.text = [NSString stringWithFormat:@"%lld", kAccount.toAccount];
    
    kAccount.chatState = play?1:0;
    if(play){
        timeRecord = [[NSDate date] timeIntervalSince1970]*1000;
        
        __weak typeof(self) weakSelf = self;
        
        // 注意此处在录制子线程执行；录制中途是不会断开的，所以时间上也是连续的；不支持暂停，要么通话要么断开
        [self.audioController recordAudio:^(NSData *media) {
            __strong typeof(self) strongSelf = weakSelf;
            
            PYIMModeAudio *audio = [[PYIMModeAudio alloc] init];
            audio.media = media;
            audio.is8kTo8k = strongSelf.is8kTo8k;
            audio.timeRecordStart = timeRecord;
            audio.timeRecordEnd = [[NSDate date] timeIntervalSince1970]*1000;
            
            if(strongSelf && strongSelf.isLocal){
                [strongSelf.audioController playAudio:audio];
                return;
            }
            
            [PYIMAPIChat chatC2CSendMedia:audio callback:nil];
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
    }else {
        [self.audioController stopAudio];
    }
}

- (IBAction)btnCancelClicked:(id)sender {
    [self caneclWithError:nil isLocal:YES];
}

- (IBAction)btnCloseClicked:(id)sender {
    
}

- (void)tapView:(UITapGestureRecognizer*)sender {
    if(sender.state == UIGestureRecognizerStateRecognized){
        [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            
        } completion:^(BOOL finished) {
            self.viewSmall.hidden = YES;
        }];
    }
}

- (void)caneclWithError:(PYIMError*)error isLocal:(BOOL)isLocal {
    if(self.audioController==nil)return;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if(self.taskGetAccount){
        [PYIMAPIChat cancelTask:@[self.taskGetAccount]];
    }
    
    if(isLocal && !self.isLocal && self.taskGetAccount==nil){
        [PYIMAPIChat chatC2CRequestOpr:self.audioController.isPlaying ? C2C_CLOSE: C2C_CANCEL_REQUEST callback:nil];
    }
    
    if(self.isLocal){
        kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
        kAccount.chatState = 0;
    }
    
    if(self.audioController){
        [self.audioController stopAudio];
        self.audioController = nil;
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
