//
//  PYIMAudioController.m
//  PYIMAV
//
//  Created by 002 on 2018/4/25.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PYIMAudioController.h"

#import "PYIMAccount.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "PYIMAudioConverter.h"


#import "c2c.h"
#import "c2s.h"

// Audio Unit Set Property
#define INPUT_BUS  1      ///< A I/O unit's bus 1 connects to input hardware (microphone).
#define OUTPUT_BUS 0      ///< A I/O unit's bus 0 connects to output hardware (speaker).


static BOOL kEndAudio = YES;
static NSInteger kAudioPlayerRequireEmptyTimes = 0; /// 如果有语音重置为0，否则递增，当达到50*5（每秒50个包）时视作对方下线

typedef struct MyAUGraphStruct{
    AUGraph graph;
    AudioUnit remoteIOUnit;
} MyAUGraphStruct;


@interface PYIMAudioController() {
    @public
    MyAUGraphStruct myStruct;
    AudioStreamBasicDescription streamFormatInput, streamFormatOutput;
    AURenderCallbackStruct recordRender, playRender;
    NSMutableData *mDataSend;
    NSMutableData *mDataRec;
    NSInteger sendCount;
}

@property (nonatomic, copy) void(^recordEnd)(NSData *media); ///< 录制语音包回调
@property (nonatomic, copy) void(^playEnd)(PYIMMediaState state); ///< 如果5秒未接收到语音数据,检查网络情况，视作对方下线，取消请求退出
@property (nonatomic, strong) PYIMAudioConverter *converter; ///< 本地录制需要初始化，网络任务会在网络层处理
@property (nonatomic, assign) PYIMMediaState mState; ///< 播放状态
@property (nonatomic, assign) BOOL speakerEnable; ///< 是否在扬声器播放，默认YES

@property (nonatomic, assign) BOOL hadClean; ///< 是否已清理

@end

/**
 double duration = (audioDataByteCount * 8) / bitRate // 计算时长
 
 UInt32 bitRate;
 UInt32 bitRateSize = sizeof(bitRate);
 OSStatus status = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_BitRate, &bitRateSize, &bitRate);
 if (status != noErr)
 {
 //错误处理
 }
 */

@implementation PYIMAudioController

- (instancetype)init {
    self = [super init];
    if(self){
        // do something
        [self setupSession]; // 请求权限
        
        _mState = EMediaState_Stoped;
        
        mDataSend = [[NSMutableData alloc] init];
        mDataRec = [[NSMutableData alloc] init];
        
        
        // 防止锁屏
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
        
        // 添加监听 - 耳机插拔
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)setIsLocal:(BOOL)isLocal {
    _isLocal = isLocal;
    
    if(isLocal && self.converter==nil){
        self.converter = [[PYIMAudioConverter alloc] init];
    }
}

- (BOOL)isPlaying {
    return !kEndAudio;
}

- (void)setMState:(PYIMMediaState)mState {
    _mState = mState;
    
    if(self.playEnd){
        self.playEnd(_mState);
    }
}

- (void)startAudio:(void(^)(PYIMMediaState state))block {
    _playEnd = block;
    kEndAudio = NO;
    self.mState = EMediaState_Playing;
    
    [self createAUGraph:&myStruct];
    [self setupRemoteIOUnit:&myStruct];
    [self startGraph:myStruct.graph];
    
    if(!(kAccount.chatType & P2P_CHAT_TYPE_VIDEO)){
        [self monitorProximity];
    }
}

/// 可能忘了问题导致收不到对方数据这时候间隔时间要暂停，等到接收到后才回复
- (void)pause {
    CheckError(AudioOutputUnitStop(myStruct.remoteIOUnit), "AudioOutputUnitStop faild"); // 停止播放
    CheckError(AUGraphStop(myStruct.graph), "AUGraphStop faild"); // 停止录制
    NSLog(@"暂停audio");
    self.mState = EMediaState_Paused;
}

- (void)resume {
    kAudioPlayerRequireEmptyTimes = 0;
    CheckError(AudioOutputUnitStart(myStruct.remoteIOUnit), "AudioOutputUnitStop faild"); // 停止播放
    CheckError(AUGraphStart(myStruct.graph), "AUGraphStop faild"); // 停止录制
    NSLog(@"恢复audio");
    self.mState = EMediaState_Playing;
}

- (void)stopAudio {
    if(_hadClean)return;
    _hadClean = YES;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    
    kAudioPlayerRequireEmptyTimes = 0;
    kEndAudio = YES;
    
    if(self.playEnd)
        [self stopGraph:myStruct.graph];
    
    self.recordEnd = nil;
    self.playEnd = nil;
    
    [self.converter dispose];
    self.converter = nil;
    
    NSLog(@"语音播放结束");
}

- (void)monitorProximity {
    // 开启红外感应，贴近耳朵切换听筒模式检查
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
    
    // 添加监听 - 感应器信息变化
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleProximityStateChange:)
                                                 name:@"UIDeviceProximityStateDidChangeNotification"
                                               object:nil];
}

