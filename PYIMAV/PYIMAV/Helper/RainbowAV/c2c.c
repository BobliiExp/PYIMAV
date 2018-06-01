#include "c2c.h"

int encodeHole(uint16_t SeqId, uint16_t CmdStatus, CmdHole *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdHole));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_HOLE);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdHole *body = (CmdHole *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	return 0;
}

int decodeHole(uint8_t *buf, uint16_t len, Header *pHeader, CmdHole *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdHole));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdHole));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdHole *body = (CmdHole *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	return 0;
}

int encodeHoleRsp(uint16_t SeqId, uint16_t CmdStatus, CmdHoleRsp *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdHoleRsp));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_HOLE_RSP);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdHoleRsp *body = (CmdHoleRsp *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	return 0;
}

int decodeHoleRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdHoleRsp *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdHoleRsp));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdHoleRsp));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdHoleRsp *body = (CmdHoleRsp *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	return 0;
}

int encodeRequest(uint16_t SeqId, uint16_t CmdStatus, CmdRequest *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdRequest));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_REQUEST);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdRequest *body = (CmdRequest *)(buf+sizeof(Header));
	body->type = pBody->type;
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	return 0;
}

int decodeRequest(uint8_t *buf, uint16_t len, Header *pHeader, CmdRequest *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdRequest));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdRequest));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdRequest *body = (CmdRequest *)(buf+sizeof(Header));
	pBody->type = body->type;
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	return 0;
}

int encodeRequestRsp(uint16_t SeqId, uint16_t CmdStatus, CmdRequestRsp *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdRequestRsp));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_REQUEST_RSP);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdRequestRsp *body = (CmdRequestRsp *)(buf+sizeof(Header));
	body->type = pBody->type;
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	body->accept = pBody->accept;
	return 0;
}

int decodeRequestRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdRequestRsp *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdRequestRsp));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdRequestRsp));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdRequestRsp *body = (CmdRequestRsp *)(buf+sizeof(Header));
	pBody->type = body->type;
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	pBody->accept = body->accept;
	return 0;
}

int encodeCancelRequest(uint16_t SeqId, uint16_t CmdStatus, CmdCancelRequest *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdCancelRequest));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_CANCEL_REQUEST);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdCancelRequest *body = (CmdCancelRequest *)(buf+sizeof(Header));
	body->type = pBody->type;
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	return 0;
}

int decodeCancelRequest(uint8_t *buf, uint16_t len, Header *pHeader, CmdCancelRequest *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdCancelRequest));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdCancelRequest));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdCancelRequest *body = (CmdCancelRequest *)(buf+sizeof(Header));
	pBody->type = body->type;
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	return 0;
}

int encodeClose(uint16_t SeqId, uint16_t CmdStatus, CmdClose *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdClose));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_CLOSE);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdClose *body = (CmdClose *)(buf+sizeof(Header));
	body->type = pBody->type;
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	return 0;
}

int decodeClose(uint8_t *buf, uint16_t len, Header *pHeader, CmdClose *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdClose));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdClose));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdClose *body = (CmdClose *)(buf+sizeof(Header));
	pBody->type = body->type;
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	return 0;
}

int encodePause(uint16_t SeqId, uint16_t CmdStatus, CmdPause *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdPause));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_PAUSE);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdPause *body = (CmdPause *)(buf+sizeof(Header));
	body->type = pBody->type;
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	return 0;
}

int decodePause(uint8_t *buf, uint16_t len, Header *pHeader, CmdPause *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdPause));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdPause));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdPause *body = (CmdPause *)(buf+sizeof(Header));
	pBody->type = body->type;
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	return 0;
}

int encodeResume(uint16_t SeqId, uint16_t CmdStatus, CmdResume *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdResume));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_RESUME);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdResume *body = (CmdResume *)(buf+sizeof(Header));
	body->type = pBody->type;
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	return 0;
}

