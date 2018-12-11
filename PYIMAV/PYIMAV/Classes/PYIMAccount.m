//
//  PYIMAccount.m
//  PYIMAV
//
//  Created by Bob Lee on 2018/4/29.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYIMAccount.h"
#import "pdu.h"

NSString * const kNotificationPY_NetworkStatusChanged = @"kNotificationPY_NetworkStatusChanged";
NSString * const kNotificationPY_ResponseServer = @"kNotificationPY_ResponseServer";

@implementation PYIMAccount

static PYIMAccount *account;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        account = [[self alloc] init];
    });
    
    return account;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        //        self.efd = epoll_create(1024);
        //        self.srvSock = -1;
        self.isTcp = 0;
        self.srvTid = 0;
        //        pthread_mutex_init(&self.mtx, NULL);
        self.terminate = 0;
        
        self.srvState = 0;
        self.srvSendTime = 0;
        self.srvRecvTime = 0;
        self.srvSendSeq = 0;
        
        //        self.videoSock = -1;
        self.videoState = 0;
        self.videoConnected = 0;
        self.videoSendTime = 0;
        self.videoRecvTime = 0;
        self.videoConnTime = 0;
        
        //        self.audioSock = -1;
        self.audioState = 0;
        self.audioSendTime = 0;
        self.audioRecvTime = 0;
        
        self.myAccount = 0;
        self.myIp = @"";
        self.myPassword = @"";
        self.myLocalIp = @"";
        self.myPort = 0;
        self.myLocalPort = 0;
        
        self.toAccount = 0;
        self.toIp = @"";
        self.toPort = 0;
        self.toLocalIp = @"";
        self.toLocalPort = 0;
        
        self.toState = 0;
        self.toSendTime = 0;
        self.toRecvTime = 0;
        self.chatType = P2P_CHAT_TYPE_MASK_NORMAL;
        self.chatState = 0;
        self.chatTimeout = 10;
        self.chatLastTime = time(NULL);
        
        self.videoSize = P2P_MAX_BUF_SIZE;
        self.videoLen = 0;
        self.frameID = 0;
        
        self.mArrAudio = [NSMutableArray array];
    }
    
    return self;
}

- (void)updateWithHost:(NSString*)host port:(uint16_t)port {
    self.srvIp = host;
    self.srvPort = port;
    self.videoIp = host;
    self.videoPort = port+2;
    self.audioIp = host;
    self.audioPort = port+1;
}

- (void)resetAccount {
    _chatState = 0;
    _toAccount = 0;
    _toIp = nil;
    _toPort = 0;
    _toLocalIp = nil;
    _toLocalPort = 0;
    
    _toState = 0;
    _toSendTime = 0;
    _toRecvTime = time(NULL);
    
//    _srvState = 0;
    _srvSendTime = 0;
    _srvRecvTime = time(NULL);
    
//    _videoState = 0;
    _videoSendTime = time(NULL);
    
//    _audioState = 0;
    _audioSendTime = time(NULL);
}

- (NSString*)chatTypeName {
    switch (self.chatType) {
        case P2P_CHAT_TYPE_AUDIO: { return @"语音"; }
        case P2P_CHAT_TYPE_VIDEO: { return @"视频"; }
            
        default: { return [NSString stringWithFormat:@"%d", self.chatType]; }
    }
}

@end