- (void)dealloc {
    NSLog(@"dealloc %@", self);
    [self stopAudio];
}

#pragma mark - 硬件监听控制

/// 感应是否切近身体
- (void)handleProximityStateChange:(NSNotification*)sender {
    [self sessionCategoryChanged:![[UIDevice currentDevice] proximityState]];
}

/// 感应外接设备连接变化
- (void)handleAudioRouteChange:(NSNotification*)sender {
    NSDictionary *interuptionDict = sender.userInfo;
    
    NSInteger routeChangeReason = [[interuptionDict valueForKey:AVAudioSessionRouteChangeReasonKey] integerValue];
    switch (routeChangeReason) {
        case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
            NSLog(@"连接上耳机、蓝牙等其他外接设备");
            break;
        case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
            NSLog(@"断开了刚才连接的设备，耳机拔出，切换到speaker");
            [self sessionCategoryChanged:YES];
            break;
        case AVAudioSessionRouteChangeReasonCategoryChange:
            // called at start - also when other audio wants to play
            NSLog(@"AVAudioSessionRouteChangeReasonCategoryChange");
            break;
    }
}

#pragma mark - 语音录制控制

- (void)recordAudio:(void (^)(NSData *))block {
    self.recordEnd = block;
}

/// 配置音频录制会话
- (void)setupSession{
    AVAudioSession* session = [AVAudioSession sharedInstance];
//    [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
    [session setActive:YES error:nil];
    
    _speakerEnable = YES;
}

/// 切换输出模式
- (void)sessionCategoryChanged:(BOOL)speaker {
    if(_speakerEnable==speaker || _hadClean)return;
    
    _speakerEnable = speaker;
    
    if(speaker) {
        // 扬声器播放
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
    } else {
        // 听筒播放
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    }
}

/// 开始语音模块
- (void)startGraph:(AUGraph)graph {
    CheckError(AUGraphInitialize(graph),
               "AUGraphInitialize failed");
    CheckError(AUGraphStart(graph),
               "AUGraphStart failed");
    
    NSLog(@"AUGraph started");
}

/// 停止（功能结束）清理资源
- (void)stopGraph:(AUGraph)graph {
    CheckError(AudioOutputUnitStop(myStruct.remoteIOUnit), "AudioOutputUnitStop faild");
    CheckError(AUGraphStop(graph), "AUGraphStop faild");
    CheckError(AUGraphRemoveRenderNotify(graph, recordRender.inputProc, recordRender.inputProcRefCon), "AUGraphRemoveRenderNotify input faild");
    CheckError(AUGraphRemoveRenderNotify(graph, playRender.inputProc, playRender.inputProcRefCon), "AUGraphRemoveRenderNotify output faild");
    CheckError(AUGraphUninitialize(graph), "AUGraphUninitialize faild");
    CheckError(AUGraphClose(graph), "AUGraphClose faild");
    
    NSLog(@"AUGraph disposed");
}

- (void)createAUGraph:(MyAUGraphStruct*)augStruct{
    //Create graph
    CheckError(NewAUGraph(&augStruct->graph),
               "NewAUGraph failed");
    
    //Create nodes and add to the graph
    AudioComponentDescription inputcd = {0};
    inputcd.componentType = kAudioUnitType_Output;
    inputcd.componentSubType = kAudioUnitSubType_VoiceProcessingIO; // 回声去除
    inputcd.componentManufacturer = kAudioUnitManufacturer_Apple;
    inputcd.componentFlags        = 0;
    inputcd.componentFlagsMask    = 0;
    
    AUNode remoteIONode;
    //Add node to the graph
    CheckError(AUGraphAddNode(augStruct->graph,
                              &inputcd,
                              &remoteIONode),
               "AUGraphAddNode failed");
    
    //Open the graph
    CheckError(AUGraphOpen(augStruct->graph),
               "AUGraphOpen failed");
    
    //Get reference to the node
    CheckError(AUGraphNodeInfo(augStruct->graph,
                               remoteIONode,
                               &inputcd,
                               &augStruct->remoteIOUnit),
               "AUGraphNodeInfo failed");
}

