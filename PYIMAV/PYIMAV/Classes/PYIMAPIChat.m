//
//  PYIMAPIChat.m
//  PYIMAV
//
//  Created by Bob Lee on 2018/4/26.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYIMAPIChat.h"
#import "PYIMAccount.h"
#import "PYIMNetworkManager.h"

#import "c2s.h"
#import "c2c.h"
#import "pdu.h"


#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
//#define IOS_VPN       @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"

@implementation PYIMAPIChat

+ (void)cancelTask:(NSArray*)tasks {
    [PYIMNetworkManager cancelTask:tasks];
}

+ (void)chatConnectHost:(NSString*)host port:(ushort)port {
    [PYIMNetworkManager connectWithHost:host port:port];
}

+ (void)chatObserverServer:(NetWorkCallback)callback {
    PYIMModeNetwork *taskCallback = [[PYIMModeNetwork alloc] init];
    taskCallback.media = [[PYIMModeMedia alloc] init];
    taskCallback.media.cmdID = kCMD_Re_ServerMsg;
    taskCallback.callback = callback;
    [PYIMNetworkManager addTask:taskCallback];
}

+ (PYIMModeNetwork*)addTask:(PYIMModeMedia*)media callback:(NetWorkCallback)callback {
    PYIMModeNetwork *network = [[PYIMModeNetwork alloc] init];
    network.callback = callback;
    network.media = media;
    
    [PYIMNetworkManager addTask:network];
    return network;
}

/// 登录
+ (PYIMModeNetwork*)chatLogin:(uint64_t)account pwd:(NSString *)pwd callback:(NetWorkCallback)callback {
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.cmdID = C2S_LOGIN;
    
    CmdLogin login = {0};
    login.account = htonll_x(account);
    memcpy(login.password, [pwd UTF8String], strlen([pwd UTF8String]));
    if(kAccount.myLocalIp)
        memcpy(login.localIp, [kAccount.myLocalIp UTF8String], strlen([kAccount.myLocalIp UTF8String]));
    else
        NSLog(@"未获取到本地iP");
    login.localPort = htons_x(kAccount.myLocalPort);
    
    // 重置
    [kAccount resetAccount];
    
    kAccount.myAccount = account;
    // ip,port 通过已连接的socket对象获取
    media.dataParam = [NSData dataWithBytes:&login length:sizeof(CmdLogin)];
    
    return [self addTask:media callback:callback];
}

/// 退出登录
+ (PYIMModeNetwork*)chatLogout:(NetWorkCallback)callback {
    kAccount.chatState = 0;
    
    if (kAccount.myAccount != 0 && kAccount.toAccount != 0) {
        if(kAccount.chatType & P2P_CHAT_TYPE_MASK_VIDEO ||
           kAccount.chatType & P2P_CHAT_TYPE_MASK_AUDIO) {
            // 关闭已有连接
            [self chatC2CRequestOpr:C2C_CLOSE callback:nil];
        }
    }
    
    int64_t myAccount = kAccount.myAccount;
//    pause_video();
    kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
    kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
    
    kAccount.myAccount = 0;
    kAccount.srvState = 0;
    
    kAccount.toAccount = 0;
    kAccount.toIp = nil;
    kAccount.toPort = 0;
    kAccount.toLocalIp = nil;
    kAccount.toLocalPort = 0;
    kAccount.toState = 0;
    
//    kAccount.videoState = 0;
//    kAccount.audioState = 0;
    
//    kAccount.myIp = nil;
//    kAccount.myPort = 0;
//    kAccount.myLocalIp = nil;
//    kAccount.myLocalPort = 0;

    
    CmdLogout body = {0};
    body.account = htonll_x(myAccount);
    
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.cmdID = C2S_LOGOUT;
    
    media.dataParam = [NSData dataWithBytes:&body length:sizeof(CmdLogout)];
   return [self addTask:media callback:callback];
}

