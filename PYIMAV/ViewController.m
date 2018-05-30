//
//  ViewController.m
//  PYIMAV
//
//  Created by Administrator on 2018/4/23.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "ViewController.h"
#import "PYVCChatAudio.h"
#import "PYVCChatVideo.h"
#import "PYIMAPIChat.h"
#import "c2c.h"
#import "c2s.h"

#import "UIView+Toast.h"

#import "PYIMAccount.h"

// hud
#import <SVProgressHUD.h>
// swizzle 这里引入控制按钮快速点击多次问题
#import "UIButton+Swizzle.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIButton *btnAudio;
@property (weak, nonatomic) IBOutlet UIButton *btnVideo;
@property (weak, nonatomic) IBOutlet UIButton *btnLogin;
@property (weak, nonatomic) IBOutlet UILabel *labDesc;
@property (weak, nonatomic) IBOutlet UIView *viewRequest;
@property (weak, nonatomic) IBOutlet UILabel *labRequest;
@property (weak, nonatomic) IBOutlet UIButton *btnReqCancel;
@property (weak, nonatomic) IBOutlet UIButton *btnReqAccept;
@property (weak, nonatomic) IBOutlet UISwitch *switchTest;
@property (weak, nonatomic) IBOutlet UITextField *txtFieldServer;
@property (weak, nonatomic) IBOutlet UITextField *txtFieldAccount;
@property (weak, nonatomic) IBOutlet UILabel *labTest;
@property (weak, nonatomic) IBOutlet UISwitch *switchRate;
@property (weak, nonatomic) IBOutlet UISwitch *switchCompress;
@property (weak, nonatomic) IBOutlet UILabel *lab8k;
@property (weak, nonatomic) IBOutlet UILabel *labComp;
@property (weak, nonatomic) IBOutlet UITextField *txtFieldTo;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.btnAudio.layer.borderColor = self.btnAudio.titleLabel.textColor.CGColor;
    self.btnAudio.layer.borderWidth = 1.0;
    self.btnAudio.layer.cornerRadius = CGRectGetHeight(self.btnAudio.frame)/2;
    self.btnAudio.layer.masksToBounds = YES;
    
    self.btnVideo.layer.borderColor = self.btnVideo.titleLabel.textColor.CGColor;
    self.btnVideo.layer.borderWidth = 1.0;
    self.btnVideo.layer.cornerRadius = CGRectGetHeight(self.btnVideo.frame)/2;
    self.btnVideo.layer.masksToBounds = YES;
    
    self.btnLogin.layer.borderColor = self.btnLogin.titleLabel.textColor.CGColor;
    self.btnLogin.layer.borderWidth = 1.0;
    self.btnLogin.layer.cornerRadius = CGRectGetHeight(self.btnLogin.frame)/2;
    self.btnLogin.layer.masksToBounds = YES;
    
    self.viewRequest.hidden = YES;
    self.viewRequest.alpha = 0;
    
    self.btnReqCancel.layer.borderColor = self.btnReqCancel.titleLabel.textColor.CGColor;
    self.btnReqCancel.layer.borderWidth = 1.0;
    self.btnReqCancel.layer.cornerRadius = CGRectGetHeight(self.btnReqCancel.frame)/2;
    self.btnReqCancel.layer.masksToBounds = YES;
    
    self.btnReqAccept.layer.borderColor = self.btnReqAccept.titleLabel.textColor.CGColor;
    self.btnReqAccept.layer.borderWidth = 1.0;
    self.btnReqAccept.layer.cornerRadius = CGRectGetHeight(self.btnReqAccept.frame)/2;
    self.btnReqAccept.layer.masksToBounds = YES;
    
    self.txtFieldServer.text = @"ws2.lang365.cn";
    self.txtFieldAccount.text = @"500";
    self.switchCompress.hidden = self.labComp.hidden = YES;
    self.switchRate.on = YES;
    self.view.userInteractionEnabled = YES;
    
    [self setupUI];
    [self setupData];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleNetworkChanged:)
                                                 name:kNotificationPY_NetworkStatusChanged
                                               object:nil];
}

