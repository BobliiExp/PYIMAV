//
//  PYIMAccount.h
//  PYIMAV
//
//  Created by Bob Lee on 2018/4/29.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSDictionary+SafeAccess.h"
#import "PYNoteManager.h"
#import "PYConfig.h"

#import <EXTScope.h>

#define kAccount  [PYIMAccount sharedInstance]

extern NSString * const kNotificationPY_NetworkStatusChanged;     ///< {@"state":@(PYNetworkSocketState), @"server":@(PYServerType), @"local":@(BOOL)} // local:是否自己端
extern NSString * const kNotificationPY_ResponseServer;     ///< PYIMError 对象，广播服务器收到的通知

@interface PYIMAccount : NSObject

//@property (nonatomic, assign) int efd;                // epoll fd
//@property (nonatomic, assign) int srvSock;            // udp socket句柄
@property (nonatomic, assign) uint8_t isTcp;            // 是否强制走tcp中转(0:否, 1:是)
@property (nonatomic, assign) fd_set srvNewrset;        // udp 事件集
@property (nonatomic, assign) pthread_t srvTid;        // udp 线程ID
@property (nonatomic, assign) pthread_t videoTid;        // video 线程ID

@property (nonatomic, assign) pthread_mutex_t mtx;    // 互斥锁
@property (nonatomic, assign) uint8_t terminate;        // 退出标记

@property (nonatomic, copy) NSString *srvIp;
@property (nonatomic, assign) uint16_t srvPort;        // 服务器端口
@property (nonatomic, assign) uint8_t srvState;        // 与服务器连接状态
@property (nonatomic, assign) long srvSendTime;        // 最后往服务器发送数据的时间
@property (nonatomic, assign) long srvRecvTime;        // 最后接收到服务器数据的时间
@property (nonatomic, assign) int64_t srvSendSeq;        // 最后发送数据到服务器的序列号
@property (nonatomic, copy) NSString *videoIp;        // video 中转服务器IP
@property (nonatomic, assign) uint16_t videoPort;        // video 中转服务器PORT
//@property (nonatomic, assign) int videoSock;            // video 中转服务器tcp句柄
@property (nonatomic, assign) BOOL hadLoginVideo;    ///< 是否登录视频服务器
@property (nonatomic, assign) uint8_t videoState;        // video 状态
@property (nonatomic, assign) uint8_t videoConnected;    // video 连接状态
@property (nonatomic, assign) long videoSendTime;         // video 发送时间
@property (nonatomic, assign) long videoRecvTime;         // video 接收时间
@property (nonatomic, assign) long videoConnTime;        // video 连接时间

@property (nonatomic, copy) NSString *audioIp;        // audio 中转服务器IP
@property (nonatomic, assign) uint16_t audioPort;        // audio 中转服务器PORT
//@property (nonatomic, assign) int audioSock;            // audio 中转服务器tcp句柄
@property (nonatomic, assign) BOOL hadLoginAudio;    ///< 是否登录语音服务器
@property (nonatomic, assign) uint8_t audioState;        // audio 状态
@property (nonatomic, assign) long audioSendTime;         // audio 发送时间
@property (nonatomic, assign) long audioRecvTime;         // audio 接收时间

@property (nonatomic, assign) int64_t myAccount;        // 自己帐号
@property (nonatomic, copy) NSString *myPassword;    // 自己密码
@property (nonatomic, copy) NSString *myIp;            // 自己IP
@property (nonatomic, assign) uint16_t myPort;        // 自己PORT
@property (nonatomic, copy) NSString *myLocalIp;        // 自己本地IP
@property (nonatomic, assign) uint16_t myLocalPort;    // 自己本地PORT

@property (nonatomic, assign) int64_t toAccount;        // 对方帐号
@property (nonatomic, copy) NSString *toIp;            // 对方IP
@property (nonatomic, assign) uint16_t toPort;        // 对方PORT
@property (nonatomic, copy) NSString *toLocalIp;        // 对方本地IP
@property (nonatomic, assign) uint16_t toLocalPort;    // 对方本地PORT
@property (nonatomic, assign) uint8_t toState;        // 与对方连接状态
@property (nonatomic, assign) long toSendTime;            // 最后往对方发送数据的时间
@property (nonatomic, assign) long toRecvTime;            // 最后接收到对方数据的时间

@property (nonatomic, readonly, copy) NSString *chatTypeName; ///< 聊天类型描述
@property (nonatomic, assign) uint8_t chatType;        // 聊天类型掩码
@property (nonatomic, assign) uint8_t chatSave;        // 请求类型保存
@property (nonatomic, assign) uint8_t chatState;        // 在会话状态
@property (nonatomic, assign) int chatTimeout;        // 聊天超时
@property (nonatomic, assign) time_t chatLastTime;    // 最后聊天时间

@property (nonatomic, assign) uint64_t frameID;        // 视频帧
//@property (nonatomic, assign) uint8_t *videoBuf;        // 视频缓冲区
@property (nonatomic, assign) uint16_t videoSize;        // 视频缓冲区大小
@property (nonatomic, assign) uint16_t videoLen;        // 视频长度

//@property (nonatomic, assign) uint8_t *swapBuf;        // 交换缓冲区

//@property (nonatomic, assign) uint8_t *fileBuf;        // 文件缓冲区
@property (nonatomic, assign) uint32_t fileLen;        // 文件长度
@property (nonatomic, assign) uint32_t bid;            // 当前块
@property (nonatomic, assign) uint32_t blocks;        // 当前块
@property (nonatomic, assign) uint16_t fileType;        // 文件类型
@property (nonatomic, assign) uint8_t *fileName;        // 文件名
@property (nonatomic, assign) long     blockTime;        // block时间

@property (nonatomic, assign) BOOL hadLogin; ///< 是否登录登录服务器

// 携带从某个服务器、客户端得到数据时的ip，port
@property (nonatomic, strong) NSString *rspIp;        // 收到服务器、客户端ip
@property (nonatomic, assign) uint16_t rspPort;        // 收到服务器、客户端端口

@property (nonatomic, strong) NSMutableArray<PYIMAccount*> *mArrP2P;    ///< p2p链接列表
@property (nonatomic, strong) NSMutableArray *mArrAudio;

// 延时同步控制，每次消耗后置0
@property (nonatomic, assign) uint64_t timeDelayOfVideo; ///< 视频是否需要暂停等待时长，毫秒
@property (nonatomic, assign) uint64_t timeDelayOfAudio; ///< 音频是否需要暂停等待时长，毫秒


+ (instancetype)sharedInstance;
- (void)updateWithHost:(NSString*)host port:(uint16_t)port;
- (void)resetAccount;

@end
