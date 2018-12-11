//
//  PYIMNetworkManager.m
//  PYIMAV
//
//  Created by Bob Lee on 2018/4/26.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYIMNetworkManager.h"
#import "PYIMAccount.h"
#import "GCDAsyncSocket.h"
#import "GCDAsyncUdpSocket.h"

#import "LDNetworkFlowTool.h"

#import "c2s.h"
#import "c2c.h"
#import "adpcm.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <net/ethernet.h>
#import <arpa/inet.h>
#import <ifaddrs.h>

static PYIMNetworkManager *manager;
static PYIMModeMedia *kVideo_Partion; // 视频分片用，可能分片从tcp或者udp获取，所以定义成全局静态

@interface PYIMOperation : NSBlockOperation {
}

@property (nonatomic, strong) PYIMModeNetwork *mode;   ///< 任务对象
@property (nonatomic, strong) NSTimer *timer;   ///< 手动超时控制
@property (nonatomic, weak) GCDAsyncSocket *socket;   ///< 执行者
@property (nonatomic, weak) GCDAsyncUdpSocket *socketUdp;   ///< 执行者
@property (nonatomic, assign, getter=isExecuting) BOOL executing;
@property (nonatomic, assign, getter=isFinished) BOOL finished;
@property (nonatomic, assign, readonly) BOOL suspended;   ///< 是否挂起等待操作
@property (nonatomic, weak) id converter; ///< 转换器

@end

@implementation PYIMOperation

@synthesize finished = _finished;
@synthesize executing = _executing;

adpcm_state encode_state;
adpcm_state decode_state;

- (instancetype)initWithMode:(PYIMModeNetwork*)mode sock:(GCDAsyncUdpSocket*)sock sockTcp:(GCDAsyncSocket*)sockTcp converter:(id)converter {
    self = [super init];
    if(self){
        _mode = mode;
        _socket = sockTcp;
        _socketUdp = sock;
        _converter = converter;
        //        [[NSRunLoop currentRunLoop] run];
    }
    
    return self;
}

/// 重写了start就不再走main函数了， 被queue触发调用，也可以手动触发调用
- (void)start {
    if ([self isCancelled]) {
        NSLog(@"已取消，不再执行 cmd:0x%04x seqID:%d", self.mode.cmdID, self.mode.seqID);
        // Must move the operation to the finished state if it is canceled.
        self.finished = YES;
        //内存清空
        [self dispose];
        return;
    }
    
    [self prepareTask];
}

- (void)dispose {
    self.mode = nil;
    [self cancelTimer];
}

- (void)prepareTask {
    if(self.isFinished || self.isCancelled)
        return;
    
    self.executing = YES;
    
    //    NSLog(@"task excuting thread:%@", [NSThread currentThread]);
    
    if(_timer){
        [_timer invalidate];
        _timer = nil;
    }
    
    // 这里不再判断，发送后才计算timeout
    //    if(self.mode.timeOut){
    //        [self operationFinishedWithErrorCode:NSURLErrorTimedOut];
    //        return;
    //    }
    
    // 控制超时
    self.timer = [NSTimer timerWithTimeInterval:self.mode.media.timeOutSpan target:self selector:@selector(timerDown) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    
    
    NSData *dataSend = [self.mode.media getSendData:self.converter]; // 必须这里调用，确保相关判断触发
    if(dataSend==nil || dataSend.length==0){
        self.finished = YES;
        NSLog(@"发送数据为空：cmd:0x%04x, port:%d, host:%@ size:%ti seqID:%d", self.mode.cmdID, self.mode.portServer, self.mode.hostServer, dataSend.length, self.mode.media.seqID);
        return;
    }
    
    if(self.socket){
        if(self.socket.isConnected){
            [self.socket writeData:dataSend withTimeout:-1 tag:self.mode.tagSelf];
        }else {
            [self operationFinishedWithErrorCode:NSURLErrorCannotConnectToHost];
            return; // 未开始执行
        }
    }else if(self.socketUdp){
        if(kAccount.chatState==0 && (self.mode.cmdID == C2C_AUDIO_FRAME||
                                     self.mode.cmdID == C2C_VIDEO_FRAME ||
                                     self.mode.cmdID == C2C_VIDEO_FRAME_EX)){
            [self operationFinishedWithErrorCode:NSURLErrorCancelled];
            return;
        }
        
        [self.socketUdp sendData:dataSend toHost:self.mode.hostServer port:self.mode.portServer withTimeout:-1 tag:self.mode.tagSelf];
    }
    
    NSLog(@"%@发送数据：cmd:0x%04x, port:%d, host:%@ size:%ti seqID:%d",self.mode.media.sendCount>0?[NSString stringWithFormat:@"第%ti次", self.mode.media.sendCount]:@"", self.mode.cmdID, self.mode.portServer, self.mode.hostServer, dataSend.length, self.mode.media.seqID);
    
    if ([self.mode.hostServer isEqualToString:kAccount.srvIp] && self.mode.portServer == kAccount.srvPort) {
        kAccount.srvRecvTime = [[NSDate date] timeIntervalSince1970];
    }else {
        kAccount.toRecvTime = [[NSDate date] timeIntervalSince1970];
    }
    
}

- (void)operationFinishedWithErrorCode:(NSInteger)code {
    NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:code userInfo:nil];
    PYIMError *err = [[PYIMError alloc] initWithError:nil];
    err.cmdID = self.mode.cmdID;
    if(code==0)
        err.cmdStatus = C2S_ERR_OK;
    else
        err.errDesc = error.localizedDescription;
    [self operationFinished:err];
}

- (void)operationFinished:(PYIMError*)error {
    // 此处检查发生错误再次触发,媒体不重发
    if(error.success || !self.mode.resendable || (!kAccount.hadLogin && self.mode.media.sType!=EServer_Login)){
        [self.mode finished:error];
        if(self.isExecuting)
            self.finished = YES; // 注意不设置finished，opr不会从queue中移除
        else{
            [self cancelTimer];
            [super cancel];
        }
    }else {
        [self.mode.media prepareReSend];
        // 再次执行
        [self prepareTask];
    }
}

- (void)timerDown {
    // 已结束、挂起并且还未被执行，超时不关心；挂起还未执行queue恢复后，会触发走流程
    if(self.isFinished || (self.suspended && !self.isExecuting))return;
    
    NSLog(@"任务超时：0x%04x, port:%d", self.mode.cmdID, self.mode.portServer);
    [self operationFinishedWithErrorCode:NSURLErrorTimedOut];
}

- (void)cancel {
    [self cancelTimer];
    [self operationFinishedWithErrorCode:NSURLErrorTimedOut];
    
    NSLog(@"opr canceled cmd:0x%04x host:%@ port:%d", self.mode.cmdID, self.mode.hostServer, self.mode.portServer);
    
    [super cancel];
}

