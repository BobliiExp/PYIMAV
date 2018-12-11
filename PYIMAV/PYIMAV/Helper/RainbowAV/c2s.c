#include <string.h>
#include "c2s.h"
#include "pdu.h"

int encodeLogin(uint16_t SeqId, uint16_t CmdStatus, CmdLogin *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdLogin));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2S_LOGIN);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdLogin *body = (CmdLogin *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	memcpy(body->password, pBody->password, sizeof(body->password));
	memcpy(body->localIp, pBody->localIp, sizeof(body->localIp));
	body->localPort = htons_x(pBody->localPort);
	
	return 0;
}

int decodeLogin(uint8_t *buf, uint16_t len, Header *pHeader, CmdLogin *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdLogin));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdLogin));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdLogin *body = (CmdLogin *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	memcpy(pBody->password, body->password, sizeof(pBody->password));
	memcpy(pBody->localIp, body->localIp, sizeof(pBody->localIp));
	pBody->localPort = ntohs_x(body->localPort);
	return 0;
}

int encodeLoginRsp(uint16_t SeqId, uint16_t CmdStatus, CmdLoginRsp *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdLoginRsp));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2S_LOGIN_RSP);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdLoginRsp *body = (CmdLoginRsp *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	memcpy(body->ip, pBody->ip, sizeof(body->ip));
	body->port = htons_x(pBody->port);
	memcpy(body->localIp, pBody->localIp, sizeof(body->localIp));
	body->localPort = htons_x(pBody->localPort);
	return 0;
}

int decodeLoginRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdLoginRsp *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdLoginRsp));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdLoginRsp));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdLoginRsp *body = (CmdLoginRsp *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	memcpy(pBody->ip, body->ip, sizeof(pBody->ip));
	pBody->port = ntohs_x(body->port);
	memcpy(pBody->localIp, body->localIp, sizeof(pBody->localIp));
	pBody->localPort = ntohs_x(body->localPort);
	return 0;
}

int encodeLogout(uint16_t SeqId, uint16_t CmdStatus, CmdLogout *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdLogout));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2S_LOGOUT);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdLogout *body = (CmdLogout *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	return 0;
}

int decodeLogout(uint8_t *buf, uint16_t len, Header *pHeader, CmdLogout *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdLogout));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdLogout));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdLogout *body = (CmdLogout *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	return 0;
}


int encodeHeartBeat(uint16_t SeqId, uint16_t CmdStatus, CmdHeartBeat *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdHeartBeat));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2S_HEART_BEAT);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdHeartBeat *body = (CmdHeartBeat *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	memcpy(body->localIp, pBody->localIp, sizeof(body->localIp));
	body->localPort = htons_x(pBody->localPort);
	return 0;
}

int decodeHeartBeat(uint8_t *buf, uint16_t len, Header *pHeader, CmdHeartBeat *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdHeartBeat));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdHeartBeat));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdHeartBeat *body = (CmdHeartBeat *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	memcpy(pBody->localIp, body->localIp, sizeof(pBody->localIp));
	pBody->localPort = ntohs_x(body->localPort);
	return 0;
}
int encodeHeartBeatRsp(uint16_t SeqId, uint16_t CmdStatus, CmdHeartBeatRsp *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdHeartBeatRsp));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2S_HEART_BEAT_RSP);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdHeartBeatRsp *body = (CmdHeartBeatRsp *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	memcpy(body->ip, pBody->ip, sizeof(body->ip));
	body->port = htons_x(pBody->port);
	memcpy(body->localIp, pBody->localIp, sizeof(body->localIp));
	body->localPort = htons_x(pBody->localPort);
	return 0;
}
int decodeHeartBeatRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdHeartBeatRsp *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdHeartBeatRsp));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdHeartBeatRsp));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdHeartBeatRsp *body = (CmdHeartBeatRsp *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	memcpy(pBody->ip, body->ip, sizeof(pBody->ip));
	pBody->port = ntohs_x(body->port);
	memcpy(pBody->localIp, body->localIp, sizeof(pBody->localIp));
	pBody->localPort = ntohs_x(body->localPort);
	return 0;
}

int encodeC2SHole(uint16_t SeqId, uint16_t CmdStatus, CmdC2SHole *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdC2SHole));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2S_HOLE);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdC2SHole *body = (CmdC2SHole *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	body->toAccount = htonll_x(pBody->toAccount);
	memcpy(body->localIp, pBody->localIp, sizeof(body->localIp));
	body->localPort = htons_x(pBody->localPort);
	return 0;
}

int decodeC2SHole(uint8_t *buf, uint16_t len, Header *pHeader, CmdC2SHole *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdC2SHole));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdC2SHole));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdC2SHole *body = (CmdC2SHole *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	memcpy(pBody->localIp, body->localIp, sizeof(pBody->localIp));
	pBody->localPort = ntohs_x(body->localPort);
	pBody->toAccount = ntohll_x(body->toAccount);
	return 0;
}

