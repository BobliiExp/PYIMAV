//
//  PYNoteManager.h
//  PYIMAV
//
//  Created by Bob Lee on 2018/5/16.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <Foundation/Foundation.h>

#define IOS_VERSION [[[UIDevice currentDevice] systemVersion] floatValue]

#define kNote  [PYNoteManager sharedInstance]


/**
 * TimeFormatType
 * 说明
 */
typedef NS_ENUM(char, AFFTimeFormatType) {
    /** yyyy-MM-dd */
    ETimeFormatTimeDate, //日期
    /** yyyy年MM月dd日 */
    ETimeFormatTimeDate_CN,
    /** yyyy.MM.dd */
    ETimeFormatTimeDateEx, //日期
    /** yyyy-MM-dd hh:mm:ss */
    ETimeFormatTimeCommon,//普通
    /** yyyy-MM-dd hh:mm */
    ETimeFormatTimeShort, //
    /** yyyy-MM-dd hh:mm:ss SSS */
    ETimeFormatTimeLong, //
    /** yyyyMMddhhmmSSS */
    ETimeFormatTimeMask, //
    /** hh:mm */
    ETimeFormatTimeTime, //
    /** hh */
    ETimeFormatTimeHour,
    /** mm */
    ETimeFormatTimeMinute,
    /** yyyy */
    ETimeFormatTimeYear,
    /** MM */
    ETimeFormatTimeMonth,
    /** yyyy年MM月 */
    ETimeFormatTimeMonth_CN,
    /** dd */
    ETimeFormatTimeDay,
    /** SSS */
    ETimeFormatTimeSecond,
    /** MM-dd */
    ETimeFormatTimeShortDate,
    /** MM-dd hh:mm */
    ETimeFormatTimeShortDateTime,
    /** MM月dd日 hh:mm */
    ETimeFormatTimeShortDateTime_CN,
    /** MM月dd日 */
    ETimeFormatTimeShortDate_CN,
    
    // 特殊格式
    
    /** yyyy.MM.dd */
    ETimeFormatTimeDateDotSpan
};

@interface PYNoteManager : NSObject

@property (nonatomic, readonly) NSMutableString *noteInfo;   ///< 日志信息，注意初始化从文件读取（文件按照日期控制）,其后内存管理

+ (instancetype)sharedInstance;

/**
 * @brief 增加日志记录
 * @param note 记录信息，注意时间戳不用带
 */
- (void)writeNote:(NSString*)note;

/**
 * @brief 保存日志信息到文件，一半外部不要调用
 */
- (void)saveNote;

/**
 * @brief 观察日志变化
 * @param block 变化通知外部，外部调用noteInfo信息展示即可
 */
- (void)addObserverForNoteChanged:(void(^)(void))block;

+ (NSArray *)loadFiles;

+ (NSString *)date2String:(NSDate *)date formatType:(AFFTimeFormatType)type;

@end
