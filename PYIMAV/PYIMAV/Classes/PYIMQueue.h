//
//  PYIMQueue.h
//  PYIMAV
//
//  Created by Bob Lee on 2018/4/26.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <Foundation/Foundation.h>
/// 以队列方式管理播放内容，方便接收排队播放；但是需要考虑队列已满情况（一般情况此模型只用于一边消费，一边生产情况，如果已经没有消费了，也会停止生产）
@interface PYIMQueue : NSObject

- (instancetype)initWithCapcity:(NSUInteger)capacity;
- (void )push:(id)item;
- (id)pop;

- (BOOL)isEmpty;
- (BOOL)isFull;

- (void)dispose;

- (void)cleanSelf; // test runtime invoke

@end
