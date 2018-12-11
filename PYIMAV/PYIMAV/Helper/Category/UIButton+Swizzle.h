//
//  UIButton+Swizzle.h
//  PYIMAV
//
//  Created by Bob Lee on 2018/5/28.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <UIKit/UIKit.h>
/**
 控制按钮点击间隔
 */
@interface UIButton (Swizzle)

@property (nonatomic, assign) long acceptEventTime; ///< 最近一次点击时间
@property (nonatomic, assign) long eventTimeInterval; ///< 按钮有效点击时间间隔 - 毫秒，间隔内不响应点击

@end
