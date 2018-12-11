//
//  PYIMVideoConverter.h
//  PYIMAV
//
//  Created by Bob Lee on 2018/5/16.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "PYConfig.h"
#import "STMGLView.h"

#import "PYIMModeAudio.h"

// 注意320*240 适用于移动设备webCam
#define ENCODE_FRMAE_WIDTH      320     // 编码的图像宽度
#define ENCODE_FRMAE_HEIGHT     240     // 编码的图像高度
#define VIDEO_FPS       10
#define VIDEO_BITRATE   128000

@interface PYIMVideoConverter : NSObject

/// 采集 - 将录制的sample转换为NSData，其中会进行PUV转换处理
+ (PYIMModeVideo*)convertSample:(CMSampleBufferRef)sample;
+ (PYIMModeVideo*)convertSampleEx:(CVPixelBufferRef)imageBuffer;

/// 编码 -  编码视频数据(convertSample)，默认采用x264算法
- (NSData*)encode:(PYIMModeVideo*)video;

/// 接收解码 - 解码视频数据，默认采用h264算法
- (NSData*)decode:(char*)buffer length:(int)length video:(PYIMModeVideo*)video;

/// 展示 - render解码后的视频帧
+ (void)convertYUV:(STMGLView*)render video:(PYIMModeVideo*)video;

- (void)dispose;

@end
