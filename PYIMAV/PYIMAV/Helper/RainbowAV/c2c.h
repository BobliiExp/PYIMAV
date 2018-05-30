#ifndef __C2C_H_
#define __C2C_H_

#include <string.h>
#include <stdint.h>
#include "pdu.h"

#ifdef __cplusplus
extern "C" {
#endif

// 消息包结构: 2字节包长(TotalLen)+2字节命令字(CmdId)+2字节序列号(SeqId)+2字节响应码(CmdStatus)+包体(可选)

// 命令ID定义
#define C2C_HOLE 					0x0101 			// 打洞
#define C2C_HOLE_RSP 				0x1101 			// 打洞响应
#define C2C_REQUEST		 			0x0102 			// 请求
#define C2C_REQUEST_RSP		 		0x1102 			// 请求响应
#define C2C_CANCEL_REQUEST		 	0x0104 			// 取消请求
#define C2C_CLOSE		 			0x0105 			// 关闭
#define C2C_PAUSE		 			0x0106 			// 暂停
#define C2C_RESUME 					0x0107 			// 恢复
#define C2C_VIDEO_FRAME 			0x0108 			// 视频数据
#define C2C_AUDIO_FRAME 			0x0109 			// 音频数据
#define C2C_TEXT_FRAME 				0x010A 			// 普通消息
#define C2C_FILE_FRAME 				0x010B 			// 文件消息
#define C2C_FILE_FRAME_RSP 			0x010C 			// 文件消息响应
#define C2C_HEART_BEAT 				0x010D 			// 心跳
#define C2C_HEART_BEAT_RSP 			0x110D 			// 心跳响应
#define C2C_SWITCH 					0x010F 			// 切换音频/视频
#define C2C_VIDEO_FRAME_EX 			0x0110 			// 视频数据扩展
#define C2C_LARGE 					0x0111 			// 大分片测试
#define C2C_LARGE_RSP 				0x1111 			// 大分片测试返回

// 错误码定义
#define C2C_ERR_OK 					0x0000 			// 正确
#define C2C_ERR_UNKNOWN 			0x0001 			// 未知错误
    
#define C2C_ERR_Disconnect          0x0100          // 未连接到任何c端
#define C2C_ERR_VideoSliceSize      0x0101          // 视频分片大小不正确
#define C2C_ERR_VideoSizeOverflow   0x0102          // 视频过大溢出
#define C2C_ERR_VideoFrameSize      0x0103          // 视频帧大小不正确
#define C2C_ERR_ExistDisconnect     0x0104          // 已经存在一个正常通话连接，新来的链接要丢掉

// 结构定义
#pragma pack(1)

typedef struct {
	int64_t account;
	int64_t toAccount;
} CmdHole;

typedef struct {
	int64_t account;
	int64_t toAccount;
} CmdHoleRsp;

typedef struct {//类型: 视频, 音频,文件
	int16_t type;	
	int64_t account;
	int64_t toAccount;
} CmdRequest;

typedef struct {//类型: 视频, 音频,文件
	int16_t type;	
	int64_t account;
	int64_t toAccount;
	int16_t accept;		//0x0通过,0x1拒绝
} CmdRequestRsp;

typedef struct {//类型: 视频, 音频,文件
	int16_t type;	
	int64_t account;
	int64_t toAccount;
} CmdCancelRequest;

typedef struct {//类型: 视频, 音频,文件
	int16_t type;	
	int64_t account;
	int64_t toAccount;
} CmdClose;

typedef struct {//类型: 视频
	int16_t type;	
	int64_t account;
	int64_t toAccount;
} CmdPause;

typedef struct {
	int16_t type;	//类型: 视频
	int64_t account;
	int64_t toAccount;
} CmdResume;

typedef struct {//类型: 视频, 音频
	int16_t type;	
	int64_t account;
	int64_t toAccount;
} CmdSwitch;

typedef struct {
	int64_t account;
	int64_t toAccount;
	uint16_t width;
	uint16_t height;
	uint16_t fps;
	uint16_t bitrate;
	uint16_t angle;
	uint16_t mirror;
//	uint16_t totallen;
//	uint16_t curpos;
//	uint16_t curlen;
	int64_t frameID;//帧id
	uint16_t frameLen;//帧长度
	uint16_t packs;//帧的包数
	uint16_t pid;//包ID
	uint16_t packLen;//包长度
    uint16_t client;
    
//    uint64_t timeStart; // 起始时间戳
//    uint64_t timeEnd;   // 结束时间戳
} CmdVideoFrame;

typedef struct {
	int64_t account;
	int64_t toAccount;
	uint16_t width;
	uint16_t height;
	uint16_t fps;
	uint16_t bitrate;
	uint16_t angle;
	uint16_t mirror;
    uint16_t client;
    
//    uint64_t timeStart; // 起始时间戳
//    uint64_t timeEnd;   // 结束时间戳
} CmdVideoFrameEx;

typedef struct {
	int64_t account;
	int64_t toAccount;
    
//    uint64_t timeStart; // 起始时间戳
//    uint64_t timeEnd;   // 结束时间戳
} CmdAudioFrame;


typedef struct {
	int64_t account;
	int64_t toAccount;
	int32_t len;
} CmdText;
typedef struct {
	int64_t account;
	int64_t toAccount;
	int32_t len;
	int32_t blocks;//总块数 每块4096
	int32_t bid;//块数
	uint16_t type;			// 文件类型
	char    name[64];
} CmdFileBlock;
typedef struct {
	int64_t account;
	int64_t toAccount;
	int32_t bid;//块数
} CmdFileBlockRsp;

typedef struct {
	int64_t account;
	char ip[16];
	uint16_t port;
	char localIp[16];
	uint16_t localPort;
	int64_t toAccount;
} CmdC2CHeartBeat;

typedef struct {
	int64_t account;
	char ip[16];
	uint16_t port;
	char localIp[16];
	uint16_t localPort;
	int64_t toAccount;
} CmdC2CHeartBeatRsp;

#pragma pack()

/**
 * 打洞协议包封包
 */
int encodeHole(uint16_t SeqId, uint16_t CmdStatus, CmdHole *pBody, uint8_t *buf, uint16_t *len);
/**
 * 打洞协议包解包
 */
int decodeHole(uint8_t *buf, uint16_t len, Header *pHeader, CmdHole *pBody);

/**
 * 打洞协议回包封包
 */
int encodeHoleRsp(uint16_t SeqId, uint16_t CmdStatus, CmdHoleRsp *pBody, uint8_t *buf, uint16_t *len);
/**
 * 打洞协议回包解包
 */
int decodeHoleRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdHoleRsp *pBody);
/**
 * 发送请求协议封包
 */