int decodeResume(uint8_t *buf, uint16_t len, Header *pHeader, CmdResume *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdResume));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdResume));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdResume *body = (CmdResume *)(buf+sizeof(Header));
	pBody->type = body->type;
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	return 0;
}

int encodeSwitch(uint16_t SeqId, uint16_t CmdStatus, CmdSwitch *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdSwitch));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_SWITCH);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdSwitch *body = (CmdSwitch *)(buf+sizeof(Header));
	body->type = pBody->type;
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	return 0;
}

int decodeSwitch(uint8_t *buf, uint16_t len, Header *pHeader, CmdSwitch *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdSwitch));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdSwitch));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdSwitch *body = (CmdSwitch *)(buf+sizeof(Header));
	pBody->type = body->type;
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	return 0;
}

int encodeVideoFrame(uint16_t SeqId, uint16_t CmdStatus, CmdVideoFrame *pBody, uint8_t *data, uint16_t data_len, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdVideoFrame) + data_len);
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_VIDEO_FRAME);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdVideoFrame *body = (CmdVideoFrame *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	body->width = htons_x(pBody->width);
	body->height = htons_x(pBody->height);
	body->fps = htons_x(pBody->fps);
	body->bitrate = htons_x(pBody->bitrate);
	body->angle = htons_x(pBody->angle);
	body->mirror = htons_x(pBody->mirror);
//	body->totallen = htons_x(pBody->totallen);
//	body->curpos = htons_x(pBody->curpos);
//	body->curlen = htons_x(data_len);
	body->frameID = htonll_x(pBody->frameID);
	body->frameLen = htons_x(pBody->frameLen);
	body->packs = htons_x(pBody->packs);
	body->pid = htons_x(pBody->pid);
	body->packLen = htons_x(pBody->packLen);
    body->client = htons_x(pBody->client);
	memcpy(buf+sizeof(Header)+sizeof(CmdVideoFrame), data, data_len);
	return 0;
}

int decodeVideoFrame(uint8_t *buf, uint16_t len, Header *pHeader, CmdVideoFrame *pBody, uint8_t *data, uint16_t *data_len)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdVideoFrame));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdVideoFrame));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdVideoFrame *body = (CmdVideoFrame *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	pBody->width = ntohs_x(body->width);
	pBody->height = ntohs_x(body->height);
	pBody->fps = ntohs_x(body->fps);
	pBody->bitrate = ntohs_x(body->bitrate);
	pBody->angle = ntohs_x(body->angle);
	pBody->mirror = ntohs_x(body->mirror);
//	pBody->totallen = ntohs_x(body->totallen);
//	pBody->curpos = ntohs_x(body->curpos);
	pBody->frameID = ntohll_x(body->frameID);
	pBody->frameLen = ntohs_x(body->frameLen);
	pBody->packs = ntohs_x(body->packs);
	pBody->pid = ntohs_x(body->pid);
	pBody->packLen = ntohs_x(body->packLen);
    pBody->client = ntohs_x(body->client);
    
	if ((uint16_t)(pHeader->TotalLen - iTotalLen) > (uint16_t)(*data_len))
	{
		return -1;
	}
	*data_len = (uint16_t)(pHeader->TotalLen - iTotalLen);
//	pBody->curlen = *data_len;
	memcpy(data, buf+iTotalLen, (uint16_t)(pHeader->TotalLen - iTotalLen));
	return 0;
}


int encodeVideoFrameEx(uint16_t SeqId, uint16_t CmdStatus, CmdVideoFrameEx *pBody, uint8_t *data, uint16_t data_len, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdVideoFrameEx) + data_len);
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_VIDEO_FRAME_EX);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdVideoFrameEx *body = (CmdVideoFrameEx *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	body->width = htons_x(pBody->width);
	body->height = htons_x(pBody->height);
	body->fps = htons_x(pBody->fps);
	body->bitrate = htons_x(pBody->bitrate);
	body->angle = htons_x(pBody->angle);
	body->mirror = htons_x(pBody->mirror);
    body->client = htons_x(pBody->client);
    
	memcpy(buf+sizeof(Header)+sizeof(CmdVideoFrameEx), data, data_len);
	return 0;
}

