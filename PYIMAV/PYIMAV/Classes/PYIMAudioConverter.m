//
//  PYIMAudioConverter.m
//  PYIMAV
//
//  Created by Bob Lee on 2018/5/8.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYIMAudioConverter.h"
#import <AudioToolbox/AudioToolbox.h>

#import "adpcm.h"

typedef struct _tagConvertContext {
    AudioConverterRef converter;
    int samplerate;
    int channels;
} ConvertContext;

static AudioConverterRef PCM44kTo8kConverterRef;    // 发送

@interface PYIMAudioConverter() {
    adpcm_state encode_state;
    adpcm_state decode_state;
    AudioStreamBasicDescription asbdSource;
    AudioStreamBasicDescription asbdTarget;
}

@end

@implementation PYIMAudioConverter

- (instancetype)init {
    self = [super init];
    if(self){
        [self initConverter];
    }
    
    return self;
}

- (void)dispose {
    if(PCM44kTo8kConverterRef)
        AudioConverterDispose(PCM44kTo8kConverterRef);
}

- (void)dealloc {
    NSLog(@"dealloc %@", self);
}

- (NSData*)encodeAudio:(NSMutableData*)dataRecord {
    return [self encodeAudio:dataRecord compres:YES];
}

- (NSData*)encodeAudio:(NSMutableData*)dataRecord compres:(BOOL)compres {
    // 如果采用44100采样，需要进行下面代码转换
    // 输入的buffer
    AudioBufferList inAudioBufferList = {0};
    inAudioBufferList.mNumberBuffers = 1;
    inAudioBufferList.mBuffers[0].mNumberChannels = 1;
    inAudioBufferList.mBuffers[0].mDataByteSize = AUDIO_BUFFER*sizeof(short); // 截取AUDIO_BUFFER个frame
    inAudioBufferList.mBuffers[0].mData = dataRecord.mutableBytes;
    
    // 输出的buffer,AUDIO_ENCODE只是临时大小，最终要根据转换后有效长度为准
    uint32_t bufferSize = (UInt32)(AUDIO_FRAMES * sizeof(short)); // 480*2刚合适
    uint8_t *buffer = (uint8_t *)malloc(bufferSize);
    memset(buffer, 0, bufferSize);
    AudioBufferList outAudioBufferList;
    outAudioBufferList.mNumberBuffers = 1;
    outAudioBufferList.mBuffers[0].mNumberChannels = 1;
    outAudioBufferList.mBuffers[0].mDataByteSize = bufferSize;
    outAudioBufferList.mBuffers[0].mData = buffer;
    
    UInt32 numOfFrames = AUDIO_FRAMES; // 2640字节转到到8000采样后大小为480字节，目前是short类型，所以转换后得到480个frame，960字节
    OSStatus status = AudioConverterFillComplexBuffer(PCM44kTo8kConverterRef, inInputDataProc, &inAudioBufferList, &numOfFrames, &outAudioBufferList, NULL);
    
    NSData *data = nil;
    if(status==0 && outAudioBufferList.mBuffers[0].mDataByteSize>0){
        AudioBuffer abuffer = outAudioBufferList.mBuffers[0];
        if(compres){
            char encodeBuffer[AUDIO_BUFFER];
            int encode_len = 0;
            
            // 从short压缩后得到char数组：4；1压缩
            adpcm_coder(abuffer.mData, (char*)encodeBuffer, AUDIO_FRAMES, &encode_state);
            encode_len = AUDIO_FRAMES/2;
            data = [NSData dataWithBytes:encodeBuffer length:encode_len];
        }else
            data = [NSData dataWithBytes:abuffer.mData length:abuffer.mDataByteSize];
    }
    
    free(buffer);
    return data;
}

// 一次截取AUDIO_FRAMES*bytesPerFrame个字节处理
- (NSData*)encodeAudioADPCM:(NSMutableData*)dataRecord {
    char encodeBuffer[AUDIO_BUFFER];
    int encode_len = 0;
    
    adpcm_coder((short*)[dataRecord subdataWithRange:NSMakeRange(0, AUDIO_FRAMES*sizeof(short))].bytes, encodeBuffer, AUDIO_FRAMES, &encode_state);
    encode_len = AUDIO_FRAMES/2;
    NSData *data = [NSData dataWithBytes:encodeBuffer length:encode_len];
    return data;
}

- (int)encodeAudio:(NSMutableData*)dataRecord outBuffer:(char*)outBuffer {
    // 输入的buffer
    AudioBufferList inAudioBufferList = {0};
    inAudioBufferList.mNumberBuffers = 1;
    inAudioBufferList.mBuffers[0].mNumberChannels = 1;
    inAudioBufferList.mBuffers[0].mDataByteSize = AUDIO_BUFFER;
    inAudioBufferList.mBuffers[0].mData = dataRecord.mutableBytes;
    
    // 输出的buffer,AUDIO_ENCODE只是临时大小，最终要根据转换后有效长度为准
    uint32_t bufferSize = (UInt32)(AUDIO_ENCODE * sizeof(short int));
    uint8_t *buffer = (uint8_t *)malloc(bufferSize);
    memset(buffer, 0, bufferSize);
    AudioBufferList outAudioBufferList;
    outAudioBufferList.mNumberBuffers = 1;
    outAudioBufferList.mBuffers[0].mNumberChannels = 1;
    outAudioBufferList.mBuffers[0].mDataByteSize = bufferSize;
    outAudioBufferList.mBuffers[0].mData = buffer;
    
    UInt32 numFrames = AUDIO_ENCODE/2; // 需要压缩后的大小 480 转换后的buffer大小为480*2
    
    OSStatus status = AudioConverterFillComplexBuffer(PCM44kTo8kConverterRef, inInputDataProc, &inAudioBufferList, &numFrames, &outAudioBufferList, NULL);
    
    int encode_len = 0;
    
    if(status==0 && outAudioBufferList.mBuffers[0].mDataByteSize>0){
        AudioBuffer abuffer = outAudioBufferList.mBuffers[0];
        adpcm_coder(abuffer.mData, (char*)outBuffer, AUDIO_FRAMES, &encode_state); // 2:1
        encode_len = AUDIO_FRAMES/2;
    }
    
    free(buffer);
    return encode_len;
}

