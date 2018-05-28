//
//  PYNoteManager.m
//  PYIMAV
//
//  Created by 002 on 2018/5/16.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYNoteManager.h"
#import "NSDictionary+SafeAccess.h"
#import "sys/utsname.h"

@interface PYNoteManager() {
    dispatch_queue_t queueR;
}

@property (nonatomic, copy) void(^noteChanged)(void);
@property (nonatomic, readonly) BOOL isEnable;   ///< 是否启用

@end

static PYNoteManager *sharedInstance;

@implementation PYNoteManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if(self){
        if(self.isEnable){
            queueR = dispatch_queue_create("note_queue", DISPATCH_QUEUE_SERIAL);
            NSError *error;
            _noteInfo = [NSMutableString stringWithContentsOfFile:[PYNoteManager fileName] encoding:NSUTF8StringEncoding error:&error];
            
            if(_noteInfo==nil){
                _noteInfo = [NSMutableString string];
                [_noteInfo appendFormat:@"%@ %f", [self.class deviceVersion], IOS_VERSION];
                [self saveNote];
            }
            
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doingCache:) name:UIApplicationWillResignActiveNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doingCache:) name:UIApplicationWillTerminateNotification object:nil];
        }
    }
    return self;
}

- (BOOL)isEnable {
#ifdef DEBUG
    return YES;
#else
    return NO;
#endif
}

#pragma mark 业务处理


#pragma mark helper

- (void)doingCache:(NSNotification*)sender {
    [self saveNote];
}

- (void)writeNote:(NSString *)note {
    if(_noteInfo){
        dispatch_sync(queueR, ^{
            [self.noteInfo appendFormat:@"\n%@:%@", [PYNoteManager date2String:[NSDate date] formatType:ETimeFormatTimeLong], note];
            if(self.noteChanged){
                self.noteChanged();
            }
        });
    }
}

- (void)saveNote {
    if(_noteInfo){
        dispatch_barrier_sync(queueR, ^{
            NSString *fileName = [PYNoteManager fileName];
            NSError *error;
            [_noteInfo writeToFile:fileName atomically:YES encoding:NSUTF8StringEncoding error:&error];
        });
    }
}

- (void)addObserverForNoteChanged:(void (^)(void))block {
    self.noteChanged = block;
}

+ (NSDateFormatter *)formatter {
    
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setTimeZone:[NSTimeZone systemTimeZone]];
        [formatter setLocale:[NSLocale currentLocale]];
        [formatter setFormatterBehavior:NSDateFormatterBehaviorDefault];
        
//        [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    });
    
    return formatter;
}

static NSString *markFilePrefix = nil;
+ (NSString*)fileName {
    NSString *newDate = [self date2String:[NSDate date] formatType:ETimeFormatTimeDate];
    if(![newDate isEqualToString:markFilePrefix] || markFilePrefix==nil){
        markFilePrefix = newDate;
        [self checkPath];
    }
    
    return [NSString stringWithFormat:@"%@/%@.txt", [self getNoteFilePath], markFilePrefix];
}

+ (NSString*)getNoteFilePath {
    NSString *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    path = [NSString stringWithFormat:@"%@/Ponyo/Note", path];
    return path;
}

/// 检查文件夹文件是否存在
+ (void)checkPath {
    NSFileManager *fileManager =[NSFileManager defaultManager];
    NSError *error;
    
    if(![fileManager fileExistsAtPath:[self getNoteFilePath]]){
        [fileManager createDirectoryAtPath:[self getNoteFilePath] withIntermediateDirectories:YES attributes:nil error:&error];
        
    }else {
        // 文件只保留了一周内的
        NSArray *arr = [self loadFiles];
        if(arr.count>0){
            for(NSInteger i=arr.count-1; i>=0; i--){
                NSDictionary *dic = [arr objectAtIndex:i];
                if([self daysAfterDate:[dic dateForKey:@"time" dateFormat:@"yyyy-MM-dd"]]>7){
                    NSString *rootFile = [dic stringForKey:@"fileName"];
                    [fileManager removeItemAtPath:rootFile error:nil];
                }
            }
        }
    }
}