int decodeVideoFrameEx(uint8_t *buf, uint16_t len, Header *pHeader, CmdVideoFrameEx *pBody, uint8_t *data, uint16_t *data_len)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdVideoFrameEx));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdVideoFrameEx));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdVideoFrameEx *body = (CmdVideoFrameEx *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	pBody->width = ntohs_x(body->width);
	pBody->height = ntohs_x(body->height);
	pBody->fps = ntohs_x(body->fps);
	pBody->bitrate = ntohs_x(body->bitrate);
	pBody->angle = ntohs_x(body->angle);
	pBody->mirror = ntohs_x(body->mirror);
    pBody->client = ntohs_x(body->client);
    
	if ((uint16_t)(pHeader->TotalLen - iTotalLen) > (uint16_t)(*data_len))
	{
		return -1;
	}
	*data_len = (uint16_t)(pHeader->TotalLen - iTotalLen);
	memcpy(data, buf+iTotalLen, (uint16_t)(pHeader->TotalLen - iTotalLen));
	return 0;
}


int encodeAudioFrame(uint16_t SeqId, uint16_t CmdStatus, CmdAudioFrame *pBody, uint8_t *data, uint16_t data_len, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdAudioFrame) + data_len);
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_AUDIO_FRAME);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdAudioFrame *body = (CmdAudioFrame *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	memcpy(buf+sizeof(Header)+sizeof(CmdAudioFrame), data, data_len);
	return 0;
}

int decodeAudioFrame(uint8_t *buf, uint16_t len, Header *pHeader, CmdAudioFrame *pBody, uint8_t *data, uint16_t *data_len)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdAudioFrame));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdAudioFrame));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdAudioFrame *body = (CmdAudioFrame *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	if ((uint16_t)(pHeader->TotalLen - iTotalLen) > (uint16_t)(*data_len))
	{
		return -1;
	}
	*data_len = (uint16_t)(pHeader->TotalLen - iTotalLen);
	memcpy(data, buf+iTotalLen, (uint16_t)(pHeader->TotalLen - iTotalLen));
	return 0;
}

int encodeText(uint16_t SeqId, uint16_t CmdStatus, CmdText *pBody, uint8_t *data, uint16_t data_len, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdText) + data_len);
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;

	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_TEXT_FRAME);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);

	CmdText *body = (CmdText *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	body->toAccount = htonll_x(pBody->toAccount);
	body->len = htonl(pBody->len);
	memcpy(buf+sizeof(Header)+sizeof(CmdText), data, data_len);
	return 0;
}

int decodeText(uint8_t *buf, uint16_t len, Header *pHeader, CmdText *pBody, uint8_t *data, uint16_t *data_len)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdText));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdText));
	if (len < iTotalLen)
	{
		return -1;
	}

	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);

	CmdText *body = (CmdText *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	pBody->len = ntohl(body->len);
	*data_len = (uint16_t)(pHeader->TotalLen - iTotalLen);
	memcpy(data, buf+iTotalLen, (uint16_t)(pHeader->TotalLen - iTotalLen));
	return 0;
}

int encodeFileBlock(uint16_t SeqId, uint16_t CmdStatus, CmdFileBlock *pBody, uint8_t *data, uint16_t data_len, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdFileBlock) + data_len);
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;

	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_FILE_FRAME);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);

	CmdFileBlock *body = (CmdFileBlock *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	body->len = htonl(pBody->len);
	body->bid = htonl(pBody->bid);
	body->blocks = htonl(pBody->blocks);
	body->type = htons_x(pBody->type);
	memcpy(body->name, pBody->name, sizeof(body->name));
	memcpy(buf+sizeof(Header)+sizeof(CmdFileBlock), data, data_len);
	return 0;
}