int encodeRequest(uint16_t SeqId, uint16_t CmdStatus, CmdRequest *pBody, uint8_t *buf, uint16_t *len);
/**
 * 发送请求协议解包
 */
int decodeRequest(uint8_t *buf, uint16_t len, Header *pHeader, CmdRequest *pBody);
/**
 * 回复请求协议封包
 */
int encodeRequestRsp(uint16_t SeqId, uint16_t CmdStatus, CmdRequestRsp *pBody, uint8_t *buf, uint16_t *len);
/**
 * 回复请求协议解包
 */
int decodeRequestRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdRequestRsp *pBody);
/**
 * 取消请求协议封包
 */
int encodeCancelRequest(uint16_t SeqId, uint16_t CmdStatus, CmdCancelRequest *pBody, uint8_t *buf, uint16_t *len);
/**
 * 取消请求协议解包
 */
int decodeCancelRequest(uint8_t *buf, uint16_t len, Header *pHeader, CmdCancelRequest *pBody);
/**
 * 关闭请求协议封包
 */
int encodeClose(uint16_t SeqId, uint16_t CmdStatus, CmdClose *pBody, uint8_t *buf, uint16_t *len);
/**
 * 关闭请求协议解包
 */
int decodeClose(uint8_t *buf, uint16_t len, Header *pHeader, CmdClose *pBody);
/**
 * 暂停请求协议封包
 */
int encodePause(uint16_t SeqId, uint16_t CmdStatus, CmdPause *pBody, uint8_t *buf, uint16_t *len);
/**
 * 暂停请求协议解包
 */