/// // 获取对方账号状态 发起通话请求 类型  1视频  2语音
+ (PYIMModeNetwork*)chatGetAccount:(uint64_t)to type:(int16_t)type callback:(NetWorkCallback)callback {
    kAccount.chatState = 0;
    if(kAccount.myAccount>0 && kAccount.toAccount>0){
        if(kAccount.chatType & P2P_CHAT_TYPE_MASK_VIDEO ||
           kAccount.chatType & P2P_CHAT_TYPE_MASK_AUDIO){
            // 关闭已有连接
            [self chatC2CRequestOpr:C2C_CLOSE callback:nil];
        }
    }
    
    kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
    kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
    kAccount.chatSave = type;
    
    kAccount.toState = 0;
    kAccount.toAccount = to;
    kAccount.toPort = 0;
    kAccount.toIp = nil;
    kAccount.toLocalPort = 0;
    kAccount.toLocalIp = nil;
    kAccount.toSendTime = 0;
    kAccount.toRecvTime = time(NULL);
    
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.cmdID = C2S_HOLE;
    
    CmdC2SHole req = {0};
    req.account = htonll_x(kAccount.myAccount);
    req.toAccount = htonll_x(kAccount.toAccount);
    if(kAccount.myLocalIp)
        memcpy(req.localIp, [kAccount.myLocalIp UTF8String], strlen([kAccount.myLocalIp UTF8String]));
    else
        NSLog(@"未获取到本地iP");
    req.localPort = htons_x(kAccount.myLocalPort);
    
    media.dataParam = [NSData dataWithBytes:&req length:sizeof(CmdC2SHole)];
    
    return [self addTask:media callback:callback];
}

#pragma mark - C2C

/// 打洞
+ (PYIMModeNetwork*)chatC2CHole:(NetWorkCallback)callback {
    CmdHole body = {0};
    body.account = htonll_x(kAccount.myAccount);
    body.toAccount = htonll_x(kAccount.toAccount);
    
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.cmdID = C2C_HOLE;
    
    media.dataParam = [NSData dataWithBytes:&body length:sizeof(CmdHole)];
    
    NSLog(@"c2cInnerHole|myAccount:%lld, myIp:%@, myPort:%u, toAccount:%lld, toIp:%@, toPort:%u", kAccount.myAccount, kAccount.myIp, kAccount.myPort, kAccount.toAccount, kAccount.toIp, kAccount.toPort);
    return [self addTask:media callback:callback];
}

// 客户端打洞回复
+ (PYIMModeNetwork*)chatC2CHoleResp:(NSString*)ip port:(uint16_t)port callback:(NetWorkCallback)callback {
    CmdHoleRsp body = {0};
    body.account = htonll_x(kAccount.myAccount);
    body.toAccount = htonll_x(kAccount.toAccount);
    
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.cmdID = C2C_HOLE_RSP;
    media.rspIP = ip;
    media.rspPort = port;
    
    media.dataParam = [NSData dataWithBytes:&body length:sizeof(CmdHoleRsp)];
    
    NSLog(@"onC2CHoleRsp|fromip:%@, fromport:%u|myAccount:%lld, toAccount:%lld, myIp:%@, myPort:%u, myLocalIp:%@, myLocalPort:%u, toIp:%@, toPort:%u, toLocalIp:%@, toLocalPort:%u|p2p succ", ip, port, kAccount.myAccount, kAccount.toAccount, kAccount.myIp, kAccount.myPort, kAccount.myLocalIp, kAccount.myLocalPort, kAccount.toIp, kAccount.toPort, kAccount.toLocalIp, kAccount.toLocalPort);
    
    return [self addTask:media callback:callback];
}

