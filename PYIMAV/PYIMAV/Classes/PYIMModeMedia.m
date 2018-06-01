
//  PYIMModeMedia.m
//  PYIMAV
//
//  Created by Bob Lee on 2018/4/26.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYIMModeMedia.h"
#import "PYIMAccount.h"
#import "pdu.h"
#import "adpcm.h"
#import "c2c.h"
#import "c2s.h"

#import "PYIMAudioConverter.h"
#import "PYIMVideoConverter.h"

#import "PYIMNetworkManager.h"

ushort const kCMD_Re_ServerMsg = 0x8500;             ///< 0x8500 服务器发出消息

@interface PYIMError () {}

- (void)copySeqID:(uint16_t)seqID;

@end

@implementation PYIMError

static uint16_t SerialNumber = 0;

- (instancetype)init {
    self = [super init];
    if(self) {
        SerialNumber ++;
        //        _sender = kAppDelegate.account.accountCode;
        
        // 防止溢出
        if(SerialNumber>65534){
            SerialNumber = 0;
        }
        
        _seqID = SerialNumber;
        _cmdStatus = C2S_ERR_OK;
    }
    
    return self;
}

- (instancetype)initWithData:(NSData*)data converter:(id)converter {
    self = [super init];
    if(self) {
        // 记录数据来源
        self.rspIP = kAccount.rspIp;
        self.rspPort = kAccount.rspPort;
        
        // 解析消息体
        Byte *buf = (Byte*)data.bytes;
        
        // 只读取header
        Header *pheader = (Header *)buf;
        _totalLen = ntohs_x(pheader->TotalLen);
        _cmdID = ntohs_x(pheader->CmdId);
        _seqID = ntohs_x(pheader->SeqId);
        _cmdStatus = ntohs_x(pheader->CmdStatus);
//        _client = ntohs_x(pheader->Client);
    }
    
    return self;
}

- (instancetype)initWithError:(NSString*)desc {
    self = [super init];
    if(self) {
        _errDesc = desc;
    }
    
    return self;
}

- (instancetype)initWithCmd:(uint16_t)cmd status:(uint16_t)status {
    self = [super init];
    if(self) {
        _cmdID = cmd;
        _cmdStatus = status;
    }
    
    return self;
}

- (BOOL)success {
    return self.errDesc == nil;
}

- (instancetype)initWithCmd:(uint16_t)cmd errDesc:(NSString*)errDesc {
    self = [super init];
    if(self) {
        _cmdID = cmd;
        _errDesc = errDesc;
    }
    
    return self;
}

- (NSString*)errDesc {
    if(_errDesc == nil){
        switch (_cmdStatus) {
            case C2S_ERR_OK: {  } break;
            case C2S_ERR_INVALID_ACCOUNT: { _errDesc = @"账号不存在或未知错误"; } break;
            case C2S_ERR_INVALID_PASSWORD: { _errDesc = @"密码错误"; } break;
            case C2S_ERR_OFFLINE: { _errDesc = @"对方已下线"; } break;
            case C2S_ERR_NOTLOGIN: { _errDesc = @"请先登录"; } break;
                
            case C2C_ERR_Disconnect: { _errDesc = @"未连接到任何C端"; } break;
            case C2S_ERR_Disconnect: { _errDesc = @"未连接到服务器"; } break;
                
            case C2S_ERR_Data: { _errDesc = @"接收到错误数据无法解析"; } break;
            case C2S_ERR_NotMyData: { _errDesc = @"接收到不属于我的数据"; } break;
                
            case C2C_ERR_VideoSliceSize: { _errDesc = @"视频分片大小不正确"; } break;
            case C2C_ERR_VideoSizeOverflow: { _errDesc = @"视频过大溢出"; } break;
            case C2C_ERR_VideoFrameSize: { _errDesc = @"视频帧大小不正确"; } break;
                
            case C2C_ERR_ExistDisconnect: { _errDesc = @"已经存在一个正常通话连接，新来的链接要丢掉"; } break;
                
            default:
                break;
        }
    }
    
    if(_errDesc){
        NSLog(@"cmd:%04x %@", self.cmdID, _errDesc);
    }
    
    return _errDesc;
}

- (PYServerType)sType {
    if(_sType>EServer_None)
        return _sType;
    
    switch (_cmdID) {
        case C2C_AUDIO_FRAME: {
            if(kAccount.srvState==1 && kAccount.toState == 1 && kAccount.isTcp == 0) { return EServer_Login; }
            else if(kAccount.audioState == 1) { return EServer_Audio; }
            
        } break;
            
        case C2C_VIDEO_FRAME:
        case C2C_VIDEO_FRAME_EX: {
            if(kAccount.srvState==1 && kAccount.toState == 1 && kAccount.isTcp == 0) { return EServer_Login; }
            else if(kAccount.videoState == 1) { return EServer_Video; }
            
        } break;
            
        default:
            return EServer_Login;
    }
    
    return EServer_Login;
}

- (id)copyWithZone:(NSZone *)zone {
    PYIMError *mode = [[[self class] alloc] init];
    mode.dataMedia = _dataMedia;
    mode.dataParam = _dataParam;
    mode.totalLen = _totalLen;
    mode.cmdID = _cmdID;
    mode.cmdStatus = _cmdStatus;
    mode.rspIP = _rspIP;
    mode.rspPort = _rspPort;
    if(_mode)
        mode.mode = [_mode copy];
//    [mode copySeqID:_seqID];
    
    return mode;
}

- (void)copySeqID:(uint16_t)seqID {
    _seqID = seqID;
}

@end

@interface PYIMModeMedia() {
    NSData *dataSend;
    //    audio_process_handle_t g_audio_process_handle;
    
    adpcm_state encode_state;
    adpcm_state decode_state;
}

@property (nonatomic, weak) PYIMAudioConverter *audioConv; ///< 语音转换器
@property (nonatomic, weak) PYIMVideoConverter *videoConv; ///< 视频转换器


@end

@implementation PYIMModeMedia

