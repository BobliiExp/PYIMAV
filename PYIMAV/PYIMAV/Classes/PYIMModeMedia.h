//
//  PYIMModeMedia.h
//  PYIMAV
//
//  Created by Bob Lee on 2018/4/26.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PYIMModeAudio.h"

//系统错误
#define    EVENT_ERROR  -1
//p2p连接失败
#define EVENT_P2P_DISCONNECT  -2
//发送请求超时
#define EVENT_REQUEST_TIMEOUT -3
//摄像头错误，打不开
#define EVENT_CAMERA_ERRO -4
//网络出错
#define EVENT_P2S_DISCONNECT -5
//视频服务器连接失败
#define EVENT_VIDEO_CONNECT_FAIL -6
//登陆错误
#define EVENT_P2S_LOGIN_FAIL -9
//对方发来视频请求
#define EVENT_REQUEST_VIDEO_BY_FRIEND 1
//对方发来语音请求
#define EVENT_REQUEST_AUDIO_BY_FRIEND 2
//对方发来文件请求
#define EVENT_REQUEST_FILE_BY_FRIEND 3
//对方取消了视频请求
#define EVENT_CANCEL_REQUEST_VIDEO_BY_FRIEND 4
//对方取消了语音请求
#define EVENT_CANCEL_REQUEST_AUDIO_BY_FRIEND 5
//对方取消了文件请求
#define EVENT_CANCEL_REQUEST_FILE_BY_FRIEND 6
//对方接受了视频请求
#define EVENT_ACCEPT_VIDEO_BY_FRIEND 7
//对方接受了语音请求
#define EVENT_ACCEPT_AUDIO_BY_FRIEND 8
//对方接受了文件请求
#define EVENT_ACCEPT_FILE_BY_FRIEND 9
//对方拒绝了视频请求
#define EVENT_REJECT_VIDEO_BY_FRIEND 10
//对方拒绝了语音请求
#define EVENT_REJECT_AUDIO_BY_FRIEND 11
//对方拒绝了文件请求
#define EVENT_REJECT_FILE_BY_FRIEND 12
//对方暂停了视频
#define EVENT_PAUSE_VIDEO_BY_FRIEND 13
//对方继续视频
#define EVENT_RESUME_VIDEO_BY_FRIEND 14
//对方关闭了视频通话
#define EVENT_CLOSED_VIDEO_BY_FRIEND 15
//对方暂停了声音
#define EVENT_PAUSE_AUDIO_BY_FRIEND 16
//对方打开了声音
#define EVENT_RESUME_AUDIO_BY_FRIEND 17
//对方关闭了语音通话
#define EVENT_CLOSED_AUDIO_BY_FRIEND 18
//对方SDK版本不支持
#define EVENT_SDK_NOT_SUPPORT_BY_FRIEND 19

//P2P连接建立成功
#define EVENT_P2P_CONNECT 20
//对方关闭了文件发送
#define EVENT_CLOSED_FILE_BY_FRIEND  21
//文本消息
#define EVENT_RECV_TEXT  22
//服务连接建立成功
#define EVENT_P2S_CONNECT 23
//视频服务器连接成功
#define EVENT_VIDEO_CONNECT_SUCC 24

//切换到语音模式
#define EVENT_P2S_SWITCH_AUDIO 29
//切换到视频模式
#define EVENT_P2S_SWITCH_VIDEO 30

extern ushort const kCMD_Re_ServerMsg;

typedef NS_ENUM(NSInteger, PYServerType) {
    EServer_None,
    EServer_Login,
    EServer_Audio,
    EServer_Video,
    
};

@interface PYIMError : NSObject <NSCopying>

@property (nonatomic, assign) uint16_t totalLen;    ///< 消息包长度
@property (nonatomic, assign) uint16_t cmdID;       ///< eg: C2C_AUDIO_FRAME
@property (nonatomic, readonly, assign) uint16_t seqID;       ///< 消息序列号，0开始自增，最大65534
@property (nonatomic, assign) uint16_t cmdStatus;   ///< 消息命令状态应答状态，返回时判断是否成功等情况
//@property (nonatomic, assign) uint16_t client; ///< 客户端类型

