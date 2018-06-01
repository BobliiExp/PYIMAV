//
//  PYIMNetworkManager.h
//  PYIMAV
//
//  Created by Bob Lee on 2018/4/26.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PYIMModeMedia.h"

#import "PYIMVideoConverter.h"
#import "PYIMAudioConverter.h"

/**
 注意内部保持三个socket链接，分别对应登录、音频、视频服务器，自己根据cmd判断走哪个
 */
@interface PYIMNetworkManager : NSObject

@property (nonatomic, strong) PYIMAudioConverter *converter; ///< 转换器
@property (nonatomic, strong) PYIMVideoConverter *converterVideo; ///< 视频转化器

+ (instancetype)sharedInstance;

+ (void)connectWithHost:(NSString*)host port:(ushort)port;

+ (void)addTask:(PYIMModeNetwork*)media;

+ (void)cancelTask:(NSArray*)tasks;

@end
