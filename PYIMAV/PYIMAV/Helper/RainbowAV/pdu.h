#ifndef __PDU_H_
#define __PDU_H_

#include <stdint.h>
#include <arpa/inet.h>

#define P2P_MAX_BUF_SIZE 8192
#define P2P_VIDEO_SLICE_SIZE 1400

#define P2P_CHAT_TYPE_MASK_NORMAL 0x1  //文本
#define P2P_CHAT_TYPE_MASK_AUDIO  0x2  //音频
#define P2P_CHAT_TYPE_MASK_VIDEO  0x4  //视频
#define P2P_CHAT_TYPE_MASK_FILE   0x8  //文件

#define P2P_CHAT_TYPE_NORMAL 0  //文本
#define P2P_CHAT_TYPE_AUDIO  1  //音频
#define P2P_CHAT_TYPE_VIDEO  2  //视频
#define P2P_CHAT_TYPE_FILE   3  //文件

#define P2P_INIT_LISTEN_PORT 9901

#ifdef __cplusplus
extern "C" {
#endif

// �ṹ����
#pragma pack(1)
    
typedef struct {
    uint16_t TotalLen;
    uint16_t CmdId;
    uint16_t SeqId;
    uint16_t CmdStatus;
//    uint16_t Client;
} Header;
    
    union bswap_helper
{
	int64_t i64;
	int32_t i32[2];
};

#pragma pack()
/// 编码发送
uint64_t htonll_x(uint64_t x);
/// 解码
uint64_t ntohll_x(uint64_t x);
    
uint16_t htons_x(uint16_t x);
uint16_t ntohs_x(uint16_t x);

uint32_t htonl_x(uint32_t x);
uint32_t ntohl_x(uint32_t x);

#ifdef __cplusplus
}
#endif
#endif