int decodeFileBlock(uint8_t *buf, uint16_t len, Header *pHeader, CmdFileBlock *pBody, uint8_t *data, uint16_t *data_len)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdFileBlock));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdFileBlock));
	if (len < iTotalLen)
	{
		return -1;
	}

	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);

	CmdFileBlock *body = (CmdFileBlock *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	pBody->len = ntohl(body->len);
	pBody->bid = ntohl(body->bid);
	pBody->blocks = ntohl(body->blocks);
	pBody->type = ntohs_x(body->type);
	memcpy(pBody->name, body->name, sizeof(pBody->name));
	*data_len = (uint16_t)(pHeader->TotalLen - iTotalLen);
	memcpy(data, buf+iTotalLen, (uint16_t)(pHeader->TotalLen - iTotalLen));

	return 0;
}

int encodeFileBlockRsp(uint16_t SeqId, uint16_t CmdStatus, CmdFileBlockRsp *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdFileBlockRsp));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;

	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_FILE_FRAME_RSP);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);

	CmdFileBlockRsp *body = (CmdFileBlockRsp *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	body->bid = 	htons_x(pBody->bid);
	return 0;
}

int decodeFileBlockRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdFileBlockRsp *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdHole));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdFileBlockRsp));
	if (len < iTotalLen)
	{
		return -1;
	}

	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);

	CmdFileBlockRsp *body = (CmdFileBlockRsp *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	pBody->toAccount = ntohll_x(body->toAccount);
	pBody->bid = ntohs_x(body->bid);
	return 0;
}

int encodeC2CHeartBeat(uint16_t SeqId, uint16_t CmdStatus, CmdC2CHeartBeat *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdC2CHeartBeat));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;

	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_HEART_BEAT);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);

	CmdC2CHeartBeat *body = (CmdC2CHeartBeat *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	memcpy(body->ip, pBody->ip, sizeof(body->ip));
	body->port = htons_x(pBody->port);
	memcpy(body->localIp, pBody->localIp, sizeof(body->localIp));
	body->localPort = htons_x(pBody->localPort);
	body->toAccount = htonll_x(pBody->toAccount);
	return 0;
}

int decodeC2CHeartBeat(uint8_t *buf, uint16_t len, Header *pHeader, CmdC2CHeartBeat *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdC2CHeartBeat));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdC2CHeartBeat));
	if (len < iTotalLen)
	{
		return -1;
	}

	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);

	CmdC2CHeartBeat *body = (CmdC2CHeartBeat *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	memcpy(pBody->ip, body->ip, sizeof(pBody->ip));
	pBody->port = ntohs_x(body->port);
	memcpy(pBody->localIp, body->localIp, sizeof(pBody->localIp));
	pBody->localPort = ntohs_x(body->localPort);
	pBody->toAccount = ntohll_x(body->toAccount);
	return 0;
}

int encodeC2CHeartBeatRsp(uint16_t SeqId, uint16_t CmdStatus, CmdC2CHeartBeatRsp *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdC2CHeartBeatRsp));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;

	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2C_HEART_BEAT_RSP);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);

	CmdC2CHeartBeatRsp *body = (CmdC2CHeartBeatRsp *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	memcpy(body->ip, pBody->ip, sizeof(body->ip));
	body->port = htons_x(pBody->port);
	memcpy(body->localIp, pBody->localIp, sizeof(body->localIp));
	body->localPort = htons_x(pBody->localPort);
	body->toAccount = htonll_x(pBody->toAccount);
	return 0;
}

int decodeC2CHeartBeatRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdC2CHeartBeatRsp *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdC2CHeartBeatRsp));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdC2CHeartBeatRsp));
	if (len < iTotalLen)
	{
		return -1;
	}

	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);

	CmdC2CHeartBeatRsp *body = (CmdC2CHeartBeatRsp *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	memcpy(pBody->ip, body->ip, sizeof(pBody->ip));
	pBody->port = ntohs_x(body->port);
	memcpy(pBody->localIp, body->localIp, sizeof(pBody->localIp));
	pBody->localPort = ntohs_x(body->localPort);
	pBody->toAccount = ntohll_x(body->toAccount);
	return 0;
}