- (void)cancelTimer {
    if(self.timer){
        [self.timer invalidate];
        self.timer = nil;
    }
}

/// 注意这里手动设置结束，表示想要一出去opr，不能触发任务回调，所以是cancel
- (void)setFinished:(BOOL)finished {
    [self cancelTimer];
    
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isAsynchronous {
    return YES;
}

- (void)dealloc {
    self.mode = nil;
    [self cancelTimer];
//    NSLog(@"dealloc NSOperation cmd:0x%04x seq:%d ip:%@ port:%d", self.mode.cmdID, self.mode.seqID, self.mode.hostServer, self.mode.portServer);
}

@end

@interface PYIMNetworkTcpManager : NSObject <GCDAsyncSocketDelegate> {
    NSData *dataPartial; // 上一次socket回调接收不完整部分
    dispatch_queue_t queueSock; /// 控制队列
}

@property (nonatomic, strong) NSOperationQueue *queue;   ///< 操作队列
@property (nonatomic, strong) GCDAsyncSocket *socket;   ///< tcp\udp层网络数据处理者

@property (nonatomic, assign) BOOL hadLogin;   ///< 是否已登录
@property (nonatomic, strong) NSString *host;   ///< 主机地址
@property (nonatomic, assign) ushort port;   ///< 端口
@property (nonatomic, assign) PYNetworkSocketState sockState;   ///< 状态

@property (nonatomic, assign) BOOL hadEnterBackground;   ///< 是否转后台了

@property (nonatomic, strong) PYIMModeNetwork *modeLogin;   ///< 登录任务缓存，下次登录替换
@property (nonatomic, strong) PYIMModeNetwork *modeServer;   ///< 服务器主动通知任务关联
@property (nonatomic, assign) long tagHeart;   ///< 心跳任务
@property (nonatomic, strong) PYIMVideoConverter *converter; ///< 转换器

@end

@implementation PYIMNetworkTcpManager

- (instancetype)init {
    self = [super init];
    if(self){
        // 初始化需要的变量
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 1; // 任务队列最大并发数量
        queueSock = dispatch_queue_create("com.PYnetwork.socktetTcpqueue", DISPATCH_QUEUE_SERIAL); // the socket queue must not be a concurrent queue,
        _converter = [[PYIMVideoConverter alloc] init];
    }
    
    return self;
}

- (void)setSockState:(PYNetworkSocketState)sockState {
    _sockState = sockState;
    
    switch (sockState) {
        case ENetworkSocketState_Connecting: {
            [_queue setSuspended:YES];
            
            NSLog(@"socket connecting");
        } break;
            
        case ENetworkSocketState_Connected: {
            [_queue setSuspended:NO];
            kAccount.videoState = 1;
            NSLog(@"socket connected:%@ port:%d", _host, _port);
        } break;
            
        case ENetworkSocketState_Disconnect: {
            [_queue setSuspended:NO]; // 打开让任务反馈回去？还是等下次连接成功，继续执行任务，增加任务时效判断？
            kAccount.videoState = 0;
            NSLog(@"socket disconnect");
        } break;
            
        default:
            break;
    }
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPY_NetworkStatusChanged object:@{@"state":@(_sockState)}];
    });
}

- (void)setHadLogin:(BOOL)hadLogin {
    _hadLogin = hadLogin;
    kAccount.hadLoginVideo = hadLogin;
    NSLog(@"%@ port:%d", hadLogin?@"登录成功":@"退出登录", _port);
}

#pragma mark task excuting control

#pragma mark task manager

- (void)addTask:(PYIMModeNetwork*)task {
    [self connectSocket];
    
    // 如果再连接中，queue会阻塞的连接成功新任务会自动触发
    if(self.sockState == ENetworkSocketState_Disconnect) {
        [task finishedWithCode:C2S_ERR_Disconnect];
        return;
    }
    
    task.hostServer = kAccount.videoIp;
    task.portServer = kAccount.videoPort;
    
    [self connectSocket];
    
    PYIMOperation *opr = [[PYIMOperation alloc] initWithMode:task sock:nil sockTcp:_socket converter:_converter];
    [self addTaskToQueue:opr];
}

- (void)addTaskToQueue:(PYIMOperation*)opr {
    [_queue addOperation:opr];
    
    //    NSLog(@"number of task: %zi queue suspend: %@", _queue.operations.count, _queue.isSuspended ? @"YES":@"NO");
}

- (void)removeTasksWithAddr:(long)addr {
    [_queue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PYIMOperation *temp = (PYIMOperation*)obj;
        if(temp.mode.tagSelf==addr){
            [temp cancel];
            temp.finished = YES;
        }else if(addr==0){
            // 清理潜在的错误数据，如果任务在队列中时间已经超过1分钟，必须强制清除
            if(temp.mode.needClean){
                [temp cancel];
                temp.finished = YES;
                
                NSLog(@"task cleaned:0x%04x", temp.mode.cmdID);
            }
        }
    }];
}

- (PYIMOperation*)operationWithTag:(long)addr {
    __block PYIMOperation *opr = nil;
    [_queue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PYIMOperation *temp = (PYIMOperation*)obj;
        if(temp.mode.tagSelf==addr){
            opr = temp;
            *stop = YES;
        }
    }];
    return opr;
}

- (PYIMOperation*)operationWithSerialNum:(long)serialNum {
    __block PYIMOperation *opr = nil;
    [_queue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PYIMOperation *temp = (PYIMOperation*)obj;
        if(temp.mode.seqID==serialNum){
            opr = temp;
            *stop = YES;
        }
    }];
    
    return opr;
}

- (void)cancelTask:(NSArray*)tasks {
    NSMutableArray *temp = [NSMutableArray arrayWithArray:tasks];
    for(PYIMOperation *opr in _queue.operations){
        for(PYIMModeNetwork *task in tasks){
            task.callback = nil;
            task.media.resentCount = 0;
            
            if(opr.mode.tagSelf == task.tagSelf){
                [opr cancel];
                opr.finished = YES;
                [temp removeObject:task];
                break;
            }
        }
    }
}

/// 暂停manger中待执行opr
- (void)pauseManager {
    self.hadEnterBackground = YES;
    [_queue setSuspended:YES];
}

/// 回复manager执行队列
- (void)resumeManager {
    self.hadEnterBackground = NO;
    [_queue setSuspended:NO];
}

#pragma mark socket delegate