// 发起请求连接
+ (PYIMModeNetwork*)chatC2CRequest:(NetWorkCallback)callback {
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0)
    {
        NSLog(@"c2cInnerRequest|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        if(callback)callback([[PYIMError alloc] initWithCmd:C2C_REQUEST_RSP status:C2S_ERR_NOTLOGIN]);
        return nil;
    }
    
    CmdRequest body = {0};
    body.type = kAccount.chatSave;
    body.account = htonll_x(kAccount.myAccount);
    body.toAccount = htonll_x(kAccount.toAccount);
    
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.cmdID = C2C_REQUEST;
    
    media.dataParam = [NSData dataWithBytes:&body length:sizeof(CmdRequest)];
    
    NSLog(@"c2cInnerRequest|toip:%@, toport:%u|myAccount:%lld, myIp:%@, myPort:%u, myLocalIp%@, myLocalPort:%u, toAccount:%lld, toIp:%@, toPort:%u, toLocalIp:%@, toLocalPort:%u", kAccount.srvIp, kAccount.srvPort, kAccount.myAccount, kAccount.myIp, kAccount.myPort, kAccount.myLocalIp, kAccount.myLocalPort, kAccount.toAccount, kAccount.toIp, kAccount.toPort, kAccount.toLocalIp, kAccount.toLocalPort);
    return [self addTask:media callback:callback];
}

/// 接受请求操作
+ (PYIMModeNetwork*)chatC2CRequestAccept:(BOOL)accept callback:(NetWorkCallback)callback {
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0)
    {
        if(callback)
            callback([[PYIMError alloc] initWithCmd:C2C_REQUEST_RSP status:C2S_ERR_NOTLOGIN]);
        return nil;
    }
    
    uint16_t type = kAccount.chatSave; // 请求时候带过来的，赋值上
    
    if (accept)
    {
        [self chatC2CHole:nil];
        
        if (type == P2P_CHAT_TYPE_VIDEO)
        {
            kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_VIDEO);
            kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_AUDIO);
//            resume_video();
        }
        else if (type == P2P_CHAT_TYPE_AUDIO)
        {
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
            kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_AUDIO);
//            pause_video();
        }
        else
        {
            kAccount.chatType = kAccount.chatType | (1 << type);
        }
        
        kAccount.chatState = 1;
        kAccount.chatLastTime = time(NULL);
    }
    else
    {
        if (type == P2P_CHAT_TYPE_VIDEO)
        {
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
//            pause_video();
        }
        else if (type == P2P_CHAT_TYPE_AUDIO)
        {
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
//            pause_video();
        }
        else
        {
            kAccount.chatType = kAccount.chatType & ~(1 << type);
        }
    }
    
    CmdRequestRsp body = {0};
    body.type = type;
    body.account = htonll_x(kAccount.myAccount);
    body.toAccount = htonll_x(kAccount.toAccount);
    body.accept = accept?0x0:0x1;
    
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.cmdID = C2C_REQUEST_RSP;
    media.dataParam = [NSData dataWithBytes:&body length:sizeof(CmdRequestRsp)];
    
    NSLog(@"c2cAccept|toip:%@, toport:%u|accept:%d,type:%d,myAccount:%lld, myIp:%@, myPort:%u, myLocalIp%@, myLocalPort:%u, toAccount:%lld, toIp:%@, toPort:%u, toLocalIp:%@, toLocalPort:%u", kAccount.srvIp, kAccount.srvPort, accept?0x0:0x01, type, kAccount.myAccount, kAccount.myIp, kAccount.myPort, kAccount.myLocalIp, kAccount.myLocalPort, kAccount.toAccount, kAccount.toIp, kAccount.toPort, kAccount.toLocalIp, kAccount.toLocalPort);
    return [self addTask:media callback:callback];
}