// 直接播放收到的8000采样数据
- (NSData*)decodeAudio:(NSData*)dataPlay {
    char *recorderBuffer = (char*)dataPlay.bytes;
    short encodeBuffer[AUDIO_BUFFER];
    int encode_len = 0; // 字节数

    adpcm_decoder(recorderBuffer, (short*)encodeBuffer, AUDIO_FRAMES, &decode_state);
    encode_len = AUDIO_FRAMES*sizeof(short);
    return [NSData dataWithBytes:encodeBuffer length:encode_len];;
}

- (int)decodeAudio:(NSData*)dataPlay outBuffer:(char*)outBuffer {
    short *recorderBuffer = (short*)dataPlay.bytes;
    int encode_len = 0;
    
    adpcm_decoder((char*)recorderBuffer, (short*)outBuffer, AUDIO_FRAMES, &decode_state);
    encode_len = AUDIO_FRAMES*sizeof(short);
    return encode_len;
}

- (int)decodeAudioEx:(char*)inBuffer outBuffer:(char*)outBuffer {
    int encode_len = 0;
    adpcm_decoder(inBuffer, (short*)outBuffer, AUDIO_FRAMES, &decode_state);
    encode_len = AUDIO_FRAMES*sizeof(short);
    return encode_len;
}

// 创建转换器
// 将样本频率从44100转换到8000；
- (void)initConverter {
    /**
     AudioStreamBasicDescription:
     mSampleRate;       采样率, eg. 44100
     mFormatID;         格式, eg. kAudioFormatLinearPCM
     mFormatFlags;      标签格式, eg. kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
     mBytesPerPacket;   每个Packet的Bytes数量, eg. 2
     mFramesPerPacket;  每个Packet的帧数量, eg. 1
     mBytesPerFrame;    (mBitsPerChannel / 8 * mChannelsPerFrame) 每帧的Byte数, eg. 2
     mChannelsPerFrame; 1:单声道；2:立体声, eg. 1
     mBitsPerChannel;   语音每采样点占用位数[8/16/24/32], eg. 16
     mReserved;         保留
     */
    
    /*AudioStreamBasicDescription streamFormat8k = {0};
    streamFormat8k.mFormatID = kAudioFormatAppleIMA4; // 对应Android的adpcm编码格式：4：1压缩
    streamFormat8k.mFormatFlags = 0;
    streamFormat8k.mSampleRate = 8000;
    streamFormat8k.mFramesPerPacket = 64;
    streamFormat8k.mBytesPerFrame = 0;
    streamFormat8k.mBytesPerPacket = 0;
    streamFormat8k.mBitsPerChannel = 0;
    streamFormat8k.mChannelsPerFrame = 1;*/
    
    asbdTarget.mFormatID = kAudioFormatLinearPCM; // 对应Android的adpcm编码格式：4：1压缩
    asbdTarget.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    asbdTarget.mSampleRate = 8000;
    asbdTarget.mFramesPerPacket = 1;
    asbdTarget.mBytesPerFrame = 2;
    asbdTarget.mBytesPerPacket = 2;
    asbdTarget.mBitsPerChannel = 16;
    asbdTarget.mChannelsPerFrame = 1;
    
    asbdSource.mFormatID = kAudioFormatLinearPCM;
    asbdSource.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    asbdSource.mSampleRate = 44100;
    asbdSource.mFramesPerPacket = 1;
    asbdSource.mBytesPerFrame = 2;
    asbdSource.mBytesPerPacket = 2;
    asbdSource.mBitsPerChannel = 16;
    asbdSource.mChannelsPerFrame = 1;
    
    OSStatus status = AudioConverterNew(&asbdSource, &asbdTarget, &PCM44kTo8kConverterRef);
    if(status!=noErr)
        NSLog(@"audio converter encord 44pcm to 8ima4：%@", status==0?@"success":@"fail");
}

// 转换方法，将数据填充到缓冲区
OSStatus inInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    AudioBufferList audioBufferList = *(AudioBufferList *)inUserData;
    
    ioData->mBuffers[0].mData = audioBufferList.mBuffers[0].mData;
    ioData->mBuffers[0].mDataByteSize = audioBufferList.mBuffers[0].mDataByteSize;
    
    *ioNumberDataPackets = audioBufferList.mBuffers[0].mDataByteSize/2; // 转换后的mBytesPerPacket = 2
    
    return  noErr;
}

@end
