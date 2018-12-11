//
//  PYIMAudioConverter.h
//  PYIMAV
//
//  Created by Bob Lee on 2018/5/8.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <Foundation/Foundation.h>

#define AUDIO_RECORD (2640)     // 注意安装对应的是short数组，ios采集出来应该对应
#define AUDIO_BUFFER (2640)
#define AUDIO_FRAMES (480)      // frame大小，对应字节为 mBytesPerFrame * AUDIO_FRAMES = 960字节

#define AUDIO_ENCODE (480)      // 44100/8000 = 5.5125，2640/5.5125=478.9
#define AUDIO_DECODE (480)     // 接收解码大小，解码后得到2048

@interface PYIMAudioConverter : NSObject

- (NSData*)encodeAudio:(NSMutableData*)dataRecord;
- (NSData*)encodeAudioADPCM:(NSMutableData*)dataRecord;
- (NSData*)encodeAudio:(NSMutableData*)dataRecord compres:(BOOL)compres;
- (int)encodeAudio:(NSMutableData*)dataRecord outBuffer:(char*)outBuffer;

- (NSData*)decodeAudio:(NSData*)dataPlay;
- (int)decodeAudio:(NSData*)dataPlay outBuffer:(char*)outBuffer;
- (int)decodeAudioEx:(char*)inBuffer outBuffer:(char*)outBuffer;

- (void)dispose;

@end
