//
//  PYIMAudioController.h
//  PYIMAV
//
//  Created by 002 on 2018/4/25.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PYIMModeAudio.h"
#import "PYConfig.h"

@interface PYIMAudioController : NSObject

@property (nonatomic, readonly, assign) BOOL isPlaying; ///< 是否正在运行
@property (nonatomic, assign) BOOL isLocal; ///< 本地测试
@property (nonatomic, assign) BOOL is8kTo8k; ///< 本地8k验证
@property (nonatomic, assign) BOOL isCompress; ///< 是否压缩
@property (nonatomic, assign) PYIMCodecType tCodec; ///< 解压缩类型
@property (nonatomic, assign) NSInteger cacheSize; ///< 是否缓冲

/// 播放接收到的语音数据，注意播放类会一直尝试播放新放入buffer的内容；但是语音如果间断来一个可能会影响体验，因为每个包直邮几kb需要缓冲几个包才播放，后期考虑支持缓冲处理
- (void)playAudio:(PYIMModeAudio*)media;

/// 录制语音，通过回调buffer得到，注意已经默认进行了echo处理，得到PCM格式数据，外部在子线程进行编码转换
- (void)recordAudio:(void(^)(NSData *media))block;

/// 开启语音模块功能
- (void)startAudio:(void(^)(PYIMMediaState state))block;

/// 暂停录制与播放
- (void)pause;

/// 回复录制播放
- (void)resume;

/// 关闭语音模块功能，退出语音时调用，会清理相关内存
- (void)stopAudio;

- (void)monitorProximity;

/// 切换播放硬件，扬声器或者听筒
- (void)sessionCategoryChanged:(BOOL)speaker;

@end