- (void)connectWithHost:(NSString*)host port:(ushort)port {
    if(_socket){
        [_socket disconnect];
        _socket.delegate = nil;
        _socket = nil;
    }
    
    if(_queue.operations.count>0){
        for(PYIMOperation *opr in _queue.operations){
            [opr cancel];
            opr.finished = YES; // 从queue移除
        }
        
        [_queue cancelAllOperations];
    }
    
    _host = host;
    _port = port;
    // 必须要登录后才能连接
    _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:queueSock]; // 工作线程执行
    [self connectSocket];
}

- (void)connectSocket {
    if(self.socket.isConnected || self.sockState==ENetworkSocketState_Connecting)return;
    
    self.sockState = ENetworkSocketState_Connecting;
    
    NSError *error;
    BOOL result = [_socket connectToHost:_host onPort:_port error:&error]; // 超时后通过socketDidDisconnect回调
    if(!result && error){
        self.sockState = ENetworkSocketState_Disconnect;
    }
}

/// 链接主机完成
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    self.sockState = ENetworkSocketState_Connected;
    [sock readDataWithTimeout:-1 tag:0]; // 加上这句话后能立刻接收服务器消息
}

/// 链接断开
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    self.sockState = ENetworkSocketState_Disconnect; // 阻塞任务队列
    
    [kNote writeNote:[NSString stringWithFormat:@"disconnect for:%@", err.localizedDescription]];
    NSLog(@"disconnect for:%@", err.localizedDescription);
    
    if (err.code == GCDAsyncSocketClosedError || err.code == 32 || err.code == GCDAsyncSocketConnectTimeoutError) {
        if(err.code == 32)
            NSLog(@"服务器主动断开连接");
        
        // 这里不触发重连，待心跳触发或者新任务触发
    }
}

/// 数据流开始接收 - 未完成：以后显示进度用
- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    PYIMOperation *opr = [self operationWithTag:tag];
    if(opr){
        if(opr.mode.cmdID == C2C_VIDEO_FRAME ||
           opr.mode.cmdID == C2C_VIDEO_FRAME_EX){
            [opr operationFinishedWithErrorCode:0];
        }
    }
}

/// 数据流接收完成
- (void)socket:(GCDAsyncSocket *)sock didReadData:(nonnull NSData *)data withTag:(long)tag {
    /**
     解决粘包问题：
     1.读取完成后解析数据以前后对称的3E标志分段
     2.根据每段数据解析其内容中的流水号，对应到任务对象上
     3.以上解析受后台数据格式定义限制，在这里起始最简单就是前2个字节代表一个任务数据长度，3-4字节代表流水号，这样不用解析内容；需要时才解析（OC总是会在最佳时间处理相关任务，开发人员同样要在代码逻辑中秉持此原则）
     4.由于可能出现粘包，所以tag已经无效了
     */
    //    dispatch_barrier_sync(queueSock, ^{
    NSData *result = data;
    if(dataPartial.length>0){
        NSMutableData *mData = [NSMutableData data];
        [mData appendData:dataPartial];
        [mData appendData:data];
        result = mData;
        
        dataPartial = nil;
    }
    
    NSArray *resuts = [PYIMModeNetwork cutPackage:result converter:@[_converter] callback:^(NSData *dataPart) {
        dataPartial = dataPart;
        [kNote writeNote:@"socket read partion data"];
        NSLog(@"socket read partion data");
    }];
    
    for(PYIMModeMedia *temp in resuts){
        PYIMModeMedia *package = temp;
        
        ////// 收到服务器数据分包处理，先不考虑
        ////// end
        
        if(_modeServer && package.cmdID == kCMD_Re_ServerMsg){
            [_modeServer finished:package];
            continue;
        }
        
        PYIMOperation *opr = [self operationWithSerialNum:package.seqID];
        if(opr){
            // 处理自己发送分包分包返回请，暂时不考虑
            [opr operationFinished:package];
        }else {
            NSLog(@"task finished without find operation 0x%04x", package.cmdID);
            if(_modeServer){
                [_modeServer finished:package];
            }
        }
    }
    //    });
}

/// 数据流发送中 - 未完成：以后显示进度用
- (void)socket:(GCDAsyncSocket *)sock didWritePartialDataOfLength:(NSUInteger)partialLength tag:(long)tag {
    // TODO: 后期考虑分包情况支持
    //    PYIMOperation *opr = [self operationWithTag:tag];
    //    if(opr){
    //        opr.mode.status = ECmodeStatusSending;
    //        opr.mode.partialLength = partialLength;
    //    }
}

/// 数据流发送完成
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag {
    // TODO: 后期考虑分包情况支持
    //    PYIMOperation *opr = [self operationWithTag:tag];
    //    if(opr){
    //        opr.mode.status = ECmodeStatusSended;
    //    }
    
    //    [sock readDataToLength:2 withTimeout:-1 tag:tag];  如果接受数据前2个字节用户读取本次消息长度，采用这个方式触发
    
    PYIMOperation *opr = [self operationWithTag:tag];
    if(opr){
        if(opr.mode.cmdID == C2C_VIDEO_FRAME){
            
        }
    }
    
    [sock readDataWithTimeout:-1 tag:tag]; // 触发等待读取数据，否则不会自动触发委托回调；此方法socket会读取完本次数据回调，然后通过数据标识位分段一次获取的数据，必须和后台协商好断包控制
}

/// 接收数据超时控制
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length {
    
    // TODO: 后期考虑分包情况支持
    //    PYIMOperation *opr = [self operationWithTag:tag];
    //    if(opr){
    //        opr.mode.status = ECmodeStatusReceiving;
    //        opr.mode.lengthOfStream = length;
    //    }
    
    return -1;
}

/// 发送数据超时控制
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length {
    
    // TODO: 后期考虑分包情况支持
    //    PYIMOperation *opr = [self operationWithTag:tag];
    //    if(opr){
    //        opr.mode.status = ECmodeStatusSending;
    //        opr.mode.lengthOfStream = length;
    //    }
    
    return -1;
}

/// SSL安全协议验证通过
- (void)socketDidSecure:(GCDAsyncSocket *)sock {
    NSLog(@"completed SSL/TLS negotiation");
}

/// TLS握手监听
- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(nonnull SecTrustRef)trust completionHandler:(nonnull void (^)(BOOL))completionHandler {
    NSLog(@"TLS handshake and manually validate the peer it's connecting to");
}

#pragma mark heart

- (void)loginKeep {
    if(_modeLogin && !self.hadLogin){
        PYIMOperation *temp = [self operationWithSerialNum:_modeLogin.seqID];
        if(temp==nil){
            [_modeLogin.media prepareReSend];
            temp = [[PYIMOperation alloc] initWithMode:_modeLogin sock:nil sockTcp:_socket converter:_converter];
            [self addTaskToQueue:temp];
        }
    }
}