+ (NSArray *)loadFiles {
    NSMutableArray *mArr = [NSMutableArray array];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray *dirArray = [fileManager contentsOfDirectoryAtPath:[self getNoteFilePath] error:nil];
    for (NSInteger i=dirArray.count-1; i>=0; i--) {
        NSString *dirName = [dirArray objectAtIndex:i];
        NSString *fileName = [NSString stringWithFormat:@"%@/%@",[self getNoteFilePath],dirName];
        NSDictionary *dic = [fileManager attributesOfItemAtPath:fileName error:nil];
        if(dic){
            NSInteger index = 0;
            for(NSInteger i=0; i<mArr.count; i++){
                NSDictionary *temp = [mArr objectAtIndex:i];
                NSDictionary *old = [temp dictionaryForKey:@"attribute"];
                
                if([dic.fileModificationDate timeIntervalSince1970] >= [old.fileModificationDate timeIntervalSince1970]){
                    index = i;
                    break;
                }
            }
            
            [mArr insertObject:@{@"attribute" : dic,
                                 @"fileName" : fileName,
                                 @"time" : dic.fileModificationDate,
                                 @"name" : dirName} atIndex:index];
        }
    }
    
    return mArr;
}

+ (NSInteger)daysAfterDate: (NSDate *) aDate {
    NSTimeInterval ti = [[NSDate date] timeIntervalSinceDate:aDate];
    return (NSInteger) (ti / 86400);
}

+ (NSString *)date2String:(NSDate *)date formatType:(AFFTimeFormatType)type {
    if(date==nil)
        return nil;
    
    NSDateFormatter *dateFormatter = [self formatter];
    [dateFormatter setDateFormat:[self formatString:type]];
    
    NSString *curTime = [dateFormatter stringFromDate:date];
    
    return curTime;
}


+ (NSString*)formatString:(AFFTimeFormatType)type {
    if(type == ETimeFormatTimeDate){
        return @"yyyy-MM-dd";
    }else if(type == ETimeFormatTimeDate_CN){
        return @"yyyy年MM月dd日";
    }
    else if(type == ETimeFormatTimeDateEx)
    {
        return @"yyyy.MM.dd";
    }
    else if(type == ETimeFormatTimeCommon){
        return @"yyyy-MM-dd HH:mm:ss";
    }
    else if(type == ETimeFormatTimeShort){
        return @"yyyy-MM-dd HH:mm";
    }else if(type == ETimeFormatTimeTime){
        return @"HH:mm";
    }else if(type == ETimeFormatTimeYear){
        return @"yyyy";
    }else if(type == ETimeFormatTimeMonth){
        return @"MM";
    }else if(type == ETimeFormatTimeDay){
        return @"dd";
    }else if(type == ETimeFormatTimeHour){
        return @"HH";
    }else if(type == ETimeFormatTimeMinute){
        return @"mm";
    }else if(type == ETimeFormatTimeSecond){
        return @"ss";
    }else if(type == ETimeFormatTimeLong){
        return @"yyyy-MM-dd HH:mm:ss.SSS";
    }else if(type == ETimeFormatTimeMask){
        return @"yyyyMMddHHmmssSSS";
    }else if(type == ETimeFormatTimeShortDate){
        return @"MM-dd";
    }else if(type == ETimeFormatTimeShortDateTime){
        return @"MM-dd HH:mm";
    }else if(type == ETimeFormatTimeShortDateTime_CN){
        return @"M月d日 HH:mm";
    }else if(type == ETimeFormatTimeShortDate_CN){
        return @"M月d日";
    }else if(type == ETimeFormatTimeDateDotSpan){
        return @"yyyy.MM.dd";
    }else if(type == ETimeFormatTimeMonth_CN){
        return @"yyyy年MM月";
    }
    
    return @"yyyy-MM-dd HH:mm";
}


