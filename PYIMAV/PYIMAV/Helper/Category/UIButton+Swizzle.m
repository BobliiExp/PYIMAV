//
//  UIButton+Swizzle.m
//  PYIMAV
//
//  Created by Bob Lee on 2018/5/28.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "UIButton+Swizzle.h"
#import <objc/runtime.h>
#import <RSSwizzle.h>

static long const kMinEventTimeInterval = 300; // 毫秒

@implementation UIButton (Swizzle)

- (void)setAcceptEventTime:(long)acceptEventTime {
    objc_setAssociatedObject(self, @selector(acceptEventTime), @(acceptEventTime), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (long)acceptEventTime {
    return [objc_getAssociatedObject(self, @selector(acceptEventTime)) longValue];
}

- (void)setEventTimeInterval:(long)eventTimeInterval {
    objc_setAssociatedObject(self, @selector(eventTimeInterval), @(eventTimeInterval), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (long)eventTimeInterval {
    return [objc_getAssociatedObject(self, @selector(eventTimeInterval)) longValue];
}

+ (void)load {
    RSSwizzleInstanceMethod([UIButton class], @selector(sendAction:to:forEvent:), RSSWReturnType(void), RSSWArguments(SEL action,id target,UIEvent *event), RSSWReplacement({
        UIButton *btn = self;
        if ([NSDate date].timeIntervalSince1970*1000 - btn.acceptEventTime < MAX(btn.eventTimeInterval, kMinEventTimeInterval)) {
            return;
        }
        
        if (MAX(btn.eventTimeInterval, kMinEventTimeInterval) > 0) {
            btn.acceptEventTime = [NSDate date].timeIntervalSince1970*1000;
        }
        RSSWCallOriginal(action,target,event);
    }), RSSwizzleModeAlways, NULL);
}

@end