- (void)heartKeep {
    // 如果任务中没有心跳，触发新心跳
    PYIMOperation *opr = [self operationWithTag:_tagHeart];
    if(opr==nil){
        PYIMModeNetwork *heart = [self createServerHeart];
        [self addTask:heart];
    }
    
    // 清理任务超长时间任务（按理不可能存在，任务超时时间不会大于60秒，超时会自动返回释放）
    [self removeTasksWithAddr:0];
}

/// encodeHeartBeat
- (PYIMModeNetwork*)createServerHeart {
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.cmdID = C2S_HEART_BEAT;
    CmdHeartBeat heart = {0};
    heart.account = htonll_x(kAccount.myAccount);
    memcpy(heart.localIp, self.socket.localAddress.bytes, self.socket.localAddress.length);
    heart.localPort = htons_x(self.socket.localPort);
    
    // ip,port 通过已连接的socket对象获取
    media.dataParam = [NSData dataWithBytes:&heart length:sizeof(CmdHeartBeat)];
    
    PYIMModeNetwork *netw = [[PYIMModeNetwork alloc] init];
    netw.media = media;
    
    _tagHeart = netw.tagSelf;
    
    return netw;
}

@end

@interface PYIMNetworkManager() <GCDAsyncUdpSocketDelegate> {
    NSTimer *timerHeart;
    NSInteger heartTimespan;
    NSData *dataPartial; // 上一次socket回调接收不完整部分
    dispatch_queue_t queueSock; // 控制队列
}

@property (nonatomic, strong) NSOperationQueue *queue;   ///< 操作队列
@property (nonatomic, strong) GCDAsyncUdpSocket *socket;   ///< tcp\udp层网络数据处理者
@property (nonatomic, strong) GCDAsyncUdpSocket *socketC2C;   ///< tcp\udp层网络数据处理者

@property (nonatomic, strong) NSString *host;   ///< 主机地址
@property (nonatomic, assign) ushort port;   ///< 端口
@property (nonatomic, assign) PYNetworkSocketState sockState;   ///< 状态

@property (nonatomic, assign) BOOL hadLogin;   ///< 是否已登录
@property (nonatomic, assign) BOOL hadEnterBackground;   ///< 是否转后台了

@property (nonatomic, strong) PYIMModeNetwork *modeLogin;   ///< 登录任务缓存，下次登录替换
@property (nonatomic, strong) PYIMModeNetwork *modeServer;   ///< 服务器主动通知任务关联
@property (nonatomic, assign) long tagHeart;   ///< 心跳任务

// 语音视频需要才链接，断开后需要清理；目前语音视频只能和一个人进行所以不做控制
@property (nonatomic, strong) PYIMNetworkTcpManager *managerVideo;    ///< 视频
@property (nonatomic, strong) PYIMNetworkManager *managerAudio;    ///< 音频

@property (nonatomic, assign) PYServerType sType;    ///< 服务器类型

@end

@implementation PYIMNetworkManager

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    
    return manager;
}

- (instancetype)init {
    self = [super init];
    if(self){
        // 初始化需要的变量
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = 10; // 任务队列最大并发数量，语音发送具有时效性
        queueSock = dispatch_queue_create("sockettask", DISPATCH_QUEUE_SERIAL); // the socket queue must not be a concurrent queue
        heartTimespan = 15; // 默认30s
        
        self.sType = EServer_Login;
    }
    
    return self;
}

- (void)setSockState:(PYNetworkSocketState)sockState {
    _sockState = sockState;
    
    switch (sockState) {
        case ENetworkSocketState_Connecting: {
            [_queue setSuspended:YES];
            
            [kNote writeNote:[NSString stringWithFormat:@"socket connecting:%@ port:%d", _host, _port]];
            NSLog(@"socket connecting:%@ port:%d", _host, _port);
        } break;
            
        case ENetworkSocketState_Connected: {
            [_queue setSuspended:NO];
            
            if(self.sType==EServer_Login)
                kAccount.srvState = 1;
            else
                kAccount.audioState = 1;
            
            [kNote writeNote:[NSString stringWithFormat:@"socket connected:%@ port:%d", _host, _port]];
            NSLog(@"socket connected:%@ port:%d", _host, _port);
        } break;
            
        case ENetworkSocketState_Disconnect: {
            [_queue setSuspended:NO]; // 打开让任务反馈回去？还是等下次连接成功，继续执行任务，增加任务时效判断？
            self.hadLogin = NO;
            
            if(self.sType==EServer_Login){
                kAccount.srvState = 0;
                kAccount.hadLogin = NO;
            } else {
                kAccount.audioState = 0;
                kAccount.hadLoginAudio = NO;
            }
            
            [kNote writeNote:[NSString stringWithFormat:@"socket disconnected:%@ port:%d", _host, _port]];
            NSLog(@"socket disconnected:%@ port:%d", _host, _port);
        } break;
            
        default:
            break;
    }
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPY_NetworkStatusChanged object:@{@"state":@(_sockState), @"server":@(self.sType)}]; // server
    });
}

- (void)setHadLogin:(BOOL)hadLogin {
    _hadLogin = hadLogin;
    
    if(self.sType == EServer_Login) {
        kAccount.hadLogin = hadLogin;
        [self heartStateChanged];
    } else
        kAccount.hadLoginAudio = hadLogin;
    
    [kNote writeNote:[NSString stringWithFormat:@"%@ port:%d account:%lld", hadLogin?@"登录成功":@"退出登录", _port, kAccount.myAccount]];
    NSLog(@"%@ port:%d account:%lld", hadLogin?@"登录成功":@"退出登录", _port, kAccount.myAccount);
    
}

- (PYIMNetworkManager*)managerAudio {
    if(_managerAudio==nil){
        _managerAudio = [[PYIMNetworkManager alloc] init];
        _managerAudio.sType = EServer_Audio;
        _managerAudio.queue.maxConcurrentOperationCount = 1; // 语音顺序发送
    }
    
    return _managerAudio;
}

- (PYIMNetworkTcpManager*)managerVideo {
    if(_managerVideo==nil){
        _managerVideo = [[PYIMNetworkTcpManager alloc] init];
    }
    
    return _managerVideo;
}

- (PYIMVideoConverter*)converterVideo {
    if(_converterVideo == nil){
        _converterVideo = [[PYIMVideoConverter alloc] init];    // 视频转化器中会有内存泄漏
    }
    
    return _converterVideo;
}

- (PYIMAudioConverter*)converter {
    if(_converter == nil){
        _converter = [[PYIMAudioConverter alloc] init];
    }
    
    return _converter;
}

#pragma mark task excuting control

#pragma mark task manager