/// 请求更多操作；取消、关闭、暂停、继续、切换、
+ (PYIMModeNetwork*)chatC2CRequestOpr:(uint16_t)cmd callback:(NetWorkCallback)callback {
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0){
        if(callback)
            callback([[PYIMError alloc] initWithCmd:cmd status:C2S_ERR_NOTLOGIN]);
        return nil;
    }
    
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.cmdID = cmd;
    
    uint16_t type = kAccount.chatSave;
    
    if(cmd == C2C_CLOSE){
        kAccount.chatState = 0;
        
        kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
        kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
        
        CmdClose body = {0};
        body.type = type;
        body.account = htonll_x(kAccount.myAccount);
        body.toAccount = htonll_x(kAccount.toAccount);
        
        media.dataParam = [NSData dataWithBytes:&body length:sizeof(CmdClose)];
    }else if(cmd == C2C_CANCEL_REQUEST){
        kAccount.chatState = 0;
        
        if (type == P2P_CHAT_TYPE_VIDEO)
        {
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
//            pause_video();
        }
        else if (type == P2P_CHAT_TYPE_AUDIO)
        {
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
//            pause_video();
        }
        else
        {
            kAccount.chatType = kAccount.chatType & ~(1 << type);
        }
        
        CmdCancelRequest body = {0};
        body.type = type;
        body.account = htonll_x(kAccount.myAccount);
        body.toAccount = htonll_x(kAccount.toAccount);
        
        media.dataParam = [NSData dataWithBytes:&body length:sizeof(CmdCancelRequest)];
    }else if(cmd == C2C_SWITCH) {
        if (type == P2P_CHAT_TYPE_VIDEO)
        {
            kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_VIDEO);
            kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_AUDIO);
//            resume_video();
        }
        else if (type == P2P_CHAT_TYPE_AUDIO)
        {
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
            kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_AUDIO);
//            pause_video();
        }
        
        CmdSwitch req = {0};
        req.type = type;
        req.account = htonll_x(kAccount.myAccount);
        req.toAccount = htonll_x(kAccount.toAccount);
        media.dataParam = [NSData dataWithBytes:&req length:sizeof(CmdSwitch)];
    }
    
    return [self addTask:media callback:callback];
}

static int64_t g_frameID = 0;

// 发送视频音频
+ (PYIMModeNetwork*)chatC2CSendMedia:(PYIMModeAudio*)media callback:(NetWorkCallback)callback {
    if(kAccount.chatSave==0){
        if(callback)callback([[PYIMError alloc] initWithCmd:C2C_AUDIO_FRAME errDesc:@"还未开始聊天"]);
        return nil;
    }
    
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0){
        if(callback)
            callback([[PYIMError alloc] initWithCmd:C2C_AUDIO_FRAME status:C2S_ERR_NOTLOGIN]);
        return nil;
    }
    
    if([media isMemberOfClass:[PYIMModeVideo class]]){
        if(kAccount.srvState>0 && kAccount.toState>0 && kAccount.isTcp==0){
            if([kAccount.myIp isEqualToString:kAccount.toIp]){
                return [self chatC2CSendVideoEx:(PYIMModeVideo*)media callback:callback];
            }else {
                // p2p分包处理？
                PYIMModeVideo *mode = (PYIMModeVideo*)media;
                
                PYIMModeMedia *mediax = [[PYIMModeMedia alloc] init];
                mediax.mode = media; /// 已经处理好了
                mediax.cmdID = C2C_VIDEO_FRAME;
                
                NSData *sendData = [mediax encodeData:[PYIMNetworkManager sharedInstance].converterVideo];
                
                int encode_size = (int)sendData.length;
                if (encode_size < 1 || encode_size > (int)(P2P_MAX_BUF_SIZE - sizeof(Header) - sizeof(CmdVideoFrameEx)))
                {
                    NSLog(@"videoEncodeThread|x264_encode_frame fail:%d, len:%ti, width:%d, height:%d", encode_size, media.media.length, mode.width, mode.height);
                    return nil;
                }
                
                // 分片发送
                char *send_buf = (char*)sendData.bytes;
                int send_len = 0;
                int send_pos = 0;
                int pid = 0;
                int packs = encode_size%P2P_VIDEO_SLICE_SIZE==0?(encode_size/P2P_VIDEO_SLICE_SIZE):(encode_size/P2P_VIDEO_SLICE_SIZE+1);
                
                g_frameID++;
                while (send_pos < encode_size && kAccount.chatState>0) {
                    if ((send_pos + P2P_VIDEO_SLICE_SIZE) < encode_size) {
                        send_len = P2P_VIDEO_SLICE_SIZE;
                    } else {
                        send_len = encode_size - send_pos;
                    }
                    
                    PYIMModeVideo *video = [[PYIMModeVideo alloc] init];
                    video.media = [NSData dataWithBytes:send_buf length:send_len];
                    video.mirror = mode.mirror;
                    video.angle = mode.angle;
                    video.width = mode.width;
                    video.height = mode.height;
                    video.fps = mode.fps;
                    video.bitrate = mode.bitrate;
                    
                    video.frameID = g_frameID;
                    video.packs = packs;
                    video.pid = pid++;
                    video.frameLen = encode_size;
                    video.packLen = send_len;
                    
                    [self chatC2CSendVideo:video callback:callback];
                    
                    send_pos += send_len;
                    send_buf += send_len;
                }
                
                return nil;// 发送多个无返回
            }
        }else if(kAccount.videoState>0){
            return [self chatC2CSendVideoEx:(PYIMModeVideo*)media callback:callback];
        }
        
        return nil;
    }else if([media isKindOfClass:[PYIMModeAudio class]]){
        return [self chatC2CSendAudio:media callback:callback];
    }else
        return nil;
}

