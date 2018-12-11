//
//  PYIMModeAudio.h
//  PYIMAV
//
//  Created by Bob Lee on 2018/5/15.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PYConfig.h"

typedef NS_ENUM(NSInteger, PYIMMediaState) {
    EMediaState_Stoped,     ///< 未开启（未初始化相关设置）
    EMediaState_Playing,    ///< 正在播放（可能暂停相关业务）
    EMediaState_Paused,     ///< 暂停状态（内部控制，根据数据接收情况以及网络情况控制）
};

@interface PYIMModeAudio : NSObject <NSCopying>

@property (nonatomic, copy) NSData *media;
@property (nonatomic, assign) BOOL is8kTo8k;    ///< 是否8k录制
@property (nonatomic, assign) int64_t timeRecordEnd; ///< 录制完成时间
@property (nonatomic, assign) int64_t timeRecordStart; ///< 录制开始时间，第一个包是连接成功时间，后面的包就是上一个包的录制完成时间
@property (nonatomic, assign) PYClientType client; ///< 客户端类型

- (instancetype)initWithData:(NSData*)data converter:(id)converter;

@end

@interface PYIMModeVideo : PYIMModeAudio

@property (nonatomic, assign) int64_t frameID;//帧id
@property (nonatomic, assign) int width;
@property (nonatomic, assign) int height;
@property (nonatomic, assign) int fps;
@property (nonatomic, assign) int angle;
@property (nonatomic, assign) int mirror; // front camera = 1
@property (nonatomic, assign) int bitrate;

@property (nonatomic, assign) uint16_t frameLen;//帧长度
@property (nonatomic, assign) uint16_t packs;//帧的包数
@property (nonatomic, assign) uint16_t pid;//包ID
@property (nonatomic, assign) uint16_t packLen;//包长度

@property (nonatomic, readonly, assign) BOOL isFinish; ///< 是否接收完成

/// 分包处理时加入包
- (void)appendPacket:(PYIMModeVideo*)packet;

- (instancetype)initWithDataEx:(NSData*)data converter:(id)converter;

@end