- (void)addTask:(PYIMModeNetwork*)task {
    if(task.media.cmdID == kCMD_Re_ServerMsg){
        _modeServer = task;
        
        if(self.sType == EServer_Login){
            PYIMModeNetwork *temp = [_modeServer copy];
            [self.managerAudio addTask:temp];
            
            //            temp = [_modeServer copy];
            //            [self.managerVideo addTask:temp];
        }
        return;
    }
    
    [self connectSocket];
    
    // 如果再连接中，queue会阻塞的连接成功新任务会自动触发
    if(self.sockState == ENetworkSocketState_Disconnect) {
        [task finishedWithCode:C2S_ERR_Disconnect];
        return;
    }
    
    if(task.media.sType == EServer_Login){
        if(task.cmdID == C2C_CLOSE ||
           task.cmdID == C2S_HEART_BEAT ||
           task.cmdID == C2S_LOGOUT ||
           task.cmdID == C2S_LOGIN) {
            if (kAccount.videoState > 0)
            {
                PYIMModeNetwork *temp = [task copy];
                temp.media.sType = EServer_Video;
                temp.hostServer = kAccount.videoIp;
                temp.portServer = kAccount.videoPort;
                //                [self.managerVideo addTask:temp];
            }
            
            if (kAccount.audioState > 0)
            {
                PYIMModeNetwork *temp = [task copy];
                temp.media.sType = EServer_Audio;
                temp.hostServer = kAccount.audioIp;
                temp.portServer = kAccount.audioPort;
                [self.managerAudio addTask:temp];
            }
        }
        
        if(task.cmdID == C2C_AUDIO_FRAME ||
           task.cmdID == C2C_VIDEO_FRAME ||
           task.cmdID == C2C_VIDEO_FRAME_EX ||
           task.cmdID == C2C_HOLE ||
           task.cmdID == C2C_HEART_BEAT ||
           task.cmdID == C2C_HEART_BEAT_RSP) {
            [self setTaskSendIpPort:task];
            
        }else {
            task.hostServer = kAccount.srvIp;
            task.portServer = kAccount.srvPort;
        }
        
    }else if(task.media.sType == EServer_Audio && self.sType == EServer_Login){
        task.hostServer = kAccount.audioIp;
        task.portServer = kAccount.audioPort;
        [self.managerAudio addTask:task];
        return;
        
    }else if(task.media.sType == EServer_Video){
        [self.managerVideo addTask:task];
        return;
    }
    
    PYIMOperation *opr = [[PYIMOperation alloc] initWithMode:task sock:_socket sockTcp:nil converter:(task.cmdID==C2C_VIDEO_FRAME||task.cmdID==C2C_VIDEO_FRAME_EX)?_converterVideo:_converter];
    
    // 如果没有登录，需要特殊判断非登录下的指令（由于注册等都没有走socket所以，没登录就不启用socket）
    if(!self.hadLogin){
        // 登录前将其他任务移除
        [self removeTasksWithAddr:1];
        
        if(task.cmdID == C2S_LOGIN){
            _modeLogin = [task copy];
            _modeLogin.callback = nil; // 内部使用不反馈
            if(self.sType!=EServer_Login)
                task.callback = nil; // 只有登录服务器需要返回，其他如果失败会在登录服务器成功后，重新尝试（登录过程除非主动退出登录，否则一直会尝试登录）
            
            if(self.sType==EServer_Login)
                [self addTaskToQueue:opr]; // 只有登录服务器登录后才尝试登录其他服务器；登录服务器登录后会通过心跳触发其他服务器登录
        }else{
            [task finishedWithCode:C2S_ERR_NOTLOGIN];
            
            [self loginKeep];
        }
        
        return;
    }
    
    [self addTaskToQueue:opr];
}

- (void)addTaskToQueue:(PYIMOperation*)opr {
    if(opr.mode.hostServer == nil || opr.mode.hostServer.length==0 || opr.mode.portServer ==0) {
        NSString *desc = [NSString stringWithFormat:@"服务器参数配置错误:host %@, port:%d server:%d", opr.mode.hostServer, opr.mode.portServer, _port];
        NSLog(@"%@", desc);
        [opr.mode finishedWithErrDesc:desc];
        return;
    }
    
    [_queue addOperation:opr];
    
    NSLog(@"number of opr in queue %ti", _queue.operations.count);
}

- (void)removeTasksWithAddr:(long)addr {
    if(addr==1){
        [_queue cancelAllOperations];
        return;
    }
    
    [_queue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PYIMOperation *temp = (PYIMOperation*)obj;
        if(temp.mode.tagSelf==addr){
            [temp cancel];
            temp.finished = YES;
        }else if(addr<=1){
            // 清理潜在的错误数据，如果任务在队列中时间已经超过1分钟，必须强制清除
            if(temp.mode.needClean){
                [temp cancel];
                temp.finished = YES;
                
                NSLog(@"task cleaned:0x%04x", temp.mode.cmdID);
            }
        }
    }];
}

- (PYIMOperation*)operationWithTag:(long)addr {
    __block PYIMOperation *opr = nil;
    [_queue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PYIMOperation *temp = (PYIMOperation*)obj;
        if(temp.mode.tagSelf==addr){
            opr = temp;
            *stop = YES;
        }
    }];
    return opr;
}

- (PYIMOperation*)operationWithSerialNum:(long)serialNum {
    __block PYIMOperation *opr = nil;
    [_queue.operations enumerateObjectsUsingBlock:^(__kindof NSOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PYIMOperation *temp = (PYIMOperation*)obj;
        if(temp.mode.seqID==serialNum){
            opr = temp;
            *stop = YES;
        }
    }];
    
    return opr;
}

- (void)cancelTask:(NSArray*)tasks {
    NSMutableArray *temp = [NSMutableArray arrayWithArray:tasks];
    for(PYIMOperation *opr in _queue.operations){
        for(PYIMModeNetwork *task in tasks){
            if(opr.mode.tagSelf == task.tagSelf){
                [opr cancel];
                opr.finished = YES;
                [temp removeObject:task];
                break;
            }
        }
    }
    
    if(self.sType==EServer_Login){
        if(self.managerAudio)
            [self.managerAudio cancelTask:temp];
        
        if(self.managerVideo)
            [self.managerVideo cancelTask:temp];
    }
}

/// 暂停manger中待执行opr
- (void)pauseManager {
    self.hadEnterBackground = YES;
    [_queue setSuspended:YES];
}

/// 回复manager执行队列
- (void)resumeManager {
    self.hadEnterBackground = NO;
    [_queue setSuspended:NO];
    
    // 强起一次心跳
    if(self.sType == EServer_Login)
        [self heartKeep];
}