/// api中将消息进行封装成网络任务
+ (PYIMModeNetwork*)chatC2CSendAudio:(PYIMModeAudio*)data callback:(NetWorkCallback)callback {
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.mode = data; /// 已经处理好了
    media.cmdID = C2C_AUDIO_FRAME;
    
    CmdAudioFrame body = {0};
    body.account = htonll_x(kAccount.myAccount);
    body.toAccount = htonll_x(kAccount.toAccount);
//    body.timeStart = htonll_x(data.timeRecordStart);
//    body.timeEnd = htonll_x(data.timeRecordEnd);
    media.dataParam = [NSData dataWithBytes:&body length:sizeof(CmdAudioFrame)];
    
    return [self addTask:media callback:callback];
}

// 视频发送
+ (PYIMModeNetwork*)chatC2CSendVideo:(PYIMModeVideo*)video callback:(NetWorkCallback)callback {
    CmdVideoFrame body = {0};
    body.account = htonll_x(kAccount.myAccount);
    body.toAccount = htonll_x(kAccount.toAccount);
    body.width = htons_x(video.width);
    body.height = htons_x(video.height);
    body.fps = htons_x(video.fps);
    body.bitrate = htons_x(video.bitrate/1000);  // android need
    body.angle = htons_x(video.angle);
    body.mirror = htons_x(video.mirror);
    body.frameID = htonll_x(video.frameID);
    body.frameLen = htons_x(video.frameLen);
    body.packs = htons_x(video.packs);
    body.pid = htons_x(video.pid);
    body.packLen = htons_x(video.packLen);
    body.client = htons_x(Client_iOS);
//    body.timeStart = htonll_x(video.timeRecordStart);
//    body.timeEnd = htonll_x(video.timeRecordEnd);
    
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.mode = video; /// 已经处理好了
    media.cmdID = C2C_VIDEO_FRAME;
    media.dataParam = [NSData dataWithBytes:&body length:sizeof(CmdVideoFrame)];
    
    return [self addTask:media callback:callback];
}

// 视频发送Ex
+ (PYIMModeNetwork*)chatC2CSendVideoEx:(PYIMModeVideo*)video callback:(NetWorkCallback)callback {
    CmdVideoFrameEx body = {0};
    body.account = htonll_x(kAccount.myAccount);
    body.toAccount = htonll_x(kAccount.toAccount);
    body.width = htons_x(video.width);
    body.height = htons_x(video.height);
    body.fps = htons_x(video.fps);
    body.bitrate = htons_x(video.bitrate/1000);
    body.angle = htons_x(video.angle);
    body.mirror = htons_x(video.mirror);
    body.client = htons_x(Client_iOS);
//    body.timeStart = htonll_x(video.timeRecordStart);
//    body.timeEnd = htonll_x(video.timeRecordEnd);
    
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.mode = video;
    media.cmdID = C2C_VIDEO_FRAME_EX;
    media.dataParam = [NSData dataWithBytes:&body length:sizeof(CmdVideoFrameEx)];
    
    return [self addTask:media callback:callback];
}

@end