- (void)setupUI {
    self.btnAudio.hidden = self.btnVideo.hidden = self.labTest.hidden = self.switchTest.hidden = self.switchRate.hidden = self.lab8k.hidden = kAccount.srvState==0;
    self.btnAudio.enabled = self.btnVideo.enabled = kAccount.hadLogin;
    self.txtFieldTo.hidden = !kAccount.hadLogin;
    self.txtFieldServer.hidden = self.txtFieldAccount.hidden = !self.btnAudio.hidden;
}

- (void)setupData {
    /*
     服务器程序分三个:
     登陆服务器LoginServer:采用UDP监听，断口10000
     音频中转服务器AudioServer:采用UDP监听，断口10001
     音频中转服务器VideoServer:采用TCP监听，断口10002
     
     测试账号1：400088 密码：123456，测试账号2：400093 密码：123456
     */
    [PYIMAPIChat chatObserverServer:^(PYIMError *error) {
        if(error.success){
            switch (error.cmdID) {
                case C2S_HOLE_NOTIFY: {
                    if(kAccount.chatState)return;
                    if(kAccount.toAccount==0)return;
                    
                    // 被人请求打洞，马上回复
                    [PYIMAPIChat chatC2CHole:^(PYIMError *error) {
                        if(!error.success)
                            NSLog(@"%@", error.errDesc);
                    }];
                } break;
                    
                case C2C_HOLE: {
                    if(kAccount.chatState || !error.success)return ;
                    
                    // 被人请求打洞，马上回复
                    [PYIMAPIChat chatC2CHoleResp:error.rspIP port:error.rspPort callback:^(PYIMError *error) {
                        if(!error.success)
                            NSLog(@"%@", error.errDesc);
                    }];
                } break;
                    
                case C2C_REQUEST: {
                    if(kAccount.chatState || !error.success)return ;
                    
                    // 收到请求，先要发一个打洞消息
                    [PYIMAPIChat chatC2CHole:^(PYIMError *error) {
                        if(error.success)
                            NSLog(@"收到请求消息，打洞发送成功");
                    }];
                    
                    // 收到请求确认处理
                    [self requestOpr:YES];
                } break;
                    
                default: {
                    if(error.cmdID == C2C_CANCEL_REQUEST){
                        [self requestOpr:NO];
                    }
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPY_ResponseServer object:error];
                } break;
            }
            
        }else {
            [kNote writeNote:[NSString stringWithFormat:@"接收到信息但有错误：cmd %04x, ip %@, port %d", error.cmdID, error.rspIP, error.rspPort]];
            NSLog(@"接收到信息但有错误：cmd %04x", error.cmdID);
        }
    }];
    
    
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

- (IBAction)btnAudioClicked:(id)sender {
    NSLog(@"点击了: %@",[NSDate date]);
    
    if(!self.switchTest.isOn && (self.txtFieldTo.text==nil || self.txtFieldTo.text.length==0)){
        [self.view makeToast:@"请输入对方账号"];
        return;
    }
    
    PYVCChatAudio *audio = [[PYVCChatAudio alloc] init];
    audio.isLocal = self.switchTest.isOn;
    audio.is8kTo8k = self.switchRate.isOn;
    audio.isCompress = !self.switchCompress.isOn;
    audio.toAccount = [self.txtFieldTo.text intValue];
    [self presentViewController:audio animated:YES completion:NULL];
}

- (IBAction)btnVideoClicked:(id)sender {
    if(!self.switchTest.isOn && (self.txtFieldTo.text==nil || self.txtFieldTo.text.length==0)){
         [self.view makeToast:@"请输入对方账号"];
        return;
    }
    
    PYVCChatVideo *video = [[PYVCChatVideo alloc] init];
    video.isLocal = self.switchTest.isOn;
    video.isCompress = !self.switchCompress.isOn;
    video.toAccount = [self.txtFieldTo.text intValue];
    [self presentViewController:video animated:YES completion:NULL];
}

