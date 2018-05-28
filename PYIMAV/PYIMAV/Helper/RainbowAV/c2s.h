#ifndef __C2S_H_
#define __C2S_H_

#include <string.h>
#include <stdint.h>
#include "pdu.h"

#ifdef __cplusplus
extern "C" {
#endif

// 消息包结构: 2字节包长(TotalLen)+2字节命令字(CmdId)+2字节序列号(SeqId)+2字节响应码(CmdStatus)+包体(可选)

// 命令ID定义
#define C2S_HEART_BEAT 				0x0001 			// 心跳
#define C2S_HEART_BEAT_RSP 			0x1001 			// 心跳响应
#define C2S_LOGIN 					0x0002 			// 登录
#define C2S_LOGIN_RSP 				0x1002 			// 登录响应
#define C2S_LOGOUT 					0x0003 			// 注销
#define C2S_HOLE 					0x0004 			// 请求对方地址,并让对方往自己打洞
#define C2S_HOLE_RSP 				0x1004 			// 打洞响应
#define C2S_HOLE_NOTIFY 			0x1005 			// 服务器发来消息让自己往对方打洞


// 错误码定义
#define C2S_ERR_OK 					0x0000 			// 正确
#define C2S_ERR_INVALID_ACCOUNT 	0x0001 			// 无效帐号
#define C2S_ERR_INVALID_PASSWORD 	0x0002 			// 无效密码
#define C2S_ERR_OFFLINE 			0x0003 			// 对方离线
#define C2S_ERR_NOTLOGIN 			0x0004 			// 没有登录
    
#define C2S_ERR_Disconnect          0x0005             // 没有链接
#define C2S_ERR_ServerConfg         0x0006             // 服务器配置错误
#define C2S_ERR_Data                0x0007             // 接收到数据错误
#define C2S_ERR_NotMyData           0x0008             // 不是属于我的数据

// 结构定义
#pragma pack(1)

typedef struct {
	int64_t account;
	int8_t password[64];
	char localIp[16];
	uint16_t localPort;
} CmdLogin;

typedef struct {
	int64_t account;
	char ip[16];
	uint16_t port;
	char localIp[16];
	uint16_t localPort;
} CmdLoginRsp;

typedef struct {
	int64_t account;
} CmdLogout;

typedef struct {
	int64_t account;
	char localIp[16];
	uint16_t localPort;
} CmdHeartBeat;

typedef struct {
	int64_t account;
	char ip[16];
	uint16_t port;
	char localIp[16];
	uint16_t localPort;
} CmdHeartBeatRsp;

typedef struct {
	int64_t account;
	char localIp[16];
	uint16_t localPort;
	int64_t toAccount;
} CmdC2SHole;

typedef struct {
	int64_t account;
	char ip[16];
	uint16_t port;
	char localIp[16];
	uint16_t localPort;
	int64_t toAccount;
	char toIp[16];
	uint16_t toPort;
	char toLocalIp[16];
	uint16_t toLocalPort;
} CmdC2SHoleRsp;
typedef struct {
	int64_t account;
	char ip[16];
	uint16_t port;
	char localIp[16];
	uint16_t localPort;
	int64_t toAccount;
	char toIp[16];
	uint16_t toPort;
	char toLocalIp[16];
	uint16_t toLocalPort;
} CmdC2SHoleNotify;

#pragma pack()
/**
 * 登录协议编码
 */
int encodeLogin(uint16_t SeqId, uint16_t CmdStatus, CmdLogin *pBody, uint8_t *buf, uint16_t *len);
/**
 * 登录协议解码
 */
int decodeLogin(uint8_t *buf, uint16_t len, Header *pHeader, CmdLogin *pBody);
/**
 * 登录回包编码
 */
int encodeLoginRsp(uint16_t SeqId, uint16_t CmdStatus, CmdLoginRsp *pBody, uint8_t *buf, uint16_t *len);
/**
 * 登录回包解码
 */
int decodeLoginRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdLoginRsp *pBody);
/**
 * 退出登录协议编码
 */
int encodeLogout(uint16_t SeqId, uint16_t CmdStatus, CmdLogout *pBody, uint8_t *buf, uint16_t *len);
/**
 * 退出登录协议解码
 */
int decodeLogout(uint8_t *buf, uint16_t len, Header *pHeader, CmdLogout *pBody);

/**
 * c2s心跳编码
 */
int encodeHeartBeat(uint16_t SeqId, uint16_t CmdStatus, CmdHeartBeat *pBody, uint8_t *buf, uint16_t *len);
/**
 * c2s心跳解码
 */
int decodeHeartBeat(uint8_t *buf, uint16_t len, Header *pHeader, CmdHeartBeat *pBody);
/**
 * c2s心跳回包编码
 */
int encodeHeartBeatRsp(uint16_t SeqId, uint16_t CmdStatus, CmdHeartBeatRsp *pBody, uint8_t *buf, uint16_t *len);
/**
 * c2s心跳回包解码
 */
int decodeHeartBeatRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdHeartBeatRsp *pBody);
/**
 * 往服务器打洞协议编码
 */
int encodeC2SHole(uint16_t SeqId, uint16_t CmdStatus, CmdC2SHole *pBody, uint8_t *buf, uint16_t *len);
/**
 * 往服务器打洞协议解码
 */
int decodeC2SHole(uint8_t *buf, uint16_t len, Header *pHeader, CmdC2SHole *pBody);
/**
 * 往服务器打洞回包协议编码
 */
int encodeC2SHoleRsp(uint16_t SeqId, uint16_t CmdStatus, CmdC2SHoleRsp *pBody, uint8_t *buf, uint16_t *len);
/**
 * 往服务器打洞回包协议解码
 */
int decodeC2SHoleRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdC2SHoleRsp *pBody);
/**
 * c2s打洞消息协议编码
 */
int encodeC2SHoleNotify(uint16_t SeqId, uint16_t CmdStatus, CmdC2SHoleNotify *pBody, uint8_t *buf, uint16_t *len);
/**
 * c2s打洞消息协议解码
 */
int decodeC2SHoleNotify(uint8_t *buf, uint16_t len, Header *pHeader, CmdC2SHoleNotify *pBody);

#ifdef __cplusplus
}
#endif

#endif