- (void)connectWithHost:(NSString*)host port:(ushort)port {
    if(_socket){
        [_socket close];
        _socket.delegate = nil;
        _socket = nil;
    }
    
    if(_queue.operations.count>0){
        for(PYIMOperation *opr in _queue.operations){
            [opr cancel];
            opr.finished = YES; // 从queue移除
        }
        
        [_queue cancelAllOperations];
    }
    
    _host = host;
    _port = port;
    _socket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:queueSock]; // 工作线程执行
    
    [self connectSocket];
}

- (void)connectAudioWithHost:(NSString*)host port:(ushort)port {
    [self.managerAudio connectWithHost:host port:port];
}

- (void)connectVideoWithHost:(NSString*)host port:(ushort)port {
    [self.managerVideo connectWithHost:host port:port];
}

- (void)connectSocket {
    if(self.sockState==ENetworkSocketState_Connected || self.sockState == ENetworkSocketState_Connecting)return;
    
    self.sockState = ENetworkSocketState_Connecting;
    
    if(self.sType == EServer_Login){
        [kAccount updateWithHost:_host port:_port];
    }
    
    NSError *error;
    
    BOOL result = [_socket bindToPort:_port error:&error];
    
    //    BOOL result = [_socket connectToHost:_host onPort:_port error:&error]; // 超时后通过socketDidDisconnect回调
    if(!result && error){
        self.sockState = ENetworkSocketState_Disconnect;
    }else {
        [_socket enableBroadcast:YES error:&error];
        if(error==nil){
            [_socket beginReceiving:&error];
            
            if (kAccount.srvState == 0 && self.sType == EServer_Login)
            {
                _socketC2C = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:queueSock]; // 工作线程执行
                
                for (uint16_t port = P2P_INIT_LISTEN_PORT; port < 10000; port++)
                {
                    result = [_socketC2C bindToPort:port error:&error];
                    
                    if(result && error==nil){
                        kAccount.myLocalPort = P2P_INIT_LISTEN_PORT;
                        
                        [self getIPAddress];
                        
                        [_socket enableBroadcast:YES error:&error];
                        if(error==nil){
                            [_socketC2C beginReceiving:&error];
                            if(error==nil){
                                NSLog(@"C2C端口绑定成功 %d", port);
                            }
                        }
                        break;
                    }
                }
            }
            
            self.sockState = ENetworkSocketState_Connected;
        }
    }
}

- (void)getIPAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    success = getifaddrs(&interfaces);
    if (success == 0) {
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr->sa_family == AF_INET) {
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in*)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    [kNote writeNote:[NSString stringWithFormat:@"获取本地ip:%@", address]];
    NSLog(@"获取本地ip:%@", address);
    
    if(address.length>5)
        kAccount.myLocalIp = address;
}

#pragma mark socket Udp delegate