int decodePause(uint8_t *buf, uint16_t len, Header *pHeader, CmdPause *pBody);
/**
 * 继续动作协议封包，如：暂停的前提下，继续视频 / 继续语聊
 */
int encodeResume(uint16_t SeqId, uint16_t CmdStatus, CmdResume *pBody, uint8_t *buf, uint16_t *len);
/**
 * 继续动作协议解包
 */
int decodeResume(uint8_t *buf, uint16_t len, Header *pHeader, CmdResume *pBody);
/**
 * 切换动作协议封包，如：切换语音/视频
 */
int encodeSwitch(uint16_t SeqId, uint16_t CmdStatus, CmdSwitch *pBody, uint8_t *buf, uint16_t *len);
/**
 * 切换动作协议解包
 */
int decodeSwitch(uint8_t *buf, uint16_t len, Header *pHeader, CmdSwitch *pBody);
/**
 * 视频帧数据编码
 */
int encodeVideoFrame(uint16_t SeqId, uint16_t CmdStatus, CmdVideoFrame *pBody, uint8_t *data, uint16_t data_len, uint8_t *buf, uint16_t *len);
/**
 * 视频帧数据解码
 */
int decodeVideoFrame(uint8_t *buf, uint16_t len, Header *pHeader, CmdVideoFrame *pBody, uint8_t *data, uint16_t *data_len);
/**
 * 视频帧数据编码扩展
 */
int encodeVideoFrameEx(uint16_t SeqId, uint16_t CmdStatus, CmdVideoFrameEx *pBody, uint8_t *data, uint16_t data_len, uint8_t *buf, uint16_t *len);
/**
 * 视频帧数据解码扩展
 */
int decodeVideoFrameEx(uint8_t *buf, uint16_t len, Header *pHeader, CmdVideoFrameEx *pBody, uint8_t *data, uint16_t *data_len);
/**
 * 音频帧数据编码
 */
int encodeAudioFrame(uint16_t SeqId, uint16_t CmdStatus, CmdAudioFrame *pBody, uint8_t *data, uint16_t data_len, uint8_t *buf, uint16_t *len);
/**
 * 音频帧数据解码
 */
int decodeAudioFrame(uint8_t *buf, uint16_t len, Header *pHeader, CmdAudioFrame *pBody, uint8_t *data, uint16_t *data_len);

int encodeText(uint16_t SeqId, uint16_t CmdStatus, CmdText *pBody, uint8_t *data, uint16_t data_len, uint8_t *buf, uint16_t *len);
int decodeText(uint8_t *buf, uint16_t len, Header *pHeader, CmdText *pBody, uint8_t *data, uint16_t *data_len);

int encodeFileBlock(uint16_t SeqId, uint16_t CmdStatus, CmdFileBlock *pBody, uint8_t *data, uint16_t data_len, uint8_t *buf, uint16_t *len);
int decodeFileBlock(uint8_t *buf, uint16_t len, Header *pHeader, CmdFileBlock *pBody, uint8_t *data, uint16_t *data_len);

int encodeFileBlockRsp(uint16_t SeqId, uint16_t CmdStatus, CmdFileBlockRsp *pBody, uint8_t *buf, uint16_t *len);
int decodeFileBlockRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdFileBlockRsp *pBody);
/**
 * c2c心跳包编码
 */
int encodeC2CHeartBeat(uint16_t SeqId, uint16_t CmdStatus, CmdC2CHeartBeat *pBody, uint8_t *buf, uint16_t *len);
/**
 * c2c心跳包解码
 */
int decodeC2CHeartBeat(uint8_t *buf, uint16_t len, Header *pHeader, CmdC2CHeartBeat *pBody);
/**
 * c2c心跳回包编码
 */
int encodeC2CHeartBeatRsp(uint16_t SeqId, uint16_t CmdStatus, CmdC2CHeartBeatRsp *pBody, uint8_t *buf, uint16_t *len);
/**
 * c2c心跳回包解码
 */
int decodeC2CHeartBeatRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdC2CHeartBeatRsp *pBody);

#ifdef __cplusplus
}
#endif

#endif
