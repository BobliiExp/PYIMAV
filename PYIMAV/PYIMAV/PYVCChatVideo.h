//
//  PYVCChatVideo.h
//  PYIMAV
//
//  Created by Administrator on 2018/4/23.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PYVCChatVideo : UIViewController

@property (nonatomic, assign) BOOL isRequest; ///< 是否别人发来的请求
@property (nonatomic, assign) BOOL isLocal; ///< 本地测试
@property (nonatomic, assign) BOOL isCompress; ///< 是否压缩
@property (nonatomic, assign) BOOL is8kTo8k; ///< 本地8k验证
@property (nonatomic, assign) int toAccount; ///< 主动链接的人

@end
