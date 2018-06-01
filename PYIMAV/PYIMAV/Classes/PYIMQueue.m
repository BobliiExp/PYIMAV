//
//  PYIMQueue.m
//  PYIMAV
//
//  Created by Bob Lee on 2018/4/26.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYIMQueue.h"

static NSInteger const kDefaultSize = 10;

@interface PYIMQueue()

@property (nonatomic, assign) int first;
@property (nonatomic, assign) int last;
@property (nonatomic, assign) NSUInteger capacity;
@property (nonatomic, strong) NSMutableArray *elementData;

@end

@implementation PYIMQueue

- (instancetype)initWithCapcity:(NSUInteger)capacity {
    self = [super init];
    if(self){
        _first = - 1 ;
        _last = - 1 ;
        _capacity = capacity;
        _elementData = [[NSMutableArray alloc] initWithCapacity:capacity];
    }
    
    return self ;
}

- (instancetype)init {
    return [self initWithCapcity:kDefaultSize];
}

- (BOOL)isFull {
    return (_first == 0 && _last == _capacity - 1) || _first == _last + 1 ;
}

- (BOOL)isEmpty {
    return _first == - 1 ;
}

- (void)push:(id)item {
    if (![self isFull]) {
        if (_last == _capacity - 1 || _last == - 1) {
            _elementData [0] = item;
            _last = 0 ;
            if (_first == - 1){
                _first = 0 ;
            }
        } else {
            _elementData [++ _last] = item;
        }
    } else {
        _capacity ++;
        _last ++;
        [_elementData addObject:item];
    }
}

- (id)pop {
    if (![self isEmpty]) {
        NSObject *tmp = _elementData[_first];
        if (_first == _last ){
            _last = _first = - 1 ;
        } else if (_first == _capacity - 1){
            _first = 0 ;
        } else {
            _first ++;
        }
        return tmp;
    } else {
//        NSLog ( @"Fail :Queue is Empty" );
        return nil ;
    }
}

- (void)dispose {
    [self.elementData removeAllObjects];
    self.elementData = nil;
}

- (void)cleanSelf {
    NSLog(@"重定向，处理了videoController没有定义：%@崩溃问题", NSStringFromSelector(_cmd));
}
@end
