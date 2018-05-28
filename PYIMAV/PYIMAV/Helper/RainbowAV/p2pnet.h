#ifndef _P2PNET_H_
#define _P2PNET_H_

#include <sys/socket.h> 
#include <sys/epoll.h> 
#include <netinet/in.h> 
#include <arpa/inet.h> 
#include <sys/types.h>
#include <sys/select.h>
#include <netdb.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>

#include "global.h"
#include "socket_util.h"

#include "pdu.h"
#include "c2c.h"
#include "c2s.h"

#ifdef __cplusplus
extern "C" {
#endif

#define P2P_MAX_BUF_SIZE 8192
#define P2P_VIDEO_SLICE_SIZE 1400

/*#define P2S_STATE_NONE 0
#define P2S_STATE_LOGIN_INIT 1
#define P2S_STATE_LOGIN_SUCC 2
#define P2S_STATE_LOGIN_FAIL 3

#define P2P_STATE_NONE 0
#define P2P_STATE_HOLE_INIT 1
#define P2P_STATE_CONNECT_SUCC 2
#define P2P_STATE_CONNECT_FAIL 3

#define P2P_REQ_STATE_NONE 0
#define P2P_REQ_STATE_INIT 1
#define P2P_REQ_STATE_SUCC 2
#define P2P_REQ_STATE_FAIL 3*/

#define P2P_CHAT_TYPE_MASK_NORMAL 0x1  //文本
#define P2P_CHAT_TYPE_MASK_AUDIO  0x2  //音频
#define P2P_CHAT_TYPE_MASK_VIDEO  0x4  //视频
#define P2P_CHAT_TYPE_MASK_FILE   0x8  //文件

#define P2P_CHAT_TYPE_NORMAL 0  //文本
#define P2P_CHAT_TYPE_AUDIO  1  //音频
#define P2P_CHAT_TYPE_VIDEO  2  //视频
#define P2P_CHAT_TYPE_FILE   3  //文件

#define P2P_INIT_LISTEN_PORT 9901
//系统错误
#define	EVENT_ERROR  -1
//p2p连接失败
#define EVENT_P2P_DISCONNECT  -2
//发送请求超时
#define EVENT_REQUEST_TIMEOUT -3
//摄像头错误，打不开
#define EVENT_CAMERA_ERRO -4
//网络出错
#define EVENT_P2S_DISCONNECT -5
//视频服务器连接失败
#define EVENT_VIDEO_CONNECT_FAIL -6
//登陆错误
#define EVENT_P2S_LOGIN_FAIL -9
//对方发来视频请求
#define EVENT_REQUEST_VIDEO_BY_FRIEND 1
//对方发来语音请求
#define EVENT_REQUEST_AUDIO_BY_FRIEND 2
//对方发来文件请求
#define EVENT_REQUEST_FILE_BY_FRIEND 3
//对方取消了视频请求
#define EVENT_CANCEL_REQUEST_VIDEO_BY_FRIEND 4
//对方取消了语音请求
#define EVENT_CANCEL_REQUEST_AUDIO_BY_FRIEND 5
//对方取消了文件请求
#define EVENT_CANCEL_REQUEST_FILE_BY_FRIEND 6	
//对方接受了视频请求
#define EVENT_ACCEPT_VIDEO_BY_FRIEND 7
//对方接受了语音请求
#define EVENT_ACCEPT_AUDIO_BY_FRIEND 8
//对方接受了文件请求
#define EVENT_ACCEPT_FILE_BY_FRIEND 9
//对方拒绝了视频请求
#define EVENT_REJECT_VIDEO_BY_FRIEND 10
//对方拒绝了语音请求
#define EVENT_REJECT_AUDIO_BY_FRIEND 11
//对方拒绝了文件请求
#define EVENT_REJECT_FILE_BY_FRIEND 12
//对方暂停了视频
#define EVENT_PAUSE_VIDEO_BY_FRIEND 13
//对方继续视频
#define EVENT_RESUME_VIDEO_BY_FRIEND 14
//对方关闭了视频通话
#define EVENT_CLOSED_VIDEO_BY_FRIEND 15
//对方暂停了声音
#define EVENT_PAUSE_AUDIO_BY_FRIEND 16
//对方打开了声音
#define EVENT_RESUME_AUDIO_BY_FRIEND 17
//对方关闭了语音通话
#define EVENT_CLOSED_AUDIO_BY_FRIEND 18
//对方SDK版本不支持
#define EVENT_SDK_NOT_SUPPORT_BY_FRIEND 19

//P2P连接建立成功
#define EVENT_P2P_CONNECT 20
//对方关闭了文件发送
#define EVENT_CLOSED_FILE_BY_FRIEND  21
//文本消息
#define EVENT_RECV_TEXT  22
//服务连接建立成功
#define EVENT_P2S_CONNECT 23
//视频服务器连接成功
#define EVENT_VIDEO_CONNECT_SUCC 24

//切换到语音模式
#define EVENT_P2S_SWITCH_AUDIO 29
//切换到视频模式
#define EVENT_P2S_SWITCH_VIDEO 30

typedef struct {
	int efd;				// epoll fd
	int srvSock;			// udp socket句柄
	uint8_t isTcp;			// 是否强制走tcp中转(0:否, 1:是)
	fd_set srvNewrset;		// udp 事件集
	pthread_t srvTid;		// udp 线程ID
	pthread_t videoTid;		// video 线程ID

	pthread_mutex_t mtx;	// 互斥锁
	uint8_t terminate;		// 退出标记

	char srvIp[16];			// 服务器IP
	uint16_t srvPort;		// 服务器端口
	uint8_t srvState;		// 与服务器连接状态
	int srvSendTime;		// 最后往服务器发送数据的时间
	int srvRecvTime;		// 最后接收到服务器数据的时间
	int64_t srvSendSeq;		// 最后发送数据到服务器的序列号

	char videoIp[16];		// video 中转服务器IP
	uint16_t videoPort;		// video 中转服务器PORT
	int videoSock;			// video 中转服务器tcp句柄
	uint8_t videoState;		// video 状态
	uint8_t videoConnected;	// video 连接状态
	int videoSendTime; 		// video 发送时间
	int videoRecvTime; 		// video 接收时间
	int videoConnTime;		// video 连接时间

	char audioIp[16];		// audio 中转服务器IP
	uint16_t audioPort;		// audio 中转服务器PORT
	int audioSock;			// audio 中转服务器tcp句柄
	uint8_t audioState;		// audio 状态
	int audioSendTime; 		// audio 发送时间
	int audioRecvTime; 		// audio 接收时间

	int64_t myAccount;		// 自己帐号
	char myPassword[64];	// 自己密码
	char myIp[16];			// 自己IP
	uint16_t myPort;		// 自己PORT
	char myLocalIp[16];		// 自己本地IP
	uint16_t myLocalPort;	// 自己本地PORT
	
	int64_t toAccount;		// 对方帐号
	char toIp[16];			// 对方IP
	uint16_t toPort;		// 对方PORT
	char toLocalIp[16];		// 对方本地IP
	uint16_t toLocalPort;	// 对方本地PORT
	uint8_t toState;		// 与对方连接状态
	int toSendTime;			// 最后往对方发送数据的时间
	int toRecvTime;			// 最后接收到对方数据的时间

	uint8_t chatType;		// 聊天类型掩码
	uint8_t chatSave;		// 请求类型保存
	uint8_t chatState;		// 在会话状态
	int chatTimeout;		// 聊天超时
	time_t chatLastTime;	// 最后聊天时间

	uint64_t frameID;		// 视频帧
	uint8_t *videoBuf;		// 视频缓冲区
	uint16_t videoSize;		// 视频缓冲区大小
	uint16_t videoLen;		// 视频长度
	
	uint8_t *swapBuf;		// 交换缓冲区
	
	uint8_t *fileBuf;		// 文件缓冲区
	uint32_t fileLen;		// 文件长度
	uint32_t bid;			// 当前块
	uint32_t blocks;		// 当前块
	uint16_t fileType;		// 文件类型
	uint8_t *fileName;		// 文件名
	int     blockTime;		// block时间
} p2pnet_t;

/**
 * p2p模块初始化
 */
void p2pInit(const char *srvIp, uint16_t srvPort, uint8_t isTcp, int timeout);
/**
 * p2p模块销毁
 */
void p2pExit();
/**
 * 设置本地局域网ip与端口，端口其实无需设置（预留）
 */
void p2pSetLocalIpAndPort(const char *localIp, uint16_t localPort);
/**
 * 登陆
 */
int c2sLogin(int64_t myAccount, const char *myPassword);
/**
 * 退出登陆
 */
int c2sLogout();
int c2sGetAccount(int64_t toAccount, int chatType);
/**
 * c2c接受请求,type表示语音/视频
 */
int c2cAccept(int accept,int type);
/**
 * c2c取消请求
 */
int c2cCancelRequest(int64_t myAccount,int64_t toAccount,int type);
/**
 * c2c关闭请求
 */
int c2cClose(int64_t myAccount,int64_t toAccount,int type);
/**
 * c2c暂停请求
 */
int c2cPause(int64_t myAccount,int64_t toAccount,int type);
/**
 * c2c继续请求，继续语音/视频
 */
int c2cResume(int64_t myAccount,int64_t toAccount,int type);
/**
 * c2c切换模式，语音/视频
 */
int c2cSwitch(int64_t myAccount,int64_t toAccount,int type);
/**
 * c2c视频帧编码
 */
int c2cVideoFrame(int64_t fid, int packs,int pid, int fLen,unsigned char *frame, int len, int width, int height, int fps, int bitrate, int angle, int mirror);
/**
 * c2c视频帧编码扩展
 */
int c2cVideoFrameEx(unsigned char *frame, int len, int width, int height, int fps, int bitrate, int angle, int mirror);
/**
 * 发消息，暂废弃
 */
int c2cSendText(unsigned char *text);
/**
 * 发文件，暂废弃
 */
int c2cSendFile(unsigned char *content,char *name,int type,int len);
/**
 * 发消息，暂废弃
 */
int c2cAudioFrame(unsigned char *frame, int len);
/**
 * 视频帧解码
 */
int video_decode(JNIEnv *env, char *buf, int buf_size);

    
    void onC2SLoginRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                       uint16_t recvLen);
    void onC2SHeartBeatRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                           uint16_t recvLen);
    void onC2SGetAccountRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                            uint16_t recvLen);
    void onC2SGetAccountNotify(p2pnet_t *p, char *ip, uint16_t port,
                               uint8_t *recvBuf, uint16_t recvLen);
    
    void onC2CHole(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                   uint16_t recvLen);
    void onC2CHoleRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                      uint16_t recvLen);
    void onC2CRequest(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                      uint16_t recvLen);
    void onC2CRequestRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                         uint16_t recvLen);
    void onC2CCancleRequest(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                            uint16_t recvLen);
    
    void onC2CClose(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                    uint16_t recvLen);
    void onC2CPause(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                    uint16_t recvLen);
    void onC2CResume(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                     uint16_t recvLen);
    void onC2CSwitch(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                     uint16_t recvLen);
    void onC2CVideoFrame(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen);
    
    void onC2CVideoFrameEx(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen);
    
    void onC2CAudioFrame(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                         uint16_t recvLen);
    void onC2CRecvText(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                       uint16_t recvLen);
    void onC2CRecvFileBlock(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                            uint16_t recvLen);
    void onC2CRecvFileBlockRsp(p2pnet_t *p, char *ip, uint16_t port,
                               uint8_t *recvBuf, uint16_t recvLen);
    void onC2CHeartBeat(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                        uint16_t recvLen);
    void onC2CHeartBeatRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
                           uint16_t recvLen);
    
    void p2pcallback(int eventId, int64_t fromAccount, char *detail, int detail_len);
    
extern p2pnet_t g_p2pnet;

#ifdef __cplusplus
}
#endif

#endif

