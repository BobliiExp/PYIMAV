//
//  PYIMVideoController.h
//  PYIMAV
//
//  Created by Bob Lee on 2018/5/16.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#import "PYIMModeAudio.h"

@interface PYIMVideoController : NSObject

@property (nonatomic, readonly, assign) BOOL isPlaying; ///< 是否正在运行
@property (nonatomic, assign) BOOL isLocal; ///< 本地测试
@property (nonatomic, assign) BOOL is8kTo8k; ///< 本地8k验证
@property (nonatomic, assign) BOOL isCompress; ///< 是否压缩
@property (nonatomic, assign) BOOL isFilter; ///< 是否美化

/**
 * @brief 初始化视频录制需要的相关对象属性
 * @param viewbg 背景视频播放依赖的view
 * @param viewfront 前面窗口播放的小view
 * @return PYIMVideoController 通过公开方法调整播放配置
 */
- (instancetype)initWithBGView:(UIView*)viewbg front:(UIView*)viewfront;

/// 切换录制摄像头
- (void)switchCamera;

/// 切换视频播放依赖的窗口（背景窗口与小窗口的内容进行切换）
- (void)switchPlayWindow;

#pragma mark - 操作控制主要用于播放接收数据；音频是一直不断的，所以通过视频播放控制同步问题

/// 暂停录制与播放
- (void)pause;
- (void)pauseUntil:(NSTimeInterval)timespan;

/// 回复录制与播放
- (void)resume;

#pragma mark - end

/// 开始视频模块
- (void)start:(void(^)(PYIMMediaState state))block;

/// 停止播放，清理相关数据（不可以在resume)
- (void)stop;

/// 播放视频数据
- (void)playMedia:(PYIMModeVideo*)media;

/// 录制视频关联，启动后就会开始预览，连接通后开始数据传输
- (void)recordMedia:(void(^)(PYIMModeVideo *media))block;

@end