@property (nonatomic, assign) BOOL success;    ///< 是否操作成功
@property (nonatomic, copy) NSString *errDesc;    ///< 错误描述，内部根据cmd解析

@property (nonatomic, copy) NSData *dataParam;    ///< 其他参数，发送时API传入数据封装
@property (nonatomic, copy) NSData *dataMedia;    ///< 媒体数据

// 接收或者发送时的特定ip、断开，使用优先
@property (nonatomic, copy) NSString *rspIP;        ///< 接收到数据来源的ip；发送数据使用的ip，设置后优先使用
@property (nonatomic, assign) uint16_t rspPort;     ///< 接收到数据来源的port；发送数据使用的port，设置后优先使用

@property (nonatomic, assign) PYServerType sType;    ///< 连接服务器类型，内部根据指令判断

@property (nonatomic, strong) PYIMModeAudio *mode; ///< 音视频数据，接收时用

/// 解析从服务器获取到的二进制数据
- (instancetype)initWithData:(NSData*)data converter:(id)converter;
- (instancetype)initWithError:(NSString*)desc;
- (instancetype)initWithCmd:(uint16_t)cmd status:(uint16_t)status;
- (instancetype)initWithCmd:(uint16_t)cmd errDesc:(NSString*)errDesc;

@end

/// 消息其他内容封装
@interface PYIMModeMedia : PYIMError

@property (nonatomic, assign) uint64_t createdTime; ///< 创建时间毫秒
@property (nonatomic, readonly, assign) NSInteger timeOutSpan; ///< 超时时长，秒
@property (nonatomic, readonly, assign) BOOL timeOut; ///< 是否超时可以丢弃了
@property (nonatomic, assign) NSInteger sendCount; ///< 尝试重发次数
@property (nonatomic, assign) NSInteger resentCount; ///< 可以重发次数

@property (nonatomic, assign) int64_t sender; ///< 发送者，默认就是自己
@property (nonatomic, assign) int64_t reciver; ///< 接收者

@property (nonatomic, readonly, assign) BOOL isSendBySelf; ///< 是否自己发送
@property (nonatomic, readonly, assign) BOOL shouldRecResponse;    ///< 是否必须接受服务器返回

- (void)prepareReSend;

/// 获取发送的二进制数据
- (NSData*)getSendData:(id)converter;

/// 语音停止后充值序列号
+ (void)resetSerialNumber;

- (NSData*)encodeData:(id)converter;

@end

typedef void(^NetWorkCallback)(PYIMError *error);    /// API层统一回调

@interface PYIMModeNetwork : NSObject <NSCopying>

@property (nonatomic, readonly, assign) BOOL needClean; ///< 超出30秒任务直接移除
@property (nonatomic, assign) long tagSelf;   ///< 确认任务自己唯一标志，自己内存地址
@property (nonatomic, readonly, assign) BOOL timeOut;  
@property (nonatomic, readonly, assign) uint16_t cmdID;       ///< eg: C2C_AUDIO_FRAME
@property (nonatomic, readonly, assign) uint16_t seqID;       ///< 消息序列号，0开始自增，最大65534
@property (nonatomic, strong) PYIMModeMedia *media; ///< 媒体数据
@property (nonatomic, copy) NetWorkCallback callback; ///< 回调

@property (nonatomic, readonly, assign) BOOL resendable; ///< 是否可以重发
@property (nonatomic, readonly, assign) BOOL shouldRecResponse;    ///< 是否必须接受服务器返回

// udp发送时使用的ip，端口
@property (nonatomic, copy) NSString *hostServer;
@property (nonatomic, assign) uint16_t portServer;

- (void)finished:(PYIMError*)error;
- (void)finishedWithCode:(uint16_t)errorCode;
- (void)finishedWithErrDesc:(NSString*)desc;

+ (NSArray<PYIMModeMedia*>*)cutPackage:(NSData *)data converter:(NSArray*)converters callback:(void(^)(NSData *dataPart))callback;

@end
