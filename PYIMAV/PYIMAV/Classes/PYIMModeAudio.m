//
//  PYIMModeAudio.m
//  PYIMAV
//
//  Created by 002 on 2018/5/15.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYIMModeAudio.h"
#import "c2c.h"
#import "pdu.h"

#import "PYIMAudioConverter.h"
#import "PYIMVideoConverter.h"

#import "PYIMAccount.h"

@implementation PYIMModeAudio

- (instancetype)initWithData:(NSData*)data converter:(id)converter{
    self = [super init];
    if(self){
        Header header;
        CmdAudioFrame rsp;
        uint16_t recvLen = data.length;
        Byte *recvBuf = (Byte*)data.bytes;
        
        uint16_t swapLen = P2P_MAX_BUF_SIZE;
        uint8_t swapBuf[P2P_MAX_BUF_SIZE];        // 交换缓冲区
        int ret = decodeAudioFrame(recvBuf, recvLen, &header, &rsp, swapBuf, &swapLen);
        if(ret == 0){
            
            self.media = [(PYIMAudioConverter*)converter decodeAudio:[NSData dataWithBytes:swapBuf length:swapLen]];
            
//            char decBuffer[AUDIO_BUFFER];
//            int lenDec = [(PYIMAudioConverter*)converter decodeAudioEx:(char*)swapBuf outBuffer:decBuffer];
//            self.media = [NSData dataWithBytes:decBuffer length:lenDec];
            
//            self.timeRecordStart = rsp.timeStart;
//            self.timeRecordEnd = rsp.timeEnd;
        }
    }
    
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    PYIMModeAudio *mode = [[[self class] alloc] init];
    mode.media = _media;
    mode.is8kTo8k = _is8kTo8k;
    mode.timeRecordStart = _timeRecordStart;
    mode.timeRecordEnd = _timeRecordEnd;
    
    return mode;
}

@end

@interface PYIMModeVideo()

@property (nonatomic, weak) PYIMVideoConverter *converter;
@property (nonatomic, strong) NSMutableArray<PYIMModeVideo*> *mArrPacket; ///< 分包缓存

@end

@implementation PYIMModeVideo

- (instancetype)initWithData:(NSData*)data converter:(id)converter {
    self = [super init];
    if(self){
        Header header;
        CmdVideoFrame rsp;
        uint16_t recvLen = data.length;
        Byte *recvBuf = (Byte*)data.bytes;
        self.converter = (PYIMVideoConverter*)converter;
        
        uint16_t swapLen = P2P_MAX_BUF_SIZE;
        uint8_t swapBuf[P2P_MAX_BUF_SIZE];        // 交换缓冲区
        int ret = decodeVideoFrame(recvBuf, recvLen, &header, &rsp, swapBuf, &swapLen);
        if(ret == 0){
            self.media = [NSData dataWithBytes:swapBuf length:swapLen];
            self.frameLen = rsp.frameLen;
            self.packs = rsp.packs;
            self.pid = rsp.pid;
            self.packLen = rsp.packLen;
            self.frameID = rsp.frameID;
            
            self.width = rsp.width;
            self.height = rsp.height;
            self.fps = rsp.fps;
            self.bitrate = rsp.bitrate;
            self.angle = rsp.angle;
            self.mirror = rsp.mirror;
            
//            self.timeRecordStart = rsp.timeStart;
//            self.timeRecordEnd = rsp.timeEnd;
        }
        
        if(_pid==0){
            kAccount.frameID = self.frameID; // 后面是同一个frame才收集
            [self appendPacket:self];
        }
    }
    
    return self;
}

- (instancetype)initWithDataEx:(NSData*)data converter:(id)converter {
    self = [super init];
    if(self){
        Header header;
        CmdVideoFrameEx rsp;
        uint16_t recvLen = data.length;
        Byte *recvBuf = (Byte*)data.bytes;
        
        uint16_t swapLen = P2P_MAX_BUF_SIZE;
        uint8_t swapBuf[P2P_MAX_BUF_SIZE];        // 交换缓冲区
        int ret = decodeVideoFrameEx(recvBuf, recvLen, &header, &rsp, swapBuf, &swapLen);
        if(ret == 0){
            // TODO: 这里解压缩数据
            if(swapLen>0){
                self.media = [(PYIMVideoConverter*)converter decode:(char*)swapBuf length:swapLen];
            }
            
            NSLog(@"receive data size:%d decodeSize:%ti seqID:%d", swapLen, self.media.length, header.SeqId);
            
            self.width = rsp.width;
            self.height = rsp.height;
            self.fps = rsp.fps;
            self.bitrate = rsp.bitrate;
            self.angle = rsp.angle;
            self.mirror = rsp.mirror;
            
//            self.timeRecordStart = rsp.timeStart;
//            self.timeRecordEnd = rsp.timeEnd;
        }
    }
    
    return self;
}

- (NSMutableArray<PYIMModeVideo*>*)mArrPacket {
    if(_mArrPacket==nil){
        _mArrPacket = [NSMutableArray array];
    }
    
    return _mArrPacket;
}

- (void)appendPacket:(PYIMModeVideo*)packet {
    [self.mArrPacket addObject:packet];
    
    if(self.isFinish){
        // 排个序
        NSSortDescriptor *order = [[NSSortDescriptor alloc] initWithKey:@"" ascending:YES];
        NSArray *arr = [self.mArrPacket sortedArrayUsingDescriptors:@[order]];
        NSMutableData *mData = [NSMutableData data];
        for(PYIMModeVideo *video in arr){
            [mData appendData:video.media];
        }
        
        if(mData.length>0){
            self.media = [self.converter decode:(char*)mData.bytes length:(int)mData.length];
        }
        
        kAccount.frameID = 0;
    }
}

- (BOOL)isFinish {
    return self.packs==self.mArrPacket.count;
}

- (id)copyWithZone:(NSZone *)zone {
    PYIMModeVideo *mode = [super copyWithZone:zone];
    mode.frameID = _frameID;
    mode.width = _width;
    mode.height = _height;
    mode.fps = _fps;
    mode.angle = _angle;
    mode.mirror = _mirror;
    mode.bitrate = _bitrate;
    mode.frameLen = _frameLen;
    mode.packs = _packs;
    mode.pid = _pid;
    mode.packLen = _packLen;
    
    return mode;
}

@end
