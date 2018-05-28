//
//  PYIMAPIChat.h
//  PYIMAV
//
//  Created by 002 on 2018/4/26.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PYIMModeMedia.h"

/**
 注意：
    API返回对象，只有支持shouldRecResponse=YES的才有效；一般返回对象就是控制下失败重发次数
 */
@interface PYIMAPIChat : NSObject

/// 链接服务器
+ (void)chatConnectHost:(NSString*)host port:(ushort)port;

/// 服务器P、2P主动通知
+ (void)chatObserverServer:(NetWorkCallback)callback;

#pragma mark - C2S

/// 登录服务器
+ (PYIMModeMedia*)chatLogin:(uint64_t)account pwd:(NSString*)pwd callback:(NetWorkCallback)callback;

/// 退出登录
+ (PYIMModeMedia*)chatLogout:(NetWorkCallback)callback;

/// 发起通话请求 类型  1视频  2语音
+ (PYIMModeMedia*)chatGetAccount:(uint64_t)to type:(int16_t)type callback:(NetWorkCallback)callback;

#pragma mark - C2C

/// 接受请求操作;return yes界面判断是否开启语音或视频
+ (PYIMModeMedia*)chatC2CRequestAccept:(BOOL)accept callback:(NetWorkCallback)callback;

/// 请求更多操作；取消、关闭、暂停、继续、切换、
+ (PYIMModeMedia*)chatC2CRequestOpr:(uint16_t)cmd callback:(NetWorkCallback)callback;

/// 发送视频，音频
+ (PYIMModeMedia*)chatC2CSendMedia:(PYIMModeAudio*)media callback:(NetWorkCallback)callback;

/// 请求链接 getAccount成功后调用
+ (PYIMModeMedia*)chatC2CHole:(NetWorkCallback)callback;

/// 收到打洞请求回复
+ (PYIMModeMedia*)chatC2CHoleResp:(NSString*)ip port:(uint16_t)port callback:(NetWorkCallback)callback;

/// 请求通话 getAccount成功后调用
+ (PYIMModeMedia*)chatC2CRequest:(NetWorkCallback)callback;

@end