- (IBAction)btnLoginClicked:(id)sender {
    [self resignInput];
    _labDesc.text = kAccount.hadLogin ? @"退出登录中" : @"登录中";
    
    
    if(kAccount.hadLogin){
        [SVProgressHUD showWithStatus:_labDesc.text];
        [PYIMAPIChat chatLogout:^(PYIMError *error) {
            if(error.success){
                [self setupUI];
                [self.btnLogin setTitle:@"登录" forState:UIControlStateNormal];
            }
            
            [SVProgressHUD dismiss];
            _labDesc.text = error.success ? @"":@"退出登录失败";
        }];
    }else {
        if(self.txtFieldAccount.text==nil || self.txtFieldAccount.text.length==0 ||
           self.txtFieldServer.text==nil || self.txtFieldServer.text.length==0){
            [self.view makeToast:@"请输入登录信息"];
            return;
        }
        
        [SVProgressHUD showWithStatus:_labDesc.text];
        [PYIMAPIChat chatConnectHost:self.txtFieldServer.text port:10000];
        [PYIMAPIChat chatLogin:[self.txtFieldAccount.text intValue] pwd:@"123456" callback:^(PYIMError *error) {
            // 统一操作回调
            if(error.success && kAccount.hadLogin>0){
                [self setupUI];
                [self.btnLogin setTitle:[NSString stringWithFormat:@"退出登录(%@)", self.txtFieldAccount.text] forState:UIControlStateNormal];
                _labDesc.text = nil;
                
            }else {
                _labDesc.text = error.success ? @"":[NSString stringWithFormat:@"登录失败 %d", error.rspPort];
            }
            
            [SVProgressHUD dismiss];
        }];
    }
}

- (IBAction)btnReqAcceptClicked:(id)sender {
    [self resignInput];
    [self requestOpr:NO];
    
    // 进入通话界面
    if(kAccount.chatSave == P2P_CHAT_TYPE_AUDIO){
        PYVCChatAudio *audio = [[PYVCChatAudio alloc] init];
        audio.isRequest = YES;
        audio.isCompress = YES;
        audio.is8kTo8k = self.switchRate.isOn;
        [self presentViewController:audio animated:YES completion:NULL];
    }else if(kAccount.chatSave == P2P_CHAT_TYPE_VIDEO){
        PYVCChatVideo *video = [[PYVCChatVideo alloc] init];
        video.isRequest = YES;
        video.isCompress = YES;
        [self presentViewController:video animated:YES completion:NULL];
    }
}

- (IBAction)btnReqCancelClicked:(id)sender {
    [self resignInput];
    [self requestOpr:NO];
    
    [PYIMAPIChat chatC2CRequestAccept:NO callback:^(PYIMError *error) {
        
    }];
}

- (IBAction)switchAction:(id)sender {
    UISwitch *sw = (UISwitch*)sender;
    self.switchCompress.hidden  = self.labComp.hidden = !sw.isOn;
}

- (void)requestOpr:(BOOL)show {
    if(self.viewRequest.hidden == !show)return;
    
    if(show){
        self.labRequest.text = [NSString stringWithFormat:@"收到来自 %lld 的 %@ 请求", kAccount.toAccount, kAccount.chatTypeName];
        self.viewRequest.hidden = NO;
    }
    
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.viewRequest.alpha = show?1:0;
        
    } completion:^(BOOL finished) {
        if(!show)
            self.viewRequest.hidden = YES;
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self resignInput];
}

- (void)resignInput {
    [self.txtFieldAccount resignFirstResponder];
    [self.txtFieldServer resignFirstResponder];
    [self.txtFieldTo resignFirstResponder];
}

@end