static NSInteger kTimeout = 10; // 秒

- (instancetype)init {
    self = [super init];
    if(self){
        _resentCount = 0;
        _createdTime = [[NSDate date] timeIntervalSince1970]*1000;
    }
    
    return self;
}

- (instancetype)initWithData:(NSData *)data converter:(id)converter{
    self = [super initWithData:data converter:converter];
    if(self){
        if(self.success && (self.cmdID == C2S_LOGIN_RSP || kAccount.hadLogin)){
            if([converter isKindOfClass:[PYIMVideoConverter class]])
                self.videoConv = converter;
            else
                self.audioConv = converter;
            
            [self parseData:data];
            
//            int datalen = [self parseData:data];
            // 获得param数据，有必要在放开
//            if(datalen>0){
//                self.dataParam = [data subdataWithRange:NSMakeRange(sizeof(Header), data.length-sizeof(Header)-datalen)];
//            }
        }
    }
    
    return self;
}

- (BOOL)isSendBySelf {
    return _sender == kAccount.myAccount;
}

- (NSInteger)timeOutSpan {
    return kTimeout;
}

- (BOOL)timeOut {
    if(_createdTime==0)return NO;
    
    int timeNew = [[NSDate date] timeIntervalSince1970];
    return (timeNew-_createdTime/1000)>kTimeout;
}

- (int)parseData:(NSData*)data {
    switch (self.cmdID) {
            // c2s
        case C2S_HEART_BEAT_RSP: {  return [self parseHeartResp:data]; }
        case C2S_LOGIN: {           return [self parseLogin:data]; }
        case C2S_LOGIN_RSP: {       return [self parseLoginResp:data]; }
        case C2S_LOGOUT: {          return [self parseLogout:data]; }
        case C2S_HOLE: {            return [self parseHole:data]; }
        case C2S_HOLE_RSP: {        return [self parseHoleResp:data]; }
        case C2S_HOLE_NOTIFY: {     return [self parseHoleNotify:data]; }
            
            
            // c2c
        case C2C_HOLE: {            return [self parseC2CHole:data]; }
        case C2C_HOLE_RSP: {        return [self parseC2CHoleResp:data]; }
        case C2C_REQUEST: {         return [self parseC2CRequest:data]; }
        case C2C_REQUEST_RSP: {     return [self parseC2CRequestResp:data]; }
        case C2C_CANCEL_REQUEST: {  return [self parseC2CRequestCancel:data]; }
        case C2C_CLOSE: {           return [self parseC2CClose:data]; }
        case C2C_PAUSE: {           return [self parseC2CPause:data]; }
        case C2C_RESUME: {          return [self parseC2CResume:data]; }
        case C2C_SWITCH: {          return [self parseC2CSwitch:data]; }
        case C2C_VIDEO_FRAME: {     return [self parseC2CVideo:data]; }
        case C2C_VIDEO_FRAME_EX: {  return [self parseC2CVideoEx:data]; }
        case C2C_AUDIO_FRAME: {     return [self parseC2CAudio:data]; }
        case C2C_TEXT_FRAME: {      return [self parseC2CText:data]; }
        case C2C_FILE_FRAME: {      return [self parseC2CFile:data]; }
        case C2C_FILE_FRAME_RSP: {  return [self parseC2CFileResp:data]; }
        case C2C_HEART_BEAT: {      return [self parseC2CHeart:data]; }
        case C2C_HEART_BEAT_RSP: {  return [self parseC2CHeartResp:data]; }
        case C2C_LARGE: {           return [self parseC2CLarge:data]; }
        case C2C_LARGE_RSP: {       return [self parseC2CLargeResp:data]; }
            
        default:
            break;
    }
    
    return 0;
}

#pragma mark - c2s

