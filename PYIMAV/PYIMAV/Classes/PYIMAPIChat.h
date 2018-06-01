//
//  PYIMAPIChat.h
//  PYIMAV
//
//  Created by Bob Lee on 2018/4/26.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PYIMModeMedia.h"

/**
 注意：
    API返回对象，只有支持shouldRecResponse=YES的才有效；一般返回对象就是控制下失败重发次数
 */
@interface PYIMAPIChat : NSObject

+ (void)cancelTask:(NSArray*)tasks;

/// 链接服务器
+ (void)chatConnectHost:(NSString*)host port:(ushort)port;

/// 服务器P、2P主动通知
+ (void)chatObserverServer:(NetWorkCallback)callback;

#pragma mark - C2S

/// 登录服务器
+ (PYIMModeNetwork*)chatLogin:(uint64_t)account pwd:(NSString*)pwd callback:(NetWorkCallback)callback;

/// 退出登录
+ (PYIMModeNetwork*)chatLogout:(NetWorkCallback)callback;

/// 发起通话请求 类型  1视频  2语音
+ (PYIMModeNetwork*)chatGetAccount:(uint64_t)to type:(int16_t)type callback:(NetWorkCallback)callback;

#pragma mark - C2C

/// 接受请求操作;return yes界面判断是否开启语音或视频
+ (PYIMModeNetwork*)chatC2CRequestAccept:(BOOL)accept callback:(NetWorkCallback)callback;

/// 请求更多操作；取消、关闭、暂停、继续、切换、
+ (PYIMModeNetwork*)chatC2CRequestOpr:(uint16_t)cmd callback:(NetWorkCallback)callback;

/// 发送视频，音频
+ (PYIMModeNetwork*)chatC2CSendMedia:(PYIMModeAudio*)media callback:(NetWorkCallback)callback;

/// 请求链接 getAccount成功后调用
+ (PYIMModeNetwork*)chatC2CHole:(NetWorkCallback)callback;

/// 收到打洞请求回复
+ (PYIMModeNetwork*)chatC2CHoleResp:(NSString*)ip port:(uint16_t)port callback:(NetWorkCallback)callback;

/// 请求通话 getAccount成功后调用
+ (PYIMModeNetwork*)chatC2CRequest:(NetWorkCallback)callback;

@end