+ (NSString*)deviceVersion {
    // 需要#import "sys/utsname.h"
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *deviceString = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    
    if ([deviceString isEqualToString:@"iPhone1,1"])    return @"iPhone 1G";
    if ([deviceString isEqualToString:@"iPhone1,2"])    return @"iPhone 3G";
    if ([deviceString isEqualToString:@"iPhone2,1"])    return @"iPhone 3GS";
    
    if ([deviceString hasPrefix:@"iPhone3"])    return @"iPhone 4";
    if ([deviceString isEqualToString:@"iPhone4,1"])    return @"iPhone 4S";
    
    if ([deviceString isEqualToString:@"iPhone5,1"])    return @"iPhone 5";
    if ([deviceString isEqualToString:@"iPhone5,2"])    return @"iPhone 5";
    if ([deviceString isEqualToString:@"iPhone5,3"])    return @"iPhone 5C";
    if ([deviceString isEqualToString:@"iPhone5,4"])    return @"iPhone 5C";
    if ([deviceString hasPrefix:@"iPhone6"])    return @"iPhone 5S";
    
    if ([deviceString isEqualToString:@"iPhone7,2"])    return @"iPhone 6";
    if ([deviceString isEqualToString:@"iPhone7,1"])    return @"iPhone 6 Plus";
    
    if ([deviceString isEqualToString:@"iPhone8,1"])    return @"iPhone 6s";
    if ([deviceString isEqualToString:@"iPhone8,2"])    return @"iPhone 6s Plus";
    if ([deviceString isEqualToString:@"iPhone8,4"])    return @"iPhone SE";
    
    if ([deviceString isEqualToString:@"iPhone9,1"])    return @"iPhone 7";
    if ([deviceString isEqualToString:@"iPhone9,2"])    return @"iPhone 7 Plus";
    
    if ([deviceString isEqualToString:@"iPhone10,1"])    return @"iPhone 8";
    if ([deviceString isEqualToString:@"iPhone10,2"])    return @"iPhone 8 Plus";
    
    if ([deviceString isEqualToString:@"iPod1,1"])      return @"iPod Touch 1G";
    if ([deviceString isEqualToString:@"iPod2,1"])      return @"iPod Touch 2G";
    if ([deviceString isEqualToString:@"iPod3,1"])      return @"iPod Touch 3G";
    if ([deviceString isEqualToString:@"iPod4,1"])      return @"iPod Touch 4G";
    if ([deviceString isEqualToString:@"iPod5,1"])      return @"iPod Touch 5G";
    if ([deviceString isEqualToString:@"iPod7,1"])      return @"iPod Touch 6G";
    
    if ([deviceString isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([deviceString isEqualToString:@"iPad2,1"])      return @"iPad 2 (WiFi)";
    if ([deviceString isEqualToString:@"iPad2,2"])      return @"iPad 2 (GSM)";
    if ([deviceString isEqualToString:@"iPad2,3"])      return @"iPad 2 (CDMA)";
    if ([deviceString isEqualToString:@"iPad3,4"])      return @"iPad 4 (WiFi)";
    
    if ([deviceString isEqualToString:@"iPad4,3"])      return @"iPad Air";
    if ([deviceString isEqualToString:@"iPad5,1"])      return @"iPad Mini4";
    if ([deviceString isEqualToString:@"iPad5,3"])      return @"iPad Air2";
    if ([deviceString hasPrefix:@"iPad6"])      return @"iPad Pro";
    
    if ([deviceString isEqualToString:@"i386"])         return @"Simulator";
    if ([deviceString isEqualToString:@"x86_64"])       return @"Simulator";
    
    //CLog(@"NOTE: Unknown device type: %@", deviceString);
    
    return deviceString;
}

@end