int encodeC2SHoleRsp(uint16_t SeqId, uint16_t CmdStatus, CmdC2SHoleRsp *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdC2SHoleRsp));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2S_HOLE_RSP);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdC2SHoleRsp *body = (CmdC2SHoleRsp *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	memcpy(body->ip, pBody->ip, sizeof(body->ip));
	body->port = htons_x(pBody->port);
	memcpy(body->localIp, pBody->localIp, sizeof(body->localIp));
	body->localPort = htons_x(pBody->localPort);
	body->toAccount = htonll_x(pBody->toAccount);
	memcpy(body->toIp, pBody->toIp, sizeof(body->toIp));
	body->toPort = htons_x(pBody->toPort);
	memcpy(body->toLocalIp, pBody->toLocalIp, sizeof(body->toLocalIp));
	body->toLocalPort = htons_x(pBody->toLocalPort);
	return 0;
}

int decodeC2SHoleRsp(uint8_t *buf, uint16_t len, Header *pHeader, CmdC2SHoleRsp *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdC2SHoleRsp));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdC2SHoleRsp));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdC2SHoleRsp *body = (CmdC2SHoleRsp *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	memcpy(pBody->ip, body->ip, sizeof(pBody->ip));
	pBody->port = ntohs_x(body->port);
	memcpy(pBody->localIp, body->localIp, sizeof(pBody->localIp));
	pBody->localPort = ntohs_x(body->localPort);
	pBody->toAccount = ntohll_x(body->toAccount);
	memcpy(pBody->toIp, body->toIp, sizeof(pBody->toIp));
	pBody->toPort = ntohs_x(body->toPort);
	memcpy(pBody->toLocalIp, body->toLocalIp, sizeof(pBody->toLocalIp));
	pBody->toLocalPort = ntohs_x(body->toLocalPort);
	return 0;
}
int encodeC2SHoleNotify(uint16_t SeqId, uint16_t CmdStatus, CmdC2SHoleNotify *pBody, uint8_t *buf, uint16_t *len)
{
	memset(buf, 0, (int)(*len));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdC2SHoleNotify));
	if (*len < iTotalLen)
	{
		return -1;
	}
	*len = iTotalLen;
	
	Header *header = (Header *)buf;
	header->TotalLen = htons_x(iTotalLen);
	header->CmdId = htons_x(C2S_HOLE_NOTIFY);
	header->SeqId = htons_x(SeqId);
	header->CmdStatus = htons_x(CmdStatus);
	
	CmdC2SHoleNotify *body = (CmdC2SHoleNotify *)(buf+sizeof(Header));
	body->account = htonll_x(pBody->account);
	memcpy(body->ip, pBody->ip, sizeof(body->ip));
	body->port = htons_x(pBody->port);
	memcpy(body->localIp, pBody->localIp, sizeof(body->localIp));
	body->localPort = htons_x(pBody->localPort);
	body->toAccount = htonll_x(pBody->toAccount);
	memcpy(body->toIp, pBody->toIp, sizeof(body->toIp));
	body->toPort = htons_x(pBody->toPort);
	memcpy(body->toLocalIp, pBody->toLocalIp, sizeof(body->toLocalIp));
	body->toLocalPort = htons_x(pBody->toLocalPort);
	return 0;
}

int decodeC2SHoleNotify(uint8_t *buf, uint16_t len, Header *pHeader, CmdC2SHoleNotify *pBody)
{
	memset(pHeader, 0, sizeof(Header));
	memset(pBody, 0, sizeof(CmdC2SHoleNotify));
	uint16_t iTotalLen = (uint16_t)(sizeof(Header) + sizeof(CmdC2SHoleNotify));
	if (len < iTotalLen)
	{
		return -1;
	}
	
	Header *header = (Header *)buf;
	pHeader->TotalLen = ntohs_x(header->TotalLen);
	pHeader->CmdId = ntohs_x(header->CmdId);
	pHeader->SeqId = ntohs_x(header->SeqId);
	pHeader->CmdStatus = ntohs_x(header->CmdStatus);
	
	CmdC2SHoleNotify *body = (CmdC2SHoleNotify *)(buf+sizeof(Header));
	pBody->account = ntohll_x(body->account);
	memcpy(pBody->ip, body->ip, sizeof(pBody->ip));
	pBody->port = ntohs_x(body->port);
	memcpy(pBody->localIp, body->localIp, sizeof(pBody->localIp));
	pBody->localPort = ntohs_x(body->localPort);
	pBody->toAccount = ntohll_x(body->toAccount);
	memcpy(pBody->toIp, body->toIp, sizeof(pBody->toIp));
	pBody->toPort = ntohs_x(body->toPort);
	memcpy(pBody->toLocalIp, body->toLocalIp, sizeof(pBody->toLocalIp));
	pBody->toLocalPort = ntohs_x(body->toLocalPort);
	return 0;
}