// 采用connectToHost链接host才会走此回调
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didConnectToAddress:(NSData *)address {
    self.sockState = ENetworkSocketState_Connected;
    
    if(!self.hadLogin){
        BOOL exist = NO;
        for(PYIMOperation *opr in _queue.operations){
            if(opr.mode.cmdID == C2S_LOGIN){
                [opr.mode.media prepareReSend];
                
                [opr start];
                exist = YES;
                break;
            }else if(!opr.isExecuting){
                NSLog(@"task restarted by network recover");
                [opr start];
            }
        }
        
        if(!exist && _modeLogin){
            // 手动触发登录，每次断线后都要重新登录
            [_modeLogin.media prepareReSend];
            
            PYIMOperation *temp = [[PYIMOperation alloc] initWithMode:_modeLogin sock:_socket sockTcp:nil converter:_converter];
            [_queue addOperation:temp];
        }
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotConnect:(NSError *)err {
    self.sockState = ENetworkSocketState_Disconnect; // 阻塞任务队列
    
    [kNote writeNote:[NSString stringWithFormat:@"udp disconnect for:%@%d port:", err.localizedDescription, _port]];
    NSLog(@"disconnect for:%@%d port:", err.localizedDescription, _port);
    if (err.code == GCDAsyncSocketClosedError || err.code == 32 || err.code == GCDAsyncSocketConnectTimeoutError) {
        if(err.code == 32)
            NSLog(@"服务器主动断开连接");
        
        // 这里不触发重连，待心跳触发或者新任务触发
    }
}

- (void)udpSocketDidClose:(GCDAsyncUdpSocket *)sock withError:(NSError *)err {
    self.sockState = ENetworkSocketState_Disconnect; // 阻塞任务队列
    
    [kNote writeNote:[NSString stringWithFormat:@"close for:%@ %ti port:%d", err.localizedDescription, err.code, _port]];
    NSLog(@"close for:%@ %ti port:%d", err.localizedDescription, err.code, _port);
    if (err.code == GCDAsyncSocketClosedError || err.code == 32 || err.code == GCDAsyncSocketConnectTimeoutError) {
        if(err.code == 32)
            NSLog(@"服务器主动断开连接");
        
        // 这里不触发重连，待心跳触发或者新任务触发
    }
}

// 发送完成
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didSendDataWithTag:(long)tag {
    [self udpSendHandle:tag error:nil sock:sock];
}

// 接收完成
- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    /**
     解决粘包问题：
     1.读取完成后解析数据以前后对称的3E标志分段
     2.根据每段数据解析其内容中的流水号，对应到任务对象上
     3.以上解析受后台数据格式定义限制，在这里起始最简单就是前2个字节代表一个任务数据长度，3-4字节代表流水号，这样不用解析内容；需要时才解析（OC总是会在最佳时间处理相关任务，开发人员同样要在代码逻辑中秉持此原则）
     4.由于可能出现粘包，所以tag已经无效了
     */
    if ([sock.connectedHost isEqualToString:kAccount.srvIp] && sock.connectedPort == kAccount.srvPort) {
        kAccount.srvRecvTime = [[NSDate date] timeIntervalSince1970];
    } else {
        kAccount.toRecvTime = [[NSDate date] timeIntervalSince1970];
    }
    
    NSData *addr = [NSData dataWithData:address];
    
    kAccount.rspIp = [GCDAsyncUdpSocket hostFromAddress:addr];
    kAccount.rspPort = [GCDAsyncUdpSocket portFromAddress:addr];
    
    NSData *result = data;
    if(dataPartial.length>0){
        NSMutableData *mData = [NSMutableData data];
        [mData appendData:dataPartial];
        [mData appendData:data];
        result = mData;
        
        dataPartial = nil;
    }
    
    NSArray *resuts = [PYIMModeNetwork cutPackage:result converter:kAccount.chatState>0?@[self.converter, self.converterVideo]:nil callback:^(NSData *dataPart) {
        dataPartial = dataPart;
        [kNote writeNote:@"socket read partion data"];
        NSLog(@"socket read partion data");
    }];
    
    for(PYIMModeMedia *temp in resuts){
        PYIMModeMedia *package = temp;
        
        ////// 收到服务器数据分包处理，先不考虑
        ////// end
        
        if(_modeServer && package.cmdID == kCMD_Re_ServerMsg){
            [_modeServer finished:package];
            continue;
        }
        
        if(package.cmdStatus == C2S_ERR_NOTLOGIN){
            self.hadLogin = NO;
            [self loginKeep];
        }
        
        PYIMOperation *opr = [self operationWithSerialNum:package.seqID];
        if(opr){
            if(package.cmdID == C2S_LOGIN_RSP){
                self.hadLogin = package.success;
                if(package.success && self.sType==EServer_Login){
                    // 立刻发起一次心跳
                    [self heartKeep];
                }
            }
            
            // 处理自己发送分包分包返回请，暂时不考虑
            [opr operationFinished:package];
        }else {
            NSLog(@"receive data cmdRec:0x%04x server:%@ fromPort:%d mediasize:%ti seq:%d", package.cmdID, kAccount.rspIp, kAccount.rspPort, package.mode?package.mode.media.length:0, package.seqID);
            // ** 注意，明确了不等待服务器反馈的指令，需要在这里关心断开返回的结果
            
            // c2c判断
            if(package.cmdID == C2C_HEART_BEAT){
                // 注意不同socket关联的是自己的queue
                [self heartResponse];
            }else if(package.cmdID == C2S_HEART_BEAT_RSP){
                if(!package.success && self.hadLogin){
                    self.hadLogin = NO;
                    [self loginKeep];
                }
                
                NSLog(@"心跳%@ status:%@ port:%d", package.success?@"成功":@"失败", package.errDesc?package.errDesc:@"", _port);
            }else if(package.cmdID == C2C_VIDEO_FRAME){
                PYIMModeVideo *first = (PYIMModeVideo*)kVideo_Partion.mode;
                PYIMModeVideo *other = (PYIMModeVideo*)package.mode;
                if(first==nil){
                     kVideo_Partion = package;
                }else if(first.frameID==other.frameID){
                    [first appendPacket:other];
                }else {
                    NSLog(@"上一个分包未完成，收到了新的分包数据, finish:%@ frameID:%lld frameIDNew:%lld", first.isFinish?@"YES":@"NO", first.frameID, other.frameID);
                    kVideo_Partion = package;
                    return;
                }
                
                if(((PYIMModeVideo*)kVideo_Partion.mode).isFinish){
                    [_modeServer finished:[kVideo_Partion copy]];
                    kVideo_Partion = nil;
                }
            }else if(package.cmdID == C2C_CLOSE){
                [self manageOperationForChat:package];
                
            }else if(_modeServer){
                if(!kAccount.hadLogin){
                    NSLog(@"receive data but didn't login so ignored cmd:0x%04x host:%@ port:%d", package.cmdID, kAccount.rspIp, kAccount.rspPort);
                    return;
                }
                
                [_modeServer finished:package];
            }
        }
    }
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didNotSendDataWithTag:(long)tag dueToError:(NSError *)error {
    // 未发送成功
    [self udpSendHandle:tag error:error sock:sock];
}

- (void)udpSendHandle:(long)tag error:(NSError*)error sock:(GCDAsyncUdpSocket*)sock {
    //    NSLog(@"currentThread %@ result:%@", [NSThread currentThread], error.localizedDescription);
    PYIMOperation *opr = [self operationWithTag:tag];
    if(opr){
        if(error){
            NSLog(@"未发送成功:%d %@", self.port, error.localizedDescription);
        }
        
        // 注意：此处处理只需要关心发送完成的任务，发送完成就反馈到UI
        if(opr.mode.cmdID == C2S_LOGOUT){
            if(error==nil && self.sType==EServer_Login){
                self.modeLogin = nil;
                kAccount.chatState = 0;
                kAccount.chatSave = 0;
                
                //    pause_video();
                kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
                kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
                
                kAccount.myAccount = 0;
                kAccount.hadLogin = NO;
                
                kAccount.toAccount = 0;
                kAccount.toIp = @"";
                kAccount.toPort = 0;
                kAccount.toLocalIp = @"";
                kAccount.toLocalPort = 0;
                kAccount.toState = 0;
                
                kAccount.videoState = 0;
                kAccount.audioState = 0;
                kAccount.hadLoginVideo = NO;
                kAccount.hadLoginAudio = NO;
                
                kAccount.myIp = @"";
                kAccount.myPort = 0;
                kAccount.myLocalIp = @"";
                kAccount.myLocalPort = 0;
            }
            
            [sock pauseReceiving];
            [sock closeAfterSending];
            
            [opr operationFinishedWithErrorCode:error.code];
            
            NSLog(@"退出登录清理socket %@", self);
            
        }else if(!opr.mode.shouldRecResponse){
            [opr operationFinishedWithErrorCode:error.code];
        }
        
        [self manageOperationForChat:opr.mode.media];
    }
}

// ** 部分数据修改必须等到发送完成才能做
- (void)manageOperationForChat:(PYIMModeMedia*)media {
    if(media.cmdID == C2C_CLOSE ||
       media.cmdID == C2C_CANCEL_REQUEST) {
        kAccount.toAccount = 0;
        kAccount.toIp = nil;
        kAccount.toPort = 0;
        kAccount.toLocalIp = nil;
        kAccount.toLocalPort = 0;
        kAccount.toState = 0;
        
        [self.converterVideo dispose];
        [self.converter dispose];
        self.converterVideo = nil;
        self.converter = nil;
    }
}

#pragma mark heart

//待调试10001服务器重新登录问题
- (void)loginKeep {
    if(_modeLogin && !self.hadLogin){
        PYIMOperation *temp = [self operationWithSerialNum:_modeLogin.seqID];
        if(temp==nil){
            NSLog(@"重新登录:%d", _port);
            [_modeLogin.media prepareReSend];
            temp = [[PYIMOperation alloc] initWithMode:_modeLogin sock:_socket sockTcp:nil converter:_converter];
            [self addTaskToQueue:temp];
        }
    }
}

- (void)heartStateChanged {
    if(timerHeart){
        [timerHeart invalidate];
        timerHeart = nil;
    }
    
    if(self.hadLogin/* || self.modeLogin*/){
        timerHeart = [NSTimer timerWithTimeInterval:heartTimespan target:self selector:@selector(heartKeep) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timerHeart forMode:NSRunLoopCommonModes];
    }
}

- (void)heartKeep {
    // 注意这里是在主线程操作
    // 如果任务中没有心跳，触发新心跳
    PYIMOperation *opr = [self operationWithTag:_tagHeart];
    if(opr==nil){
        NSLog(@"开始心跳");
        [self createServerHeart];
    }
    
    // 清理任务超长时间任务（按理不可能存在，任务超时时间不会大于60秒，超时会自动返回释放）
    [self removeTasksWithAddr:0];
    
    // 这里对自己端网络进行判断，算1秒的数据量
    if(_queue.operationCount>10 && kAccount.chatState>0){
        // 正常是不可能达到这么多的，检查5次求平均值
        [[LDNetworkFlowTool sharedInstance] startWithTimes:5 flowBlock:^(float speed) {
            NSLog(@"通话中网络暂用情况 %.2f kb/s", speed);
            
            float slow = kAccount.chatType&P2P_CHAT_TYPE_MASK_VIDEO ? 30 : 10;
            if(speed<slow){
                dispatch_async(dispatch_get_main_queue(), ^{
                    PYNetworkSocketState quality = speed<(slow/2)?ENetworkQuality_slow_very:ENetworkQuality_slow;
                    BOOL local = YES;
                    
                    NSMutableString *desc = [NSMutableString string];
                    if(quality == ENetworkQuality_slow ||
                       quality == ENetworkQuality_slow_very){
                        [desc appendString:local?@"当前网络环境":@"对方网络环境"];
                        
                        [desc appendString:quality == ENetworkQuality_slow?@"较差":@"非常差"];
                    }
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationPY_NetworkStatusChanged
                                                                        object:@{@"status":@(quality),
                                                                                 @"server":@(self.sType),
                                                                                 @"local":@(YES),
                                                                                 @"desc":desc
                                                                                 }];
                });
            }
        }];
    }
}

/// encodeHeartBeat, c2c需要更多参数
- (void)createServerHeart {
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.cmdID = C2S_HEART_BEAT;
    //    media.sType = self.sType;
    
    CmdHeartBeat heart = {0};
    heart.account = htonll_x(kAccount.myAccount);
    if(kAccount.myLocalIp)
        memcpy(heart.localIp, [kAccount.myLocalIp UTF8String], strlen([kAccount.myLocalIp UTF8String]));
    else
        NSLog(@"未获取到本地iP");
    heart.localPort = htons_x(kAccount.myLocalPort);
    
    // ip,port 通过已连接的socket对象获取
    media.dataParam = [NSData dataWithBytes:&heart length:sizeof(CmdHeartBeat)];
    
    PYIMModeNetwork *netw = [[PYIMModeNetwork alloc] init];
    netw.media = media;
    
    _tagHeart = netw.tagSelf;
    [self addTask:netw];
}

// 客户端心跳
- (void)createC2CHeart {
    if(kAccount.srvState != 1 ||
       kAccount.toState != 1 ||
       kAccount.myAccount == 0 ||
       kAccount.toAccount == 0 ||
       kAccount.myIp == nil ||
       kAccount.myPort == 0 ||
       kAccount.myLocalIp == nil ||
       kAccount.myLocalPort == 0 ||
       kAccount.toIp == nil ||
       kAccount.toPort == 0 ||
       kAccount.toLocalIp == nil ||
       kAccount.toLocalPort == 0){
        NSLog(@"c2c心跳失败");
        return;
    }
    
    CmdC2CHeartBeat body = {0};
    body.account = htonll_x(kAccount.myAccount);
    memcpy(body.ip, [kAccount.myIp UTF8String], strlen([kAccount.myIp UTF8String]));
    body.port = htons_x(kAccount.myPort);
    memcpy(body.localIp, [kAccount.myLocalIp UTF8String], strlen([kAccount.myLocalIp UTF8String]));
    body.localPort = htons_x(kAccount.myLocalPort);
    body.toAccount = htonll_x(kAccount.toAccount);
    
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.cmdID = C2C_HEART_BEAT;
    
    media.dataParam = [NSData dataWithBytes:&body length:sizeof(CmdC2CHeartBeat)];
    PYIMModeNetwork *network = [[PYIMModeNetwork alloc] init];
    network.media = media;
    
    [self addTask:network];
}

- (void)heartResponse {
    // 从主线程发起任务，再分发到各个sock对应子线程队列
    //    dispatch_async(dispatch_get_main_queue(), ^{
    CmdC2CHeartBeatRsp body = {0};
    body.account = htonll_x(kAccount.myAccount);
    memcpy(body.ip, [kAccount.myIp UTF8String], strlen([kAccount.myIp UTF8String]));
    body.port = htons_x(kAccount.myPort);
    memcpy(body.localIp, [kAccount.myLocalIp UTF8String], strlen([kAccount.myLocalIp UTF8String]));
    body.localPort = htons_x(kAccount.myLocalPort);
    body.toAccount = htonll_x(kAccount.toAccount);
    
    PYIMModeMedia *media = [[PYIMModeMedia alloc] init];
    media.cmdID = C2C_HEART_BEAT_RSP;
    
    media.dataParam = [NSData dataWithBytes:&body length:sizeof(CmdC2CHeartBeatRsp)];
    PYIMModeNetwork *network = [[PYIMModeNetwork alloc] init];
    network.media = media;
    
    [[PYIMNetworkManager sharedInstance] addTask:network];
    //    });
}

// 设置任务发送端口ip（部分任务需要）
- (void)setTaskSendIpPort:(PYIMModeNetwork*)task {
    int ret = 0;
    if ([kAccount.myIp isEqualToString:kAccount.toIp])
    {
        task.hostServer = kAccount.toLocalIp;
        task.portServer = kAccount.toLocalPort;
        ret = 1;
    }
    else
    {
        task.hostServer = kAccount.toIp;
        task.portServer = kAccount.toPort;
        ret = 2;
    }
    
    NSLog(@"c2cGetIpAndPort ip:%@, port:%u, ret:%d", task.hostServer, task.portServer, ret);
}

#pragma mark static methods

+ (void)applicationDidEnterBackground {
    [[self sharedInstance] pauseManager];
}

+ (void)applicationWillEnterForeground {
    [[self sharedInstance] resumeManager];
}

+ (void)connectWithHost:(NSString*)host port:(ushort)port {
    [[self sharedInstance] connectWithHost:host port:port];
    [[self sharedInstance] connectAudioWithHost:host port:port+1];
    //    [[self sharedInstance] connectVideoWithHost:host port:port+2];
}

+ (void)addTask:(PYIMModeNetwork *)task {
    [[self sharedInstance] addTask:task];
}

+ (void)removeTasksWithAddr:(long)addr {
    [[self sharedInstance] removeTasksWithAddr:addr];
}

+ (void)cancelTask:(NSArray*)tasks {
    if(tasks.count>0)
        [[self sharedInstance] cancelTask:tasks];
}

@end