// 心跳反馈（几个服务器都一样的数据）
- (int)parseHeartResp:(NSData*)data {
    if(kAccount.myAccount==0){
        NSLog(@"onC2SHeartBeatRsp|invalid myAccount");
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    Header header;
    CmdHeartBeatRsp rsp;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    int ret = decodeHeartBeatRsp(recvBuf, recvLen, &header, &rsp);
    
    if (ret != 0)
    {
        NSLog(@"onC2SHeartBeatRsp|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (rsp.account != kAccount.myAccount)
    {
        NSLog(@"onC2SHeartBeatRsp|invalid account:%lld, myAccount:%lld", rsp.account, kAccount.myAccount);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    NSString *rspIp = [NSString stringWithUTF8String:rsp.ip];
    
    if(![kAccount.myIp isEqualToString:rspIp] || kAccount.myPort != rsp.port){
        kAccount.myIp = rspIp;
        kAccount.myPort = rsp.port;
    }
    
    rspIp = [NSString stringWithUTF8String:rsp.localIp];
    
    if(![kAccount.myLocalIp isEqualToString:rspIp] || kAccount.myLocalPort != rsp.localPort){
        kAccount.myLocalIp = rspIp;
        kAccount.myLocalPort = rsp.localPort;
    }
    
    kAccount.srvState = 1;
    
    return 0;
}

- (int)parseLogin:(NSData*)data {
    return 0;
}

// 登录反馈
- (int)parseLoginResp:(NSData*)data {
    if(kAccount.myAccount==0){
        NSLog(@"onC2SLoginRsp|invalid myAccount");
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    // 参考jni工程解析
    Header header;
    CmdLoginRsp rsp;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    int ret = decodeLoginRsp(recvBuf, recvLen, &header, &rsp);
    
    if(ret!=0){
        NSLog(@"onC2SLoginRsp|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if(rsp.account != kAccount.myAccount){
        NSLog(@"invalid account:%lld, myAccount:%lld", rsp.account, kAccount.myAccount);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    kAccount.myIp = [NSString stringWithUTF8String:rsp.ip];
    kAccount.myPort = rsp.port;
    kAccount.srvState = 1;
    
    // 立刻发送一次心跳
//    c2sInnerHeartBeat(p);
    return 0;
}

- (int)parseLogout:(NSData*)data {
    return 0;
}

// c2sHole
- (int)parseHole:(NSData*)data {
    Header header;
    CmdHole req;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    int ret = decodeHole(recvBuf, recvLen, &header, &req);
    if (ret != 0)
    {
        NSLog(@"onC2CHole|decode fail");
        return -1;
    }
    
    return 0;
}

// 获取连接账号反馈
- (int)parseHoleResp:(NSData*)data {
    if (kAccount.myAccount == 0)
    {
        NSLog(@"onC2SGetAccountRsp|invalid myAccount");
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    if(kAccount.toAccount==0) {
        NSLog(@"onC2SGetAccountRsp|invalid toAccount");
        self.cmdStatus = C2C_ERR_Disconnect;
        return -1;
    }
    
    Header header;
    CmdC2SHoleRsp rsp;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    int ret = decodeC2SHoleRsp(recvBuf, recvLen, &header, &rsp);
    if (ret != 0)
    {
        NSLog(@"onC2SGetAccountRsp|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (rsp.account != kAccount.myAccount)
    {
        NSLog(@"onC2SGetAccountRsp|invalid rsp.account:%lld, myAccount:%lld", rsp.account, kAccount.myAccount);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    if (rsp.toAccount != kAccount.toAccount)
    {
        NSLog(@"onC2SGetAccountRsp|invalid rsp.toAccount:%lld, toAccount:%lld", rsp.toAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    NSString *rspIp = [NSString stringWithUTF8String:rsp.ip];
    if (![kAccount.myIp isEqualToString:rspIp])
    {
        kAccount.myIp = rspIp;
    }
    
    if (kAccount.myPort != rsp.port)
    {
        kAccount.myPort = rsp.port;
    }
    
    rspIp = [NSString stringWithUTF8String:rsp.localIp];
    if (rspIp && ![kAccount.myLocalIp isEqualToString:rspIp])
    {
        kAccount.myLocalIp = rspIp;
    }
    if (kAccount.myLocalPort != rsp.localPort)
    {
        kAccount.myLocalPort = rsp.localPort;
    }
    
    kAccount.toIp = [NSString stringWithUTF8String:rsp.toIp];
    kAccount.toPort = rsp.toPort;
    
    kAccount.toLocalIp = [NSString stringWithUTF8String:rsp.toLocalIp];
    kAccount.toLocalPort = rsp.toLocalPort;
    
    NSLog(@"onC2SGetAccountRsp|fromip:%@, fromport:%u|myAccount:%lld, toAccount:%lld, myIp:%@, myPort:%u, myLocalIp:%@, myLocalPort:%u, toIp:%@, toPort:%u, toLocalIp:%@, toLocalPort:%u", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, kAccount.toAccount, kAccount.myIp, kAccount.myPort, kAccount.myLocalIp, kAccount.myLocalPort, kAccount.toIp, kAccount.toPort, kAccount.toLocalIp, kAccount.toLocalPort);
    
    // 注意在API层还要处理这些方法
//    c2cInnerHole(p);
//    usleep(10000);
//    c2cInnerRequest(p);
    return 0;
}

// 收到别人请求账号信息
- (int)parseHoleNotify:(NSData*)data {
    if (kAccount.myAccount == 0)
    {
        NSLog(@"onC2SGetAccountNotify|invalid myAccount");
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    Header header;
    CmdC2SHoleNotify rsp;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    int ret = decodeC2SHoleNotify(recvBuf, recvLen, &header, &rsp);
    if (ret != 0)
    {
        NSLog(@"onC2SGetAccountNotify|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (rsp.toAccount != kAccount.myAccount)
    {
        NSLog(@"onC2SGetAccountNotify|fromip:%@, fromport:%u|myAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, rsp.toAccount);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    if (rsp.account == 0)
    {
        NSLog(@"onC2SGetAccountNotify|invalid account");
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    if (kAccount.chatState != 0)
    {
        NSLog(@"onC2SGetAccountNotify|chatState, toAccount:%lld, account:%lld", kAccount.toAccount, rsp.account);
        self.cmdStatus = C2C_ERR_ExistDisconnect;
        return -1;
    }
    
//    pause_video();
    kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
    kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
    
    kAccount.toAccount = rsp.account;
    kAccount.toIp = [NSString stringWithUTF8String:rsp.ip];
    kAccount.toPort = rsp.port;
    
    kAccount.toLocalIp = [NSString stringWithUTF8String:rsp.localIp];
    kAccount.toLocalPort = rsp.localPort;
    
    NSString *rspIp = [NSString stringWithUTF8String:rsp.toIp];
    if (![kAccount.myIp isEqualToString:rspIp])
    {
        kAccount.myIp = rspIp;
    }
    if (kAccount.myPort != rsp.toPort)
    {
        kAccount.myPort = rsp.toPort;
    }
    
    rspIp = [NSString stringWithUTF8String:rsp.toLocalIp];
    if (rspIp && ![kAccount.myLocalIp isEqualToString:rspIp])
    {
        kAccount.myLocalIp = rspIp;
    }
    if (kAccount.myLocalPort != rsp.toLocalPort)
    {
        kAccount.myLocalPort = rsp.toLocalPort;
    }
    
    NSLog(@"onC2SGetAccountNotify|fromip:%@, fromport:%u|myAccount:%lld, toAccount:%lld, myIp:%@, myPort:%u, myLocalIp:%@, myLocalPort:%u, toIp:%@, toPort:%u, toLocalIp:%@, toLocalPort:%u", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, kAccount.toAccount, kAccount.myIp, kAccount.myPort, kAccount.myLocalIp, kAccount.myLocalPort, kAccount.toIp, kAccount.toPort, kAccount.toLocalIp, kAccount.toLocalPort);
    
//    c2cInnerHole(p);
    return 0;
}

#pragma mark - c2c

// 收到打洞信息；立刻回复
- (int)parseC2CHole:(NSData*)data {
    if(kAccount.myAccount == 0 || kAccount.toAccount == 0) {
        NSLog(@"onC2CHole|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    Header header;
    CmdHole req;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    int ret = decodeHole(recvBuf, recvLen, &header, &req);
    if (ret != 0) {
        NSLog(@"onC2CHole|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (req.toAccount != kAccount.myAccount || req.account != kAccount.toAccount) {
        NSLog(@"onC2CHole|fromip:%@, fromport:%u|invalid account. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, req.toAccount, kAccount.toAccount, req.account);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    [self c2cSetIpAndPort];
    // 收到后要立刻调用holersp返回
    
    kAccount.toState = 1;
    return 0;
}

// 收到回复打洞消息
- (int)parseC2CHoleResp:(NSData*)data {
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0) {
        NSLog(@"onC2CRequestRsp|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    Header header;
    CmdHoleRsp rsp;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    int ret = decodeHoleRsp(recvBuf, recvLen, &header, &rsp);
    if (ret != 0)
    {
        NSLog(@"onC2CHoleRsp|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (rsp.toAccount != kAccount.myAccount || rsp.account != kAccount.toAccount)
    {
        NSLog(@"onC2CHoleRsp fail|fromip:%@, fromport:%u|invalid account. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, rsp.toAccount, kAccount.toAccount, rsp.account);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }

    [self c2cSetIpAndPort];
    
    kAccount.toState = 1;
    return 0;
}

// 请求连接，如果已经在通话中将丢弃；否则立刻发送打洞消息，界面提示是否允许连接
- (int)parseC2CRequest:(NSData*)data {
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0)
    {
        NSLog(@"onC2CRequest|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    Header header;
    CmdRequest req;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    int ret = decodeRequest(recvBuf, recvLen, &header, &req);
    if (ret != 0)
    {
        NSLog(@"onC2CRequest|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (req.toAccount != kAccount.myAccount || req.account != kAccount.toAccount)
    {
        NSLog(@"onC2CRequest|fromip:%@, fromport:%u|invalid account. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, req.toAccount, kAccount.toAccount, req.account);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    NSLog(@"onC2CRequest|fromip:%@, fromport:%u|myAccount:%lld, myIp:%@, myPort:%u, toAccount:%lld, toIp:%@, toPort:%u,type:%d", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, kAccount.myIp, kAccount.myPort, kAccount.toAccount, kAccount.toIp, kAccount.toPort, req.type);
    
//    c2cInnerHole(p);
    
    kAccount.chatSave = req.type;
    
    return 0;
}

// 自己请求链接回复处理
- (int)parseC2CRequestResp:(NSData*)data {
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0) {
        NSLog(@"onC2CRequestRsp|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    Header header;
    CmdRequestRsp rsp;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    int ret = decodeRequestRsp(recvBuf, recvLen, &header, &rsp);
    if (ret != 0) {
        NSLog(@"onC2CRequestRsp|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (rsp.toAccount != kAccount.myAccount || rsp.account != kAccount.toAccount)
    {
        NSLog(@"onC2CRequestRsp|fromip:%@, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, rsp.toAccount, kAccount.toAccount, rsp.account);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    if (rsp.accept == 0)
    {
        // 接受
        NSLog(@"onC2CRequestRsp|fromip:%@, fromport:%u|accept,type:%d,myAccount:%lld, myIp:%@, myPort:%u, toAccount:%lld, toIp:%@, toPort:%u, type:%u", kAccount.rspIp, kAccount.rspPort, rsp.type, kAccount.myAccount, kAccount.myIp, kAccount.myPort, kAccount.toAccount, kAccount.toIp, kAccount.toPort, rsp.type);
        
//        c2cInnerHole(p);
        
        if (rsp.type == P2P_CHAT_TYPE_VIDEO)
        {
            kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_VIDEO);
            kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_AUDIO);
//            resume_video();
        }
        else if (rsp.type == P2P_CHAT_TYPE_AUDIO)
        {
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
            kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_AUDIO);
//            pause_video();
        }
        else if (rsp.type == P2P_CHAT_TYPE_FILE)
        {
            kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_FILE);
        }
        
        kAccount.chatState = 1;
        kAccount.chatLastTime = time(NULL);
    }
    else
    {
        NSLog(@"onC2CRequestRsp|fromip:%@, fromport:%u|reject,type:%d myAccount:%lld, myIp:%@, myPort:%u, toAccount:%lld, toIp:%@, toPort:%u, type:%u", kAccount.rspIp, kAccount.rspPort, rsp.type, kAccount.myAccount, kAccount.myIp, kAccount.myPort, kAccount.toAccount, kAccount.toIp, kAccount.toPort, rsp.type);
        
        if (rsp.type == P2P_CHAT_TYPE_VIDEO)
        {
//            pause_video();
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
        }
        else if (rsp.type == P2P_CHAT_TYPE_AUDIO)
        {
//            pause_video();
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
        }
        else if (rsp.type == P2P_CHAT_TYPE_FILE)
        {
            kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_FILE);
        }
    }
    
    return 0;
}

// 取消连接请求
- (int)parseC2CRequestCancel:(NSData*)data {
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0)
    {
        NSLog(@"onC2CCancleRequest|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    Header header;
    CmdCancelRequest req;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    int ret = decodeCancelRequest(recvBuf, recvLen, &header, &req);
    if (ret != 0)
    {
        NSLog(@"onC2CCancleRequest|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (req.toAccount != kAccount.myAccount || req.account != kAccount.toAccount)
    {
        NSLog(@"onC2CCancleRequest fail|fromip:%@, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, req.toAccount, kAccount.toAccount, req.account);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    kAccount.chatState = 0;
    
    NSLog(@"onC2CCancleRequest|fromip:%@, fromport:%u|myAccount:%lld, myIp:%@, myPort:%u, toAccount:%lld, toIp:%@, toPort:%u, type:%u", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, kAccount.myIp, kAccount.myPort, kAccount.toAccount, kAccount.toIp, kAccount.toPort, req.type);
    
    if (req.type == P2P_CHAT_TYPE_VIDEO)
    {
//        pause_video();
        kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
        kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
    }
    else if (req.type == P2P_CHAT_TYPE_AUDIO)
    {
//        pause_video();
        kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
        kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
    }
    else if (req.type == P2P_CHAT_TYPE_FILE)
    {
        kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_FILE);
    }
    
    return 0;
}

// 关闭通话
- (int)parseC2CClose:(NSData*)data {
    kAccount.chatState = 0;
    
//    pause_video();
    kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
    kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
    
    kAccount.toAccount = 0;
    kAccount.toIp = nil;
    kAccount.toPort = 0;
    kAccount.toLocalIp = nil;
    kAccount.toLocalPort = 0;
    kAccount.toState = 0;
    
    NSLog(@"onC2CClose|fromip:%@, fromport:%u|myAccount:%lld, myIp:%@, myPort:%u", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, kAccount.myIp, kAccount.myPort);
    
    return 0;
}

// 暂停通话 - 目前看没有必要
- (int)parseC2CPause:(NSData*)data {
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0)
    {
        NSLog(@"onC2CPause|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    Header header;
    CmdPause req;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    int ret = decodePause(recvBuf, recvLen, &header, &req);
    if (ret != 0)
    {
        NSLog(@"onC2CPause|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (req.toAccount != kAccount.myAccount || req.account != kAccount.toAccount)
    {
        NSLog(@"onC2CPause|fromip:%@, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, req.toAccount, kAccount.toAccount, req.account);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    NSLog(@"onC2CPause|fromip:%@, fromport:%u|myAccount:%lld, myIp:%@, myPort:%u, toAccount:%lld, toIp:%@, toPort:%u, type:%u", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, kAccount.myIp, kAccount.myPort, kAccount.toAccount, kAccount.toIp, kAccount.toPort, req.type);
    
    if (req.type == P2P_CHAT_TYPE_VIDEO)
    {
//        pause_video();
        kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
    }
    
    return 0;
}

// 恢复通话
- (int)parseC2CResume:(NSData*)data {
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0)
    {
        NSLog(@"onC2CResume|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    Header header;
    CmdResume req;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    int ret = decodeResume(recvBuf, recvLen, &header, &req);
    if (ret != 0)
    {
        NSLog(@"onC2CResume|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (req.toAccount != kAccount.myAccount || req.account != kAccount.toAccount)
    {
        NSLog(@"onC2CResume|fromip:%@, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, req.toAccount, kAccount.toAccount, req.account);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    NSLog(@"onC2CResume|fromip:%@, fromport:%u|myAccount:%lld, myIp:%@, myPort:%u, toAccount:%lld, toIp:%@, toPort:%u, type:%u", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, kAccount.myIp, kAccount.myPort, kAccount.toAccount, kAccount.toIp, kAccount.toPort, req.type);
    
    if (req.type == P2P_CHAT_TYPE_VIDEO)
    {
        kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_VIDEO);
        kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_AUDIO);
//        resume_video();
    }
    else if (req.type == P2P_CHAT_TYPE_AUDIO)
    {
        kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_AUDIO);
    }
    
    return 0;
}

// 视频语音切换
- (int)parseC2CSwitch:(NSData*)data {
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0)
    {
        NSLog(@"onC2CSwitch|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    Header header;
    CmdSwitch req;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    int ret = decodeSwitch(recvBuf, recvLen, &header, &req);
    if (ret != 0)
    {
        NSLog(@"onC2CSwitch|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (req.toAccount != kAccount.myAccount || req.account != kAccount.toAccount)
    {
        NSLog(@"onC2CSwitch|fromip:%@, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, req.toAccount, kAccount.toAccount, req.account);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    NSLog(@"onC2CSwitch|fromip:%@, fromport:%u|myAccount:%lld, myIp:%@, myPort:%u, toAccount:%lld, toIp:%@, toPort:%u, type:%u", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, kAccount.myIp, kAccount.myPort, kAccount.toAccount, kAccount.toIp, kAccount.toPort, req.type);
    
    if (req.type == P2P_CHAT_TYPE_VIDEO)
    {
        kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_VIDEO);
        kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_AUDIO);
//        resume_video();
    }
    else if (req.type == P2P_CHAT_TYPE_AUDIO)
    {
        kAccount.chatType = kAccount.chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
        kAccount.chatType = kAccount.chatType | (1 << P2P_CHAT_TYPE_AUDIO);
//        pause_video();
    }
    
    return 0;
}

// 接收到视频数据
- (int)parseC2CVideo:(NSData*)data {
    kAccount.chatLastTime = time(NULL);
    
    if (kAccount.chatState != 1)
    {
        NSLog(@"onC2CVideoFrame|not chatState");
        self.cmdStatus = C2C_ERR_Disconnect;
        return -1;
    }
    
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0)
    {
        NSLog(@"onC2CVideoFrame|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    if (!(kAccount.chatType & P2P_CHAT_TYPE_MASK_VIDEO))
    {
        NSLog(@"onC2CVideoFrame|not video state");
        self.cmdStatus = C2C_ERR_Disconnect;
        kAccount.frameID = 0;
        kAccount.videoLen = 0;
        return -1;
    }
    
    Header header;
    CmdVideoFrame req;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    uint16_t swapLen = P2P_MAX_BUF_SIZE;
    uint8_t swapBuf[P2P_MAX_BUF_SIZE];        // 交换缓冲区
    int ret = decodeVideoFrame(recvBuf, recvLen, &header, &req, swapBuf, &swapLen);
    if (ret != 0)
    {
        NSLog(@"onC2CVideoFrame|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        kAccount.frameID = 0;
        kAccount.videoLen = 0;
        return -1;
    }
    
    if (req.toAccount != kAccount.myAccount || req.account != kAccount.toAccount)
    {
        NSLog(@"onC2CVideoFrame|fromip:%@, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, req.toAccount, kAccount.toAccount, req.account);
        kAccount.frameID = 0;
        kAccount.videoLen = 0;
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    int packs = req.packs;
    int pid = req.pid;
    int fLen = req.frameLen;
    int packLen = req.packLen;
    
    if (packLen > P2P_VIDEO_SLICE_SIZE)
    {
        NSLog(@"onC2CVideoFrame|invalid. frameId:%llu, packNum:%d, packId:%d, packLen:%d, frameLen:%d", req.frameID, packs, pid, packLen, fLen);
        kAccount.frameID = 0;
        kAccount.videoLen = 0;
        self.cmdStatus = C2C_ERR_VideoSliceSize;
        return -1;
    }
    
//    if (kAccount.frameID == req.frameID)
//    {
//        kAccount.videoLen += packLen;
//    }
//    else
//    {
//        kAccount.frameID = req.frameID;
//        kAccount.videoLen = packLen;
//    }
    
    if ((int) (pid * P2P_VIDEO_SLICE_SIZE + packLen) > (int) (P2P_MAX_BUF_SIZE))
    {
        NSLog(@"onC2CVideoFrame|too long. fid:%llu,packs:%d, pid:%d, len:%d,packLen:%d", req.frameID, packs, pid, fLen, packLen);
        kAccount.frameID = 0;
        kAccount.videoLen = 0;
        self.cmdStatus = C2C_ERR_VideoSizeOverflow;
        return -1;
    }
    
    if (fLen < 0 || fLen > (int) (P2P_MAX_BUF_SIZE))
    {
        NSLog(@"onC2CVideoFrame|invalid fLen:%d", fLen);
        kAccount.frameID = 0;
        kAccount.videoLen = 0;
        self.cmdStatus = C2C_ERR_VideoFrameSize;
        return -1;
    }
//    else if (fLen > kAccount.videoLen)
//    {
//        NSLog(@"onC2CVideoFrame|fromip:%@, fromport:%u|frameId:[%llu, %llu], packNum:%d, packId:%d, packLen:%d, frameLen:%d, videoLen:%d|not enough", kAccount.rspIp, kAccount.rspPort, kAccount.frameID, req.frameID, packs, pid, packLen, fLen, kAccount.videoLen);
//        self.cmdStatus = C2C_ERR_VideoFrameSize;
//        return -1;
//    }
//    else if (fLen < kAccount.videoLen)
//    {
//        NSLog(@"onC2CVideoFrame|fromip:%@, fromport:%u|frameId:[%llu, %llu], packNum:%d, packId:%d, packLen:%d, frameLen:%d, videoLen:%d|ignore", kAccount.rspIp, kAccount.rspPort, kAccount.frameID, req.frameID, packs, pid, packLen, fLen, kAccount.videoLen);
//        kAccount.frameID = 0;
//        kAccount.videoLen = 0;
//        self.cmdStatus = C2C_ERR_VideoFrameSize;
//        return -1;
//    }
    
    // 视频需要数据模型支持相关参数
    self.mode = [[PYIMModeVideo alloc] initWithData:data converter:self.videoConv];
    
    return swapLen;
}

// 接收到视频数据Ex
- (int)parseC2CVideoEx:(NSData*)data {
    kAccount.chatLastTime = time(NULL);
    
    if (kAccount.chatState != 1)
    {
        NSLog(@"onC2CVideoFrameEx|not chatState");
        self.cmdStatus = C2C_ERR_Disconnect;
        return -1;
    }
    
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0)
    {
        NSLog(@"onC2CVideoFrameEx|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    if (!(kAccount.chatType & P2P_CHAT_TYPE_MASK_VIDEO))
    {
        NSLog(@"onC2CVideoFrameEx|not video state");
        self.cmdStatus = C2C_ERR_Disconnect;
        return -1;
    }
    
    Header header;
    CmdVideoFrameEx req;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    uint16_t swapLen = P2P_MAX_BUF_SIZE;
    uint8_t swapBuf[P2P_MAX_BUF_SIZE];        // 交换缓冲区
    int ret = decodeVideoFrameEx(recvBuf, recvLen, &header, &req, swapBuf, &swapLen);
    if (ret != 0)
    {
        NSLog(@"onC2CVideoFrameEx|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (req.toAccount != kAccount.myAccount || req.account != kAccount.toAccount)
    {
        NSLog(@"onC2CVideoFrameEx|fromip:%@, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, req.toAccount, kAccount.toAccount, req.account);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    // 视频需要数据模型支持相关参数
    self.mode = [[PYIMModeVideo alloc] initWithDataEx:data converter:self.videoConv];
    
    if(self.mode.media==nil) {
        NSLog(@"receive data error datasize:%ti seqID:%d", self.mode.media.length, self.seqID);
    }
    
    return swapLen;
}

// 接收到语音数据
- (int)parseC2CAudio:(NSData*)data {
    // 参考jni工程解析
    Header header;
    CmdAudioFrame req;
    uint16_t swapLen = P2P_MAX_BUF_SIZE;
    uint8_t swapBuf[P2P_MAX_BUF_SIZE];        // 交换缓冲区
    uint16_t recvLen = data.length;
    
    // 解析消息体
    Byte *recvBuf = (Byte*)data.bytes;
    int ret = decodeAudioFrame(recvBuf, recvLen, &header, &req, swapBuf, &swapLen);
    
    if (ret != 0)
    {
        NSLog(@"onC2CAudioFrame|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (req.toAccount != kAccount.myAccount || req.account != kAccount.toAccount)
    {
        NSLog(@"onC2CAudioFrame|fromip:%@, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, req.toAccount, kAccount.toAccount, req.account);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    self.sender = req.account;
    self.reciver = req.toAccount;
    
    // TODO:后面将解压放到这里处理
    if(swapLen != AUDIO_FRAMES/2){
        NSLog(@"onC2CAudioFrame|收到语音数据长度:%d", swapLen);
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    self.mode = [[PYIMModeAudio alloc] initWithData:data converter:self.audioConv];
    
    return swapLen;
}

- (int)parseC2CText:(NSData*)data {
    return 0;
}

- (int)parseC2CFile:(NSData*)data {
    return 0;
}

- (int)parseC2CFileResp:(NSData*)data {
    return 0;
}

// 客户端心跳
- (int)parseC2CHeart:(NSData*)data {
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0)
    {
        NSLog(@"onC2CHeartBeat|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    Header header;
    CmdC2CHeartBeat req;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    int ret = decodeC2CHeartBeat(recvBuf, recvLen, &header, &req);
    if (ret != 0)
    {
        NSLog(@"onC2CHeartBeat|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (req.toAccount != kAccount.myAccount || req.account != kAccount.toAccount)
    {
        NSLog(@"onC2CHeartBeat|fromip:%@, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, req.toAccount, kAccount.toAccount, req.account);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    // 收到对方心跳需要马上回应，在网络层进行处理
    return 0;
}

// 收到心跳回复
- (int)parseC2CHeartResp:(NSData*)data {
    if (kAccount.myAccount == 0 || kAccount.toAccount == 0)
    {
        NSLog(@"onC2CHeartBeatRsp|invalid myAccount:%lld, toAccount:%lld", kAccount.myAccount, kAccount.toAccount);
        self.cmdStatus = C2S_ERR_NOTLOGIN;
        return -1;
    }
    
    Header header;
    CmdC2CHeartBeatRsp rsp;
    uint16_t recvLen = data.length;
    Byte *recvBuf = (Byte*)data.bytes;
    
    int ret = decodeC2CHeartBeatRsp(recvBuf, recvLen, &header, &rsp);
    if (ret != 0)
    {
        NSLog(@"onC2CHeartBeatRsp|decode fail");
        self.cmdStatus = C2S_ERR_Data;
        return -1;
    }
    
    if (rsp.toAccount != kAccount.myAccount || rsp.account != kAccount.toAccount)
    {
        NSLog(@"onC2CHeartBeatRsp|fromip:%@, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", kAccount.rspIp, kAccount.rspPort, kAccount.myAccount, rsp.toAccount, kAccount.toAccount, rsp.account);
        self.cmdStatus = C2S_ERR_NotMyData;
        return -1;
    }
    
    NSLog(@"onC2CHeartBeatRsp|fromip:%@, fromport:%u|account:%lld, toAccount:%lld, ip:%s, port:%u, localIp:%s, localPort:%u", kAccount.rspIp, kAccount.rspPort, rsp.account, rsp.toAccount, rsp.ip, rsp.port, rsp.localIp, rsp.localPort);
    
    return 0;
}

- (int)parseC2CLarge:(NSData*)data {
    return 0;
}

- (int)parseC2CLargeResp:(NSData*)data {
    return 0;
}

#pragma mark - helper

- (void)c2cSetIpAndPort {
    int ret = 0;
    
    if (kAccount.rspIp == nil || [kAccount.rspIp isEqualToString:@"0.0.0.0"] || [kAccount.rspIp isEqualToString:@"127.0.0.1"] || kAccount.rspPort == 0)
    {
        return;
    }
    
    if ([kAccount.myIp isEqualToString:kAccount.toIp])
    {
        if (![kAccount.toLocalIp isEqualToString:kAccount.rspIp] || kAccount.toLocalPort != kAccount.rspPort)
        {
            kAccount.toLocalIp = kAccount.rspIp;
            kAccount.toLocalPort = kAccount.rspPort;
            ret = 1;
        }
    }
    else
    {
        if (![kAccount.toIp isEqualToString:kAccount.rspIp] || kAccount.toPort != kAccount.rspPort)
        {
            kAccount.toIp = kAccount.rspIp;
            kAccount.toPort = kAccount.rspPort;
            ret = 2;
        }
    }
    
    NSLog(@"c2cSetIpAndPort ip:%@, port:%u, ret:%d", kAccount.rspIp, kAccount.rspPort, ret);
}

// TODO:后期将压缩放到任务线程（这里处理)
- (NSData*)encodeData:(id)converter {
    NSData *data = nil;
    if([self.mode isMemberOfClass:[PYIMModeVideo class]]){
        // 视频数据
        data = [(PYIMVideoConverter*)converter encode:(PYIMModeVideo*)self.mode];
        
    }else if([self.mode isMemberOfClass:[PYIMModeAudio class]]){
        // 语音数据
        if(self.mode.is8kTo8k){
            data = [(PYIMAudioConverter*)converter encodeAudioADPCM:[NSMutableData dataWithData:self.mode.media]];
        }else {
            data = [(PYIMAudioConverter*)converter encodeAudio:[NSMutableData dataWithData:self.mode.media] compres:YES];
        }
    }
    
    return data;
}

- (NSData*)getSendData:(id)converter {
    if([converter isKindOfClass:[PYIMVideoConverter class]])
        self.videoConv = converter;
    else
        self.audioConv = converter;
    
    _createdTime = [[NSDate date] timeIntervalSince1970]*1000;
    
    if(dataSend==nil){
        char buf[P2P_MAX_BUF_SIZE];
        uint16_t sendLen = 0;
        memset(buf, 0, P2P_MAX_BUF_SIZE);
        // header
        Header *header = (Header *)buf;
        header->CmdId = htons_x(self.cmdID);
        header->SeqId = htons_x(self.seqID);
        header->CmdStatus = htons_x(self.cmdStatus);
//        header->Client = htons_x(Client_iOS);
        
        sendLen += sizeof(header);
        // param
        memcpy(buf+sizeof(Header), self.dataParam.bytes, self.dataParam.length);
        
        sendLen += self.dataParam.length;
        // media
        NSData *media = nil;
        
        if(self.cmdID==C2C_VIDEO_FRAME){
            media = self.mode.media; // 视频分片发送已经在api层编码
        }else {
            media = [self encodeData:converter];
        }
        
        if(media){
            if(media.length<(P2P_MAX_BUF_SIZE-sendLen)){
                memcpy(buf+sendLen, media.bytes, media.length);
                sendLen += media.length;
            } else {
                NSLog(@"发送数据长度超出最大要求:%d", sendLen+(int)media.length);
                return nil;
            }
        }
        
        header->TotalLen = htons_x(sendLen);
        
        dataSend = [NSData dataWithBytes:buf length:sendLen];
    }
    
    return dataSend;
}

- (id)copyWithZone:(NSZone *)zone {
    PYIMModeMedia *model = [super copyWithZone:zone];
    model.createdTime = _createdTime;
    model.sender = _sender;
    model.reciver = _reciver;
    
    return model;
}

+ (void)resetSerialNumber {
    SerialNumber = 0;
}

- (void)prepareReSend {
//    dataSend = nil;
    _sendCount++;
    _resentCount--;
}

- (BOOL)shouldRecResponse {
    switch (self.cmdID) {
        case C2C_REQUEST:
        case C2C_REQUEST_RSP:
        case C2C_CLOSE:
        case C2C_AUDIO_FRAME:
        case C2C_VIDEO_FRAME:
        case C2C_VIDEO_FRAME_EX:
        case C2C_CANCEL_REQUEST:
        case C2C_HOLE_RSP:
        case C2C_HOLE:
        case C2S_LOGOUT:
            
        case C2S_HEART_BEAT:
        case C2C_HEART_BEAT:
            
        case C2C_SWITCH:
            
            return NO;
            
        default: return YES;
    }
}

@end


@implementation PYIMModeNetwork

- (uint16_t)cmdID {
    return self.media.cmdID;
}

- (uint16_t)seqID {
    return self.media.seqID;
}

- (BOOL)timeOut {
    return self.media.timeOut;
}

- (long)tagSelf {
    return self.media.seqID;
//    if(_tagSelf == 0)
//         _tagSelf = (long)&self;
//
//    return _tagSelf;
}

- (BOOL)resendable {
    if(self.cmdID==C2S_LOGIN)return YES;
    if(!kAccount.hadLogin)return NO;
    if(self.media.mode)return NO;
    if(self.media.resentCount>0)return YES;
    
    return NO;
}

- (BOOL)shouldRecResponse {
    return self.media.shouldRecResponse;
}

- (NSString*)hostServer {
    if(self.media.rspIP)
        return self.media.rspIP;
    return _hostServer;
}

- (uint16_t)portServer {
    if(self.media.rspPort>0)
        return self.media.rspPort;
    return _portServer;
}

- (id)copyWithZone:(NSZone *)zone {
    PYIMModeNetwork *netw = [[self.class alloc] init];
    netw.callback = _callback;
    netw.media = [_media copy];
    netw.hostServer = _hostServer;
    netw.portServer = _portServer;
    return netw;
}

- (void)finishedWithErrDesc:(NSString*)desc {
    PYIMError *error = [[PYIMError alloc] initWithError:desc];
    error.cmdID = self.cmdID;
    [self finished:error];
}

- (void)finishedWithCode:(uint16_t)errorCode {
    PYIMError *error = [[PYIMError alloc] initWithError:nil];
    error.cmdStatus = errorCode;
    error.cmdID = self.cmdID;
    [self finished:error];
}

- (void)finished:(PYIMError*)error {
    if(self.callback){
        // 网络层自己的任务不需要走主线程
        dispatch_async(dispatch_get_main_queue(), ^{
            self.callback(error);
        });
    }
}

- (BOOL)needClean {
    long span = [[NSDate date] timeIntervalSince1970]*1000 - self.media.createdTime;
    return (span/1000)>30;
}

+ (Header)parseHeader:(NSData*)data {
    Byte *buf = (Byte*)data.bytes;
    Header *pheader = (Header *)buf;
    Header header;
    
    memset(&header, 0, sizeof(Header));
    header.CmdId = ntohs_x(pheader->CmdId);
    header.CmdStatus = ntohs_x(pheader->CmdStatus);
    header.SeqId = ntohs_x(pheader->SeqId);
    header.TotalLen = ntohs_x(pheader->TotalLen);
    
    return header;
}

// 网络子线程处理
+ (NSArray<PYIMModeMedia*>*)cutPackage:(NSData *)data converter:(NSArray*)converters callback:(void(^)(NSData *dataPart))callback {
    NSMutableArray *mArr = [NSMutableArray array];
    
    // 解析消息头，如果没法解析说明数据未接收完成
    if(data.length < sizeof(Header)){
        if(callback){
            callback(data);
        }
        
        return mArr;
    }
    
    
    // 解析消息体
    NSData *dataRemain = data;
    
    while (1) {
        Header header = [self parseHeader:dataRemain];
        
        if(dataRemain.length<header.TotalLen){
            break; // 未接收完成
        }
        
        id convert = nil;
        for(id temp in converters){
            if(header.CmdId==C2C_AUDIO_FRAME && [temp isKindOfClass:[PYIMAudioConverter class]]){
                convert = temp;
                break;
            }else if((header.CmdId == C2C_VIDEO_FRAME ||
                      header.CmdId == C2C_VIDEO_FRAME_EX) && [temp isKindOfClass:[PYIMVideoConverter class]]){
                convert = temp;
                break;
            }
        }
        
        
        NSData *sub = [NSData dataWithBytes:dataRemain.bytes length:header.TotalLen];
        PYIMModeMedia *media = [[PYIMModeMedia alloc] initWithData:sub converter:convert];
        [mArr addObject:media];
        
        dataRemain = dataRemain.length==sub.length ? nil : [dataRemain subdataWithRange:NSMakeRange(sub.length, dataRemain.length-sub.length)];
        
        if(dataRemain.length<sizeof(Header))
            break;
    }
    
    if(mArr.count>1){
        NSLog(@"receive many packages:%ti", mArr.count);
    }
    
    if(dataRemain){
        // 出现数据接收不完整情况，需要缓存下来下次拼接使用
        if(callback){
            callback(dataRemain);
        }
    }
    
    return mArr;
}


@end