- (void)setupRemoteIOUnit:(MyAUGraphStruct*)augStruct{
    //Open input of the bus 1(input mic)
    UInt32 inputEnableFlag = 1;
    CheckError(AudioUnitSetProperty(augStruct->remoteIOUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input,
                                    INPUT_BUS,
                                    &inputEnableFlag,
                                    sizeof(inputEnableFlag)),
               "Open input of bus 1 failed");
    
    //Open output of bus 0(output speaker)
    UInt32 outputEnableFlag = 1;
    CheckError(AudioUnitSetProperty(augStruct->remoteIOUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Output,
                                    OUTPUT_BUS,
                                    &outputEnableFlag,
                                    sizeof(outputEnableFlag)),
               "Open output of bus 0 failed");
    
    // Android上参数，从配置上看，发送和接收只是在采样率上有变化，所以ios上也只做同样处理
    /*
     #define SL_SPEAKER_FRONT_LEFT                  ((SLuint32) 0x00000001)
     #define SL_SPEAKER_FRONT_RIGHT                 ((SLuint32) 0x00000002)
     #define SL_SPEAKER_FRONT_CENTER                ((SLuint32) 0x00000004)
     
    SLDataFormat_PCM format_pcm_recorder = {
        SL_DATAFORMAT_PCM,                  // formatType 采样数据格式 pcm
        1,                                  // numChannels 声道数量 1
        SL_SAMPLINGRATE_44_1,               // sampleRate 采样率 ((SLuint32) 44100000)
        SL_PCMSAMPLEFORMAT_FIXED_16,        // bitsPerSample=mBitsPerChannel ((SLuint16) 0x0010) = 16
        SL_PCMSAMPLEFORMAT_FIXED_16,        // containerSize ((SLuint16) 0x0010) = 16 = 2byte
        SL_SPEAKER_FRONT_CENTER,            // channelMask 声道 ((SLuint32) 0x00000004) = 4
        SL_BYTEORDER_LITTLEENDIAN           // endianness ((SLuint32) 0x00000002) = 2
        
    };
     
     SLDataFormat_PCM format_pcm_player = {
     SL_DATAFORMAT_PCM,
     1,
     SL_SAMPLINGRATE_8,              // 8000
     SL_PCMSAMPLEFORMAT_FIXED_16,
     SL_PCMSAMPLEFORMAT_FIXED_16,
     SL_SPEAKER_FRONT_CENTER,
     SL_BYTEORDER_LITTLEENDIAN};
     
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
    
    // 设置录制、播放的数据格式信息
    // 一秒时间数据大小：mSampleRate*mBitsPerChannel/8*mChannelsPerFrame
    streamFormatOutput.mFormatID = kAudioFormatLinearPCM; // iOS硬件直接播放支持的格式，发送需要转成adpcm
    streamFormatOutput.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    if(self.is8kTo8k)
        streamFormatOutput.mSampleRate = 8000;   // 采样率
    else
        streamFormatOutput.mSampleRate = 44100;   // 采样率
    streamFormatOutput.mBitsPerChannel = 16;  // 位数
    streamFormatOutput.mChannelsPerFrame = 1; // 声道数
    
    streamFormatOutput.mFramesPerPacket = 1;  // 每个数据包中的样本帧数目
    streamFormatOutput.mBytesPerFrame = streamFormatOutput.mBitsPerChannel / 8 * streamFormatOutput.mChannelsPerFrame; // 2
    streamFormatOutput.mBytesPerPacket = 2;
    
    streamFormatInput.mFormatID = kAudioFormatLinearPCM; // iOS硬件直接播放支持的格式，发送需要转成adpcm
    streamFormatInput.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    streamFormatInput.mSampleRate = 8000;   // 采样率 16000字节/秒
    streamFormatInput.mBitsPerChannel = 16;  // 位数
    streamFormatInput.mChannelsPerFrame = 1; // 声道数
    
    streamFormatInput.mFramesPerPacket = 1;  // 每个数据包中的样本帧数目
    streamFormatInput.mBytesPerFrame = streamFormatInput.mBitsPerChannel / 8 * streamFormatInput.mChannelsPerFrame; ;
    streamFormatInput.mBytesPerPacket = 2;
    
    // 设置播放参数
    CheckError(AudioUnitSetProperty(augStruct->remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Input,
                                    OUTPUT_BUS,
                                    &streamFormatInput,
                                    sizeof(streamFormatInput)),
               "kAudioUnitProperty_StreamFormat of bus 0 failed");
    
    // 设置录制参数
    CheckError(AudioUnitSetProperty(augStruct->remoteIOUnit,
                                    kAudioUnitProperty_StreamFormat,
                                    kAudioUnitScope_Output,
                                    INPUT_BUS,
                                    &streamFormatOutput,
                                    sizeof(streamFormatOutput)),
               "kAudioUnitProperty_StreamFormat of bus 1 failed");
    
    // 录制输出
    recordRender.inputProc = InputCallback;
    recordRender.inputProcRefCon = (__bridge void *)(self);
    CheckError(AudioUnitSetProperty(augStruct->remoteIOUnit,
                                    kAudioOutputUnitProperty_SetInputCallback,
                                    kAudioUnitScope_Output,
                                    INPUT_BUS,
                                    &recordRender,
                                    sizeof(recordRender)),
               "couldnt set remote i/o render callback for output");
    
    // 播放输入
    playRender.inputProc = OutputCallback;
    playRender.inputProcRefCon = (__bridge void *)(self);
    CheckError(AudioUnitSetProperty(augStruct->remoteIOUnit,
                                    kAudioUnitProperty_SetRenderCallback,
                                    kAudioUnitScope_Input,
                                    OUTPUT_BUS,
                                    &playRender,
                                    sizeof(playRender)),
               "kAudioUnitProperty_SetRenderCallback failed");
    
    [self openEchoCancellation];
}

- (void)createRemoteIONodeToGraph:(AUGraph*)graph {
    
}

/// 输入输出都要进行回声处理
- (void)openEchoCancellation {
    UInt32 echoCancellation;
    // 自动增益控制
    CheckError(AudioUnitSetProperty(myStruct.remoteIOUnit,
                                    kAUVoiceIOProperty_BypassVoiceProcessing,
                                    kAudioUnitScope_Global,
                                    INPUT_BUS,
                                    &echoCancellation,
                                    sizeof(echoCancellation)),
               "AudioUnitSetProperty input_bus skAUVoiceIOProperty_BypassVoiceProcessing failed");

    CheckError(AudioUnitSetProperty(myStruct.remoteIOUnit,
                                    kAUVoiceIOProperty_BypassVoiceProcessing,
                                    kAudioUnitScope_Global,
                                    OUTPUT_BUS,
                                    &echoCancellation,
                                    sizeof(echoCancellation)),
               "AudioUnitSetProperty output_bus kAUVoiceIOProperty_BypassVoiceProcessing failed");
}

#pragma mark - 语音播放控制

/// 这里采用NSMutableData缓冲，主要是单位时间播放音频交给系统判断
- (void)playAudio:(PYIMModeAudio *)media {
    if(media.media==nil || media.media.length==0){
        NSLog(@"收到语音数据为空");
        return;
    }

    if(self.isLocal){
        if(media.media.length != AUDIO_FRAMES/(self.isCompress?2:0.5)){
            NSLog(@"收到语音数据长度:%ti", media.media.length);
            return;
        }
    }
    
    if(_mState==EMediaState_Paused){
        [self resume];
    }
    
    // 后期考虑同步问题，同步还要通过kAccount做中间协调；播放按理也是连续的，只可能是网络导致无数据播放，才会考虑同步控制
    NSData *temp = nil;
    if(self.isLocal && self.isCompress){
        temp = [self.converter decodeAudio:media.media];
    }else {
        temp = media.media;
    }
    
    @synchronized(mDataRec) {
        // 拿到一定先解压到缓冲区，这样回调播放想拿多少就拿多少
        [mDataRec appendData:temp];
    }
}

/// 播放队列回调，获取需要播放的数据
- (BOOL)handlePlayEnd:(AudioBufferList *)bufferList frames:(UInt32)inNumberFrames {
    if(_mState==EMediaState_Paused) return NO;
    
    AudioBuffer buffer = bufferList->mBuffers[0];
    
    if(mDataRec.length>0){
        if(mDataRec.length>bufferList->mBuffers[0].mDataByteSize){
            kAudioPlayerRequireEmptyTimes = 0;
            
            @synchronized(mDataRec) {
                @autoreleasepool{
                    int len = buffer.mDataByteSize, lenTotal = (int)mDataRec.length;
                    
                    // 为mBuffers[0].mData分配内存大小
                    memset(buffer.mData, 0, len);
                    memcpy(buffer.mData, mDataRec.bytes, len);
                    buffer.mDataByteSize = len;
                    
                    NSData *temp = [mDataRec subdataWithRange:NSMakeRange(len, lenTotal-len)];
                    [mDataRec setData:temp];
                }
            }
            
            return YES;
        }
    }
    
    [kNote writeNote:@"出现了空白情况，此情况可用于控制本机是否继续录制发送"];
    NSLog(@"出现了空白情况，此情况可用于控制本机是否继续录制发送");
    
    kAudioPlayerRequireEmptyTimes++;
    if(kAudioPlayerRequireEmptyTimes>=10*5){
        [self pause];
    }
    
    return NO;
}

/// 录制的语音，注意是在录制线程中进行的
- (void)handleRecordEnd {
    NSInteger buffersize = (self.is8kTo8k ? AUDIO_FRAMES : AUDIO_BUFFER)*sizeof(short); // 字节数；后续要根据frame进行处理
    NSInteger bufferTotal = mDataSend.length;
    if(mDataSend.length>=buffersize){
        @autoreleasepool{
            if(self.isLocal){
                NSData *temp1 = self.is8kTo8k ? (self.isCompress ? [self.converter encodeAudioADPCM:mDataSend] : [mDataSend subdataWithRange:NSMakeRange(0, buffersize)]) :  [self.converter encodeAudio:mDataSend compres:self.isCompress];
                self.recordEnd(temp1);
            }else {
                self.recordEnd([mDataSend subdataWithRange:NSMakeRange(0, buffersize)]);
            }
            
            [mDataSend setData:[mDataSend subdataWithRange:NSMakeRange(buffersize, bufferTotal-buffersize)]];
        }
    }
}

#pragma mark - 回调检查

static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    char errorString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) &&
        isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else
        // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    exit(1);
}

/// 听筒录入回调
OSStatus InputCallback(void *inRefCon,
                       AudioUnitRenderActionFlags *ioActionFlags,
                       const AudioTimeStamp *inTimeStamp,
                       UInt32 inBusNumber,
                       UInt32 inNumberFrames,
                       AudioBufferList *ioData){
    if(kEndAudio)return noErr;
    
    PYIMAudioController *adc = (__bridge PYIMAudioController*)inRefCon;
    if(kAccount.chatSave==0 && !adc.isLocal)
        return noErr;
    
    if (adc.recordEnd == NULL) {
        return noErr;
    }
     
    MyAUGraphStruct *myStruct = &(adc->myStruct);
    
    // 这里通过bufferList 获取render中的媒体数据，buffer大小由inNumberFrames*inBusNumber决定；后面增加自己弄buffer获取限定长度
    AudioBufferList bufferList;
    bufferList.mNumberBuffers = 1;
    bufferList.mBuffers[0].mData = NULL;
    bufferList.mBuffers[0].mDataByteSize = 0;
    
    AudioUnitRender(myStruct->remoteIOUnit,
                    ioActionFlags,
                    inTimeStamp,
                    inBusNumber,
                    inNumberFrames,
                    &bufferList);
    
    if (adc.recordEnd && adc.mState==EMediaState_Playing)
    {
        AudioBuffer buffer = bufferList.mBuffers[0];
        // 放入缓冲区
        [adc->mDataSend appendBytes:buffer.mData length:buffer.mDataByteSize];
        [adc handleRecordEnd];
    }
    
    return noErr;
}

/// 语音播放回调
OSStatus OutputCallback(void *inRefCon,
                        AudioUnitRenderActionFlags *ioActionFlags,
                        const AudioTimeStamp *inTimeStamp,
                        UInt32 inBusNumber,
                        UInt32 inNumberFrames,
                        AudioBufferList *ioData)

{
    if(kEndAudio)return noErr;
    
    PYIMAudioController *adc = (__bridge PYIMAudioController*)inRefCon;
    BOOL result = [adc handlePlayEnd:ioData frames:inNumberFrames];
    if(!result){
        // 没有数据，播放空白语音
        ioData->mBuffers[0].mDataByteSize = 0;
        *ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
    }
    
    return noErr;
}

@end
