/*#include "p2pnet.h"
#include "GLRender.h"
#include "h264decoder.h"
#include "x264encoder.h"
#include "native-audio-jni.h"

static JNIEnv *g_env;

p2pnet_t g_p2pnet;

void *p2pLoop(void *arg);
void *p2pThread(void *arg);

void p2p_proc_data(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
		uint16_t recvLen);

void video_proc_data(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
		uint16_t recvLen);
int videoInnerLogin(p2pnet_t *p);

void audio_proc_data(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf,
		uint16_t recvLen);
int audioInnerLogin(p2pnet_t *p);

int c2sInnerLogin(p2pnet_t *p);
int c2sInnerHeartBeat(p2pnet_t *p);
int c2cInnerHole(p2pnet_t *p);
int c2cInnerHeartBeat(p2pnet_t *p);
int c2cInnerRequest(p2pnet_t *p);

int videoInnerHeartBeat(p2pnet_t *p);
int audioInnerHeartBeat(p2pnet_t *p);

void c2cGetIpAndPort(p2pnet_t *p, char **pIp, uint16_t *pPort);
void c2cSetIpAndPort(p2pnet_t *p, char *ip, uint16_t port);
int c2cSendFileBlock(int bid);

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

int send_data(int type, int sockfd, char *buf, int len, int flags, const char *tohost, unsigned short toport)
{
	struct sockaddr_in toaddr;
	int left_bytes; 
	int send_bytes; 
	char *ptr;
	int retry_count;
	
	if (type == 0)
	{
		bzero(&toaddr, sizeof(struct sockaddr));
		toaddr.sin_family = AF_INET;
		toaddr.sin_addr.s_addr = inet_addr(tohost);
		toaddr.sin_port = htons(toport);
	}
	
	ptr = (char *)buf; 
	left_bytes = len;
	retry_count = 0;
	while (left_bytes > 0 && retry_count < 3) 
	{ 
		if (type == 0)
		{
			send_bytes = sendto(sockfd, ptr, left_bytes, flags, (struct sockaddr *)&toaddr, sizeof(toaddr));
		}
		else
		{
			send_bytes = send(sockfd, ptr, left_bytes, flags);
		}
		if (send_bytes < 0) 
		{ 
			if (errno == EAGAIN)
			{
				retry_count++;
				send_bytes = 0;
				usleep(1000);
			}
			else if (errno == EINTR)
			{
				send_bytes = 0;
			}
			else
			{
				break;
			}
		} 
		
		left_bytes -= send_bytes; 
		ptr += send_bytes; 
	}

	return len - left_bytes;
}

int MySendToSrv(p2pnet_t *p, const void *buf, int len, int flags,
		const char *tohost, unsigned short toport) {
	if (buf == NULL || len <= 0) {
		return -1;
	}

	if (p->srvSock == -1) {
		return -1;
	}

	if (!tohost) {
		return -1;
	}

	char sendIp[16];
	uint16_t sendPort;
	bzero(sendIp, sizeof(sendIp));
	strncpy(sendIp, tohost, sizeof(sendIp) - 1);
	sendPort = toport;
	if (sendPort == 0 || strlen(sendIp) == 0 || strcmp(sendIp, "0.0.0.0") == 0 || strcmp(sendIp, "127.0.0.1") == 0) {
		return -1;
	}
	
	if (strcmp(sendIp, p->srvIp) == 0 && sendPort == p->srvPort)
	{
		p->srvSendTime = time(NULL);
	}
	else if (strcmp(sendIp, p->toIp) == 0 && sendPort == p->toPort)
	{
		p->toSendTime = time(NULL);
	}
	else if (strcmp(sendIp, p->toLocalIp) == 0 && sendPort == p->toLocalPort)
	{
		p->toSendTime = time(NULL);
	}
	else
	{
		p->toSendTime = time(NULL);
	}

	if (strcmp(sendIp, p->srvIp) == 0 && sendPort == p->srvPort)
	{
		int ret = send_data(0, p->srvSock, (char *)buf, len, flags, sendIp, sendPort);
		if (ret != len)
		{
			LOGI("MySendToSrv|sendto:%d, len:%d, toip:%s, toport:%u", ret, len, sendIp, sendPort);
		}
		return ret;
	}
	else
	{
		struct sockaddr_in toaddr;
		bzero(&toaddr, sizeof(struct sockaddr_in));
		toaddr.sin_family = AF_INET;
		toaddr.sin_addr.s_addr = inet_addr(sendIp);
		toaddr.sin_port = htons(sendPort);
	
		int ret = sendto(p->srvSock, buf, len, flags, (struct sockaddr *)&toaddr, sizeof(toaddr));
		if (ret != len)
		{
			LOGI("MySendToSrv|sendto:%d, len:%d, toip:%s, toport:%u", ret, len, sendIp, sendPort);
		}
		return ret;
	}

	return 0;
}

int MySendToVideo(p2pnet_t *p, const void *buf, int len, int flags,
		const char *tohost, unsigned short toport) {
	if (buf == NULL || len <= 0) {
		LOGI("MySendToVideo|invalid param");
		return -1;
	}

	if (p->videoSock == -1) {
		LOGI("MySendToVideo|videoSock not create");
		return -1;
	}
	
	if (p->videoPort == 0 || strlen(p->videoIp) == 0 || strcmp(p->videoIp, "0.0.0.0") == 0 || strcmp(p->videoIp, "127.0.0.1") == 0) {
		LOGI("MySendToVideo|invalid videoIp");
		return -1;
	}
	
	p->videoSendTime = time(NULL);
	
	int ret = send_data(1, p->videoSock, (char *)buf, len, flags, tohost, toport);
	if (ret != len)
	{
		LOGI("MySendToVideo|sendto:%d, len:%d", ret, len);
	}
	
	return ret;
}

int MySendToAudio(p2pnet_t *p, const void *buf, int len, int flags,
		const char *tohost, unsigned short toport) {
	if (buf == NULL || len <= 0) {
		return -1;
	}

	if (p->audioSock == -1) {
		return -1;
	}
	
	if (p->audioPort == 0 || strlen(p->audioIp) == 0 || strcmp(p->audioIp, "0.0.0.0") == 0 || strcmp(p->audioIp, "127.0.0.1") == 0) {
		return -1;
	}
	
	p->audioSendTime = time(NULL);
	
	struct sockaddr_in toaddr;
	bzero(&toaddr, sizeof(struct sockaddr_in));
	toaddr.sin_family = AF_INET;
	toaddr.sin_addr.s_addr = inet_addr(p->audioIp);
	toaddr.sin_port = htons(p->audioPort);

	int ret = sendto(p->audioSock, buf, len, flags, (struct sockaddr *)&toaddr, sizeof(toaddr));
	if (ret != len)
	{
		LOGI("MySendToAudio|sendto:%d, len:%d", ret, len);
	}

	return ret;
}

void MySrvCreate(p2pnet_t *p) {
	if (p->srvSock == -1) 
	{
		for (uint16_t port = P2P_INIT_LISTEN_PORT; port < 10000; port++) 
		{
			int sockfd = UDPListen(port, NULL);
			if (sockfd != -1) 
			{
				if (SetNonBlock(sockfd) == 0)
				{
					struct epoll_event ev; 
					ev.data.fd = sockfd;                               
					ev.events = EPOLLIN;                               
					if (epoll_ctl(p->efd, EPOLL_CTL_ADD, sockfd, &ev) != 0)
					{
						close(sockfd);
					}
					else
					{
						p->myLocalPort = port;
						p->srvSock = sockfd;
						break;
					}
				}
				else
				{
					close(sockfd);
				}
			}
		}
	}
}

void MyVideoCreate(p2pnet_t *p) {
	if (p->videoSock == -1) 
	{
		int sockfd = socket(AF_INET, SOCK_STREAM, 0);
		if (sockfd != -1) 
		{
			if (SetNonBlock(sockfd) == 0)
			{
				struct epoll_event ev; 
				ev.data.fd = sockfd;                               
				ev.events = EPOLLIN|EPOLLOUT;                               
				if (epoll_ctl(p->efd, EPOLL_CTL_ADD, sockfd, &ev) != 0)
				{
					close(sockfd);
				}
				else
				{
					struct sockaddr_in serv_addr;
					memset(&serv_addr, 0, sizeof(serv_addr));
				  	serv_addr.sin_family = AF_INET;
				  	serv_addr.sin_addr.s_addr = inet_addr(p->videoIp);
				  	serv_addr.sin_port = htons(p->videoPort);
					
					if (connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) == -1 && errno != EINPROGRESS)
					{
						close(sockfd);
					}
					else
					{
						p->videoConnected = 0;
						p->videoSock = sockfd;
						p->videoConnTime = time(NULL);
					}
				}
			}
			else
			{
				close(sockfd);
			}
		}
	}
}

void MyAudioCreate(p2pnet_t *p) {
	if (p->audioSock == -1) 
	{
		int sockfd = UDPClient();
		if (sockfd != -1) 
		{
			if (SetNonBlock(sockfd) == 0)
			{
				struct epoll_event ev; 
				ev.data.fd = sockfd;                               
				ev.events = EPOLLIN;                               
				if (epoll_ctl(p->efd, EPOLL_CTL_ADD, sockfd, &ev) != 0)
				{
					close(sockfd);
				}
				else
				{
					p->audioSock = sockfd;
				}
			}
			else
			{
				close(sockfd);
			}
		}
	}
}

void p2pInit(const char *srvIp, uint16_t srvPort, uint8_t isTcp, int timeout) {
	LOGI("p2pInit start. srvIp:%s, srvPort:%u, isTcp:%u, timeout:%d", srvIp, srvPort, isTcp, timeout);

	srand(time(NULL));
	
	int now = time(NULL);

	p2pnet_t *p = &g_p2pnet;
	
	p->efd = epoll_create(1024);
	p->srvSock = -1;
	p->isTcp = isTcp;
	p->srvTid = 0;
	pthread_mutex_init(&p->mtx, NULL);
	p->terminate = 0;

	bzero(p->srvIp, sizeof(p->srvIp));
	strncpy(p->srvIp, srvIp, sizeof(p->srvIp) - 1);
	p->srvPort = srvPort;

	p->srvState = 0;
	p->srvSendTime = 0;
	p->srvRecvTime = 0;
	p->srvSendSeq = 0;

	bzero(p->videoIp, sizeof(p->videoIp));
	strncpy(p->videoIp, srvIp, sizeof(p->videoIp) - 1);
	p->videoPort = srvPort+2;
	p->videoSock = -1;
	p->videoState = 0;
	p->videoConnected = 0;
	p->videoSendTime = 0;
	p->videoRecvTime = 0;
	p->videoConnTime = 0;

	bzero(p->audioIp, sizeof(p->audioIp));
	strncpy(p->audioIp, srvIp, sizeof(p->audioIp) - 1);
	p->audioPort = srvPort+1;
	p->audioSock = -1;
	p->audioState = 0;
	p->audioSendTime = 0;
	p->audioRecvTime = 0;

	p->myAccount = 0;
	bzero(p->myPassword, sizeof(p->myPassword));
	bzero(p->myIp, sizeof(p->myIp));
	p->myPort = 0;
	bzero(p->myLocalIp, sizeof(p->myLocalIp));
	p->myLocalPort = 0;

	p->toAccount = 0;
	bzero(p->toIp, sizeof(p->toIp));
	p->toPort = 0;
	bzero(p->toLocalIp, sizeof(p->toLocalIp));
	p->toLocalPort = 0;

	p->toState = 0;
	p->toSendTime = 0;
	p->toRecvTime = 0;
	p->chatType = P2P_CHAT_TYPE_MASK_NORMAL;
	p->chatState = 0;
	p->chatTimeout = (timeout > 10) ? timeout : 10;
	p->chatLastTime = time(NULL);

	p->videoBuf = (uint8_t *) malloc(P2P_MAX_BUF_SIZE);
	if (!p->videoBuf)
	{
		LOGE("p2pInit malloc fail");
		p2pExit();
		return;
	}
	p->videoSize = P2P_MAX_BUF_SIZE;
	p->videoLen = 0;
	p->frameID = 0;

	p->swapBuf = (uint8_t *) malloc(P2P_MAX_BUF_SIZE);
	if (!p->swapBuf)
	{
		LOGE("p2pInit malloc fail");
		p2pExit();
		return;
	}

	if (pthread_create(&(p->srvTid), NULL, p2pThread, p) != 0) {
		LOGE("p2pInit pthread_create p2pThread fail");
	}

	LOGI("p2pInit end");
	return;
}

void p2pExit() {
	LOGI("p2pExit start");

	p2pnet_t *p = &g_p2pnet;

	p->terminate = 1;
	
	if (p->efd != -1)
	{
		close(p->efd);
		p->efd = -1;
	}
	
	if (p->srvTid != 0) {
		pthread_join(p->srvTid, NULL);
		p->srvTid = 0;
	}
	
	if (p->srvSock != -1) {
		close(p->srvSock);
		p->srvSock = -1;
	}

	if (p->videoSock != -1) {
		close(p->videoSock);
		p->videoSock = -1;
	}

	if (p->videoBuf) {
		free(p->videoBuf);
		p->videoBuf = NULL;
	}
	
	if (p->swapBuf) {
		free(p->swapBuf);
		p->swapBuf = NULL;
	}

	pthread_mutex_destroy(&p->mtx);
	LOGI("p2pExit end");
}

void p2pSetLocalIpAndPort(const char *localIp, uint16_t localPort)
{
	p2pnet_t *p = &g_p2pnet;

	if (strcmp(p->myLocalIp, localIp) != 0 && (int) strlen(localIp) < (int) sizeof(p->myLocalIp))
	{
		strncpy(p->myLocalIp, localIp, sizeof(p->myLocalIp) - 1);
		p->myLocalIp[strlen(localIp)] = 0;
	} 
}

void p2pcallback(int eventId, int64_t fromAccount, char *detail, int detail_len)
{
	if (JNI_TRUE == (*g_env)->IsSameObject(g_env, g_control_cls, NULL) || JNI_TRUE == (*g_env)->IsSameObject(g_env, g_control_obj, NULL))
	{
		LOGE("p2pcallback|g_control_cls or g_control_obj invalid");
		return;
	}

	jmethodID control_mid = (*g_env)->GetMethodID(g_env, g_control_cls, "callbackOnEvent", "(IJ[B)V");
	if (control_mid == 0)
	{
		LOGE("p2pcallback|control_mid is null");
		return;
	}

	jbyteArray byteDetail = NULL;
	if (detail && detail_len > 0)
	{
		byteDetail = (*g_env)->NewByteArray(g_env, detail_len);
		(*g_env)->SetByteArrayRegion(g_env, byteDetail, 0, detail_len, detail);
	}

	(*g_env)->CallVoidMethod(g_env, g_control_obj, control_mid, eventId, fromAccount, byteDetail);
	(*g_env)->DeleteLocalRef(g_env, byteDetail);

	return;
}

void onRecvFile(int64_t fromAccount, int type, char * fileName, long fileLen, char *data, int dataLen, int bid, int blocks)
{
	if (JNI_TRUE == (*g_env)->IsSameObject(g_env, g_control_cls, NULL) || JNI_TRUE == (*g_env)->IsSameObject(g_env, g_control_obj, NULL))
	{
		LOGE("onRecvFile|g_control_cls or g_control_obj invalid");
		return;
	}

	jmethodID control_mid = (*g_env)->GetMethodID(g_env, g_control_cls, "onRecvFile", "(JI[BI[BII)V");
	if (control_mid == 0)
	{
		LOGE("onRecvFile|control_mid is null");
		return;
	}

	jbyteArray byteFileName = NULL;
	if (fileName)
	{
		byteFileName = (*g_env)->NewByteArray(g_env, strlen(fileName));
		(*g_env)->SetByteArrayRegion(g_env, byteFileName, 0, strlen(fileName), fileName);
	}
	else
	{
		LOGE("onRecvFile|filename is null");
		return;
	}

	jbyteArray byteDetail = NULL;
	if (data && dataLen > 0)
	{
		byteDetail = (*g_env)->NewByteArray(g_env, dataLen);
		(*g_env)->SetByteArrayRegion(g_env, byteDetail, 0, dataLen, data);
	}
	else
	{
		LOGE("onRecvFile|data is null or invalid dataLen:%d", dataLen);

		(*g_env)->ReleaseByteArrayElements(g_env, byteFileName, fileName, 0);
		(*g_env)->DeleteLocalRef(g_env, byteFileName);
		return;
	}

	(*g_env)->CallVoidMethod(g_env, g_control_obj, control_mid, fromAccount, type, byteFileName, fileLen, byteDetail, blocks, bid);

	(*g_env)->DeleteLocalRef(g_env, byteFileName);
	(*g_env)->DeleteLocalRef(g_env, byteDetail);

	return;
}

void onSendFile(int64_t toAccount, int type, char * fileName, int bid, int blocks)
{
	if (JNI_TRUE == (*g_env)->IsSameObject(g_env, g_control_cls, NULL) || JNI_TRUE == (*g_env)->IsSameObject(g_env, g_control_obj, NULL))
	{
		LOGE("onSendFile|g_control_cls or g_control_obj invalid");
		return;
	}

	jmethodID control_mid = (*g_env)->GetMethodID(g_env, g_control_cls, "onSendFile", "(JI[BII)V");
	if (control_mid == 0)
	{
		LOGE("onSendFile|control_mid is null");
		return;
	}

	jbyteArray byteFileName = NULL;
	if (fileName)
	{
		byteFileName = (*g_env)->NewByteArray(g_env, strlen(fileName));
		(*g_env)->SetByteArrayRegion(g_env, byteFileName, 0, strlen(fileName), fileName);
	}
	else
	{
		LOGE("onSendFile|filename is null");
		return;
	}

	(*g_env)->CallVoidMethod(g_env, g_control_obj, control_mid, toAccount, type, byteFileName, blocks, bid);
	(*g_env)->DeleteLocalRef(g_env, byteFileName);

	return;
}

void *p2pThread(void *arg) {
	LOGI("p2pThread|enter");

	sigset_t newmask;
	sigemptyset(&newmask);
	sigaddset(&newmask, SIGINT);
	sigaddset(&newmask, SIGUSR1);
	sigaddset(&newmask, SIGPIPE);
	sigprocmask(SIG_BLOCK, &newmask, NULL);
	
	p2pnet_t *p = &g_p2pnet;
	
	uint16_t recvMax = P2P_MAX_BUF_SIZE;
	uint16_t recvLen = 0;
	uint8_t *recvBuf = (uint8_t *)malloc(recvMax);

	if (!recvBuf) {
		LOGE("p2pThread|malloc faile");
		return NULL;
	}

	uint16_t videoMax = P2P_MAX_BUF_SIZE;
	uint16_t videoLen = 0;
	uint8_t *videoBuf = (uint8_t *)malloc(videoMax);

	if (!videoBuf) {
		LOGE("p2pThread|malloc faile");
		free(recvBuf);
		return NULL;
	}

	if ((*g_jvm)->AttachCurrentThread(g_jvm, &g_env, NULL) != JNI_OK)
	{
		LOGE("p2pThread|AttachCurrentThread faile");
		free(recvBuf);
		free(videoBuf);
		return NULL;
	}
	
	struct sockaddr_in from;
	socklen_t fromlen;
	int nread;
	char recvIp[16];
	uint16_t recvPort;
	uint16_t len;

  	struct epoll_event ev; 
	const int MAXEVENTS = 1024;
	struct epoll_event events[MAXEVENTS];

	int i, nfds;
	
	int videoRecvTime;
	int audioRecvTime;
	int srvRecvTime;
	
	videoRecvTime = audioRecvTime = srvRecvTime = time(NULL);
	
	while (p->terminate == 0) 
	{
		if (p->srvSock == -1)
		{
			p->chatState = 0;
			
			bzero(p->myIp, sizeof(p->myIp));
			p->myPort = 0;
			p->myLocalPort = 0;
			
			bzero(p->toIp, sizeof(p->toIp));
			p->toPort = 0;
			bzero(p->toLocalIp, sizeof(p->toLocalIp));
			p->toLocalPort = 0;
			
			p->toState = 0;
			p->toSendTime = 0;

			p->srvState = 0;
			p->srvSendTime = 0;
			MySrvCreate(p);
			if (p->srvSock == -1) 
			{
				LOGI("p2pThread|MySrvCreate fail");
			} 
			else 
			{
				LOGI("p2pThread|srvSock create succ");
				
				p->toRecvTime = time(NULL);
				p->srvRecvTime = time(NULL);
			}
		}
	
		if (p->videoSock == -1) 
		{
			LOGI("p2pThread|video connect start");
			
			videoLen = 0;
			p->videoState = 0;
			p->videoSendTime = 0;
			MyVideoCreate(p);
			if (p->videoSock == -1) 
			{
				LOGI("p2pThread|MyVideoCreate fail");
			} 
			else 
			{
				LOGI("p2pThread|videoSock create succ");
				
				videoRecvTime = p->videoRecvTime = time(NULL);
			}
		}
		else if (p->videoConnected == 0)
		{
			if ((int)(p->videoConnTime + 120) < (int)time(NULL))
			{
				LOGI("p2pThread|video connect timeout");
				
				close(p->videoSock);                    
				epoll_ctl(p->efd, EPOLL_CTL_DEL, p->videoSock, &ev);
				p->videoSock = -1;
				
				p2pcallback(EVENT_VIDEO_CONNECT_FAIL, 0, NULL, 0);
			}
		}
		else if (p->myAccount != 0)
		{
			if ((int)(videoRecvTime + 30) < (int)time(NULL))
			{
				LOGI("p2pThread|video read timeout");
				
				close(p->videoSock);                    
				epoll_ctl(p->efd, EPOLL_CTL_DEL, p->videoSock, &ev);
				p->videoSock = -1;
			}
		}
		
		if (p->audioSock == -1) 
		{
			p->audioState = 0;
			p->audioSendTime = 0;
			MyAudioCreate(p);
			if (p->audioSock == -1) 
			{
				LOGI("p2pThread|MyAudioCreate fail");
			} 
			else 
			{
				LOGI("p2pThread|audioSock create succ");
				
				audioRecvTime = p->audioRecvTime = time(NULL);
			}
		}
		else if (p->myAccount != 0)
		{
			if ((int)(audioRecvTime + 30) < (int)time(NULL))
			{
				LOGI("p2pThread|audio read timeout");
				
				close(p->audioSock);                    
				epoll_ctl(p->efd, EPOLL_CTL_DEL, p->audioSock, &ev);
				p->audioSock = -1;
			}
		}
		
		if (p->myAccount != 0)
		{
			if (p->srvSock != -1)
			{
				if (p->srvState != 1)
				{
					if ((int)(time(NULL) - p->srvSendTime) > 3)
					{
						c2sInnerLogin(p);
					}
				}
				else
				{
					if ((int)(time(NULL) - p->srvSendTime) > 10)
					{
						c2sInnerHeartBeat(p);
					}
				}
			}
			
			if (p->videoConnected == 1 && p->videoSock != -1)
			{
				if (p->videoState != 1)
				{
					if ((int)(time(NULL) - p->videoSendTime) > 3)
					{
						videoInnerLogin(p);
					}
				}
				else
				{
					if ((int)(time(NULL) - p->videoSendTime) > 10)
					{
						videoInnerHeartBeat(p);
					}
				}
			}
			
			if (p->audioSock != -1)
			{
				if (p->audioState != 1)
				{
					if ((int)(time(NULL) - p->audioSendTime) > 3)
					{
						audioInnerLogin(p);
					}
				}
				else
				{
					if ((int)(time(NULL) - p->audioSendTime) > 10)
					{
						audioInnerHeartBeat(p);
					}
				}
			}
			
			if (p->chatState == 1 && p->toAccount != 0)
			{
				if ((time_t)(p->chatLastTime + p->chatTimeout) < time(NULL))
				{
					p->chatLastTime = time(NULL);
					
					uint8_t chatType = p->chatType;
					int64_t toAccount = p->toAccount;

					pause_video();
					p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
					p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
				
					p->toAccount = 0;
					bzero(p->toIp, sizeof(p->toIp));
					p->toPort = 0;
					bzero(p->toLocalIp, sizeof(p->toLocalIp));
					p->toLocalPort = 0;
					p->toState = 0;
				
					if (chatType & P2P_CHAT_TYPE_MASK_VIDEO)
					{
						p2pcallback(EVENT_CLOSED_VIDEO_BY_FRIEND, toAccount, NULL, 0);
					}
					else if (chatType & P2P_CHAT_TYPE_MASK_AUDIO)
					{
						p2pcallback(EVENT_CLOSED_AUDIO_BY_FRIEND, toAccount, NULL, 0);
					}
				}
			}
			
			
		}

		nfds = epoll_wait(p->efd, events, MAXEVENTS, 1000);
		for (i = 0; i < nfds && p->terminate == 0; ++i)         
		{
			if (events[i].data.fd == p->srvSock)
			{
				if (events[i].events&EPOLLIN)
				{
					bzero(&from, sizeof(struct sockaddr_in));
					fromlen = sizeof(struct sockaddr_in);
					nread = recvfrom(p->srvSock, recvBuf, recvMax, 0, (struct sockaddr *) &from, &fromlen);
	
					bzero(recvIp, sizeof(recvIp));
					inet_ntop(AF_INET, &from.sin_addr, recvIp, sizeof(recvIp));
					recvPort = ntohs(from.sin_port);
	
					if (nread > 0) 
					{
						srvRecvTime = time(NULL);
						
						recvLen = nread;
						if (p->myAccount != 0) 
						{
							p2p_proc_data(p, recvIp, recvPort, recvBuf, recvLen);
						}
					}
					else if (nread < 0 && errno != EINTR && errno != EAGAIN) 
					{
						LOGI("p2pThread|srvsock read fail. nread:%d, errno:%d", nread, errno);
	
						close(events[i].data.fd);                    
						epoll_ctl(p->efd, EPOLL_CTL_DEL, events[i].data.fd, &ev);
						p->srvSock = -1;
					}
				}
				else if (events[i].events&EPOLLERR || events[i].events&EPOLLHUP)
				{
					LOGI("p2pThread|srvsock err or hup");
					
					close(events[i].data.fd);                    
					epoll_ctl(p->efd, EPOLL_CTL_DEL, events[i].data.fd, &ev);
					p->srvSock = -1;
				}
			}
			else if (events[i].data.fd == p->videoSock)
			{
				if (events[i].events&EPOLLIN)
				{
					bzero(&from, sizeof(struct sockaddr_in));
					fromlen = sizeof(struct sockaddr_in);
					if (videoLen < 0 || videoLen >= videoMax)
					{
						videoLen = 0;
					}
					nread = recv(p->videoSock, videoBuf+videoLen, videoMax-videoLen, 0);
	
					bzero(recvIp, sizeof(recvIp));
					strncpy(recvIp, p->videoIp, sizeof(recvIp) - 1);
					recvPort = p->videoPort;
	
					if (nread > 0) 
					{
						videoRecvTime = time(NULL);
						
						videoLen += nread;
						while (videoLen >= 2)
						{
							len = htons(*(uint16_t *)videoBuf);
							if (len > P2P_MAX_BUF_SIZE || len < (uint16_t)sizeof(Header))
							{
								videoLen = 0;
								break;
							}
							else if (len > videoLen)
							{
								break;
							}
							else
							{
								if (p->myAccount != 0)
								{
									video_proc_data(p, recvIp, recvPort, videoBuf, len);
								}
								memmove(videoBuf, videoBuf+len, videoLen-len);
								videoLen = videoLen-len;
							}
						}
					}
					else if (nread < 0 && errno != EINTR && errno != EAGAIN) 
					{
						LOGI("p2pThread|videosock read fail. nread:%d, errno:%d", nread, errno);
	
						close(events[i].data.fd);                    
						epoll_ctl(p->efd, EPOLL_CTL_DEL, events[i].data.fd, &ev);
						p->videoSock = -1;
					}
				}
				else if (events[i].events&EPOLLERR || events[i].events&EPOLLHUP)
				{
					LOGI("p2pThread|videosock err or hup");
					
					close(events[i].data.fd);                    
					epoll_ctl(p->efd, EPOLL_CTL_DEL, events[i].data.fd, &ev);
					p->videoSock = -1;
				}
				else if (events[i].events&EPOLLOUT)
				{
					ev.data.fd = events[i].data.fd;                               
					ev.events = EPOLLIN;                               
					if (epoll_ctl(p->efd, EPOLL_CTL_MOD, events[i].data.fd, &ev) != 0)
					{
						LOGI("p2pThread|video connect success but epoll_ctl fail");
						
						close(events[i].data.fd);                    
						epoll_ctl(p->efd, EPOLL_CTL_DEL, events[i].data.fd, &ev);
						p->videoSock = -1;
					}
					else
					{
						LOGI("p2pThread|video connect success");
						
						p->videoConnected = 1;
						if (p->myAccount != 0 && p->videoState != 1)
						{
							videoInnerLogin(p);
						}
						
						p2pcallback(EVENT_VIDEO_CONNECT_SUCC, 0, NULL, 0);
					}
				}
			}
			else if (events[i].data.fd == p->audioSock)
			{
				if (events[i].events&EPOLLIN)
				{
					bzero(&from, sizeof(struct sockaddr_in));
					fromlen = sizeof(struct sockaddr_in);
					nread = recvfrom(p->audioSock, recvBuf, recvMax, 0, (struct sockaddr *) &from, &fromlen);
	
					bzero(recvIp, sizeof(recvIp));
					inet_ntop(AF_INET, &from.sin_addr, recvIp, sizeof(recvIp));
					recvPort = ntohs(from.sin_port);
	
					if (nread > 0) 
					{
						audioRecvTime = time(NULL);
						
						recvLen = nread;
						if (p->myAccount != 0) 
						{
							audio_proc_data(p, recvIp, recvPort, recvBuf, recvLen);
						}
					}
					else if (nread < 0 && errno != EINTR && errno != EAGAIN) 
					{
						LOGI("p2pThread|audiosock read fail. nread:%d, errno:%d", nread, errno);
	
						close(events[i].data.fd);                    
						epoll_ctl(p->efd, EPOLL_CTL_DEL, events[i].data.fd, &ev);
						p->audioSock = -1;
					}
				}
				else if (events[i].events&EPOLLERR || events[i].events&EPOLLHUP)
				{
					LOGI("p2pThread|audiosock err or hup");
					
					close(events[i].data.fd);                    
					epoll_ctl(p->efd, EPOLL_CTL_DEL, events[i].data.fd, &ev);
					p->audioSock = -1;
				}
			}
		}
		

	}
	
	if (p->srvSock != -1) {
		close(p->srvSock);
		p->srvSock = -1;
	}
	
	if (p->videoSock != -1) {
		close(p->videoSock);
		p->videoSock = -1;
	}
	
	if (p->audioSock != -1) {
		close(p->audioSock);
		p->audioSock = -1;
	}

	if (recvBuf) {
		free(recvBuf);
	}
	
	if (videoBuf) {
		free(videoBuf);
	}
	
	(*g_jvm)->DetachCurrentThread(g_jvm);


	LOGI("p2pThread|exit");

	return NULL;
}

void p2p_proc_data(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (recvLen < (uint16_t)sizeof(Header))
	{
		return;
	}
	
	if (strcmp(ip, p->srvIp) == 0 && port == p->srvPort)
	{
		p->srvRecvTime = time(NULL);
	}
	else
	{
		p->toRecvTime = time(NULL);
	}
	
	Header *pHeader = (Header *) (recvBuf);
	uint16_t iCmdId = ntohs(pHeader->CmdId);
	uint16_t iCmdStatus = ntohs(pHeader->CmdStatus);

	if (iCmdId == 0 || iCmdStatus == C2S_ERR_NOTLOGIN) 
	{
		LOGI("p2p_proc_data|ip:%s, port:%u, cmd:%u, status:%u, len:%u|not login", ip, port, iCmdId, iCmdStatus, recvLen);
		
		//p->srvState = 0;
		c2sInnerLogin(p);
		return;
	}

	switch (iCmdId) 
	{
	case C2S_HEART_BEAT_RSP:
		onC2SHeartBeatRsp(p, ip, port, recvBuf, recvLen);
		break;
	case C2S_LOGIN_RSP:
		onC2SLoginRsp(p, ip, port, recvBuf, recvLen);
		break;
	case C2S_HOLE_RSP:
		onC2SGetAccountRsp(p, ip, port, recvBuf, recvLen);
		break;
	case C2S_HOLE_NOTIFY:
		onC2SGetAccountNotify(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_HOLE:
		onC2CHole(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_HOLE_RSP:
		onC2CHoleRsp(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_REQUEST:
		onC2CRequest(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_REQUEST_RSP:
		onC2CRequestRsp(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_CANCEL_REQUEST:
		onC2CCancleRequest(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_CLOSE:
		onC2CClose(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_PAUSE:
		onC2CPause(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_RESUME:
		onC2CResume(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_SWITCH:
		onC2CSwitch(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_VIDEO_FRAME_EX:
		onC2CVideoFrameEx(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_VIDEO_FRAME:
		onC2CVideoFrame(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_AUDIO_FRAME:
		onC2CAudioFrame(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_FILE_FRAME:
		onC2CRecvFileBlock(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_FILE_FRAME_RSP:
		onC2CRecvFileBlockRsp(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_TEXT_FRAME:
		onC2CRecvText(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_HEART_BEAT:
		onC2CHeartBeat(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_HEART_BEAT_RSP:
		onC2CHeartBeatRsp(p, ip, port, recvBuf, recvLen);
		break;
	default:
		break;
	}
}

void video_proc_data(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (recvLen < (uint16_t)sizeof(Header))
	{
		return;
	}
	
	if (strcmp(ip, p->videoIp) == 0 && port == p->videoPort)
	{
		p->videoRecvTime = time(NULL);
	}
	
	Header *pHeader = (Header *) (recvBuf);
	uint16_t iCmdId = ntohs(pHeader->CmdId);
	uint16_t iCmdStatus = ntohs(pHeader->CmdStatus);

	if (iCmdId == 0 || iCmdStatus == C2S_ERR_NOTLOGIN) 
	{
		LOGI("video_proc_data|ip:%s, port:%u, cmd:%u, status:%u, len:%u|not login", ip, port, iCmdId, iCmdStatus, recvLen);
		
		//p->videoState = 0;
		videoInnerLogin(p);
		return;
	}

	switch (iCmdId) 
	{
	case C2S_LOGIN_RSP:
		LOGI("video_proc_data|C2S_LOGIN_RSP");
		p->videoState = 1;
		break;
	case C2C_VIDEO_FRAME:
		onC2CVideoFrame(p, ip, port, recvBuf, recvLen);
		break;
	case C2C_VIDEO_FRAME_EX:
		onC2CVideoFrameEx(p, ip, port, recvBuf, recvLen);
		break;
	default:
		break;
	}
}

void audio_proc_data(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (recvLen < (uint16_t)sizeof(Header))
	{
		return;
	}
	
	if (strcmp(ip, p->audioIp) == 0 && port == p->audioPort)
	{
		p->audioRecvTime = time(NULL);
	}
	
	Header *pHeader = (Header *) (recvBuf);
	uint16_t iCmdId = ntohs(pHeader->CmdId);
	uint16_t iCmdStatus = ntohs(pHeader->CmdStatus);

	if (iCmdId == 0 || iCmdStatus == C2S_ERR_NOTLOGIN) 
	{
		LOGI("audio_proc_data|ip:%s, port:%u, cmd:%u, status:%u, len:%u|not login", ip, port, iCmdId, iCmdStatus, recvLen);
		//p->audioState = 0;
		audioInnerLogin(p);
		return;
	}

	switch (iCmdId) 
	{
	case C2S_LOGIN_RSP:
		LOGI("audio_proc_data|C2S_LOGIN_RSP");
		p->audioState = 1;
		break;
	case C2C_AUDIO_FRAME:
		onC2CAudioFrame(p, ip, port, recvBuf, recvLen);
		break;
	default:
		break;
	}
}

int c2sLogin(int64_t myAccount, const char *myPassword) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	p->chatState = 0;

	p->toAccount = 0;
	bzero(p->toIp, sizeof(p->toIp));
	p->toPort = 0;
	bzero(p->toLocalIp, sizeof(p->toLocalIp));
	p->toLocalPort = 0;
	
	p->toState = 0;
	p->toSendTime = 0;
	p->toRecvTime = time(NULL);
	
	bzero(p->myPassword, sizeof(p->myPassword));
	strncpy(p->myPassword, myPassword, sizeof(p->myPassword) - 1);
	p->srvState = 0;
	p->srvSendTime = 0;
	p->srvRecvTime = time(NULL);

	p->videoState = 0;
	p->videoSendTime = time(NULL);

	p->audioState = 0;
	p->audioSendTime = time(NULL);

	p->myAccount = myAccount;

	return 0;
}

int c2sInnerLogin(p2pnet_t *p)
{
	if (p->srvSock == -1)
	{
		return -1;
	}

	if (p->myAccount == 0) 
	{
		return -1;
	}

	CmdLogin req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	strncpy(req.password, p->myPassword, sizeof(req.password) - 1);
	strncpy(req.localIp, p->myLocalIp, sizeof(req.localIp) - 1);
	req.localPort = p->myLocalPort;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeLogin(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);
	int n = MySendToSrv(p, sendBuf, sendLen, 0, p->srvIp, p->srvPort);
	int ret = sendLen == n ? 0 : -2;

	LOGI("c2sInnerLogin|srvIp:%s, srvPort:%u|myAccount:%lld, myPassword:%s, ret:%d", p->srvIp, p->srvPort, p->myAccount, p->myPassword, ret);

	return ret;
}

int videoInnerLogin(p2pnet_t *p) 
{
	if (p->videoSock == -1) 
	{
		return -1;
	}

	if (p->myAccount == 0) 
	{
		return -1;
	}

	CmdLogin req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	strncpy(req.password, p->myPassword, sizeof(req.password) - 1);
	strncpy(req.localIp, p->myLocalIp, sizeof(req.localIp) - 1);
	req.localPort = p->myLocalPort;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeLogin(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);
	int n = MySendToVideo(p, sendBuf, sendLen, 0, p->videoIp, p->videoPort);
	int ret = (int) sendLen == n ? 0 : -2;

	LOGI("videoInnerLogin|videoIp:%s, videoPort:%u|myAccount:%lld, myPassword:%s, ret:%d", p->videoIp, p->videoPort, p->myAccount, p->myPassword, ret);

	return ret;
}

int audioInnerLogin(p2pnet_t *p) 
{
	if (p->audioSock == -1) 
	{
		return -1;
	}

	if (p->myAccount == 0) 
	{
		return -1;
	}

	CmdLogin req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	strncpy(req.password, p->myPassword, sizeof(req.password) - 1);
	strncpy(req.localIp, p->myLocalIp, sizeof(req.localIp) - 1);
	req.localPort = p->myLocalPort;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeLogin(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);
	int n = MySendToAudio(p, sendBuf, sendLen, 0, p->audioIp, p->audioPort);
	int ret = (int) sendLen == n ? 0 : -2;

	LOGI("audioInnerLogin|audioIp:%s, audioPort:%u|myAccount:%lld, myPassword:%s, ret:%d", p->audioIp, p->audioPort, p->myAccount, p->myPassword, ret);

	return ret;
}

int c2sLogout() 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	p->chatState = 0;

	if (p->myAccount != 0 && p->toAccount != 0)
	{
		if (p->chatType & P2P_CHAT_TYPE_MASK_VIDEO)
		{
			c2cClose(p->myAccount, p->toAccount, P2P_CHAT_TYPE_VIDEO);
		}
		else if (p->chatType & P2P_CHAT_TYPE_MASK_AUDIO)
		{
			c2cClose(p->myAccount, p->toAccount, P2P_CHAT_TYPE_AUDIO);
		}
	}

	int64_t myAccount = p->myAccount;

	pause_video();
	p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
	p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);

	p->myAccount = 0;
	p->srvState = 0;

	p->toAccount = 0;
	bzero(p->toIp, sizeof(p->toIp));
	p->toPort = 0;
	bzero(p->toLocalIp, sizeof(p->toLocalIp));
	p->toLocalPort = 0;
	p->toState = 0;

	p->videoState = 0;
	p->audioState = 0;

	bzero(p->myIp, sizeof(p->myIp));
	p->myPort = 0;
	bzero(p->myLocalIp, sizeof(p->myLocalIp));
	p->myLocalPort = 0;

	CmdLogout req;
	bzero(&req, sizeof(req));
	req.account = myAccount;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeLogout(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);

	if (p->srvSock != -1)
	{
		int n = MySendToSrv(p, sendBuf, sendLen, 0, p->srvIp, p->srvPort);
		int ret = (int) sendLen == n ? 0 : -2;
		LOGI("c2sLogout|srvIp:%s, srvPort:%u|myAccount:%lld, ret:%d", p->srvIp, p->srvPort, myAccount, ret);
	}
	
	if (p->videoSock != -1)
	{
		int n = MySendToVideo(p, sendBuf, sendLen, 0, p->videoIp, p->videoPort);
		int ret = (int) sendLen == n ? 0 : -2;
		LOGI("c2sLogout|videoIp:%s, videoPort:%u|myAccount:%lld, ret:%d", p->videoIp, p->videoPort, myAccount, ret);
	}

	if (p->audioSock != -1)
	{
		int n = MySendToAudio(p, sendBuf, sendLen, 0, p->audioIp, p->audioPort);
		int ret = (int) sendLen == n ? 0 : -2;
		LOGI("c2sLogout|audioIp:%s, audioPort:%u|myAccount:%lld, ret:%d", p->audioIp, p->audioPort, myAccount, ret);
	}

	return 0;
}

int c2sInnerHeartBeat(p2pnet_t *p) 
{
	if (p->srvSock == -1)
	{
		return -1;
	}

	if (p->myAccount == 0) 
	{
		return -1;
	}
	
	CmdHeartBeat req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	strncpy(req.localIp, p->myLocalIp, sizeof(req.localIp) - 1);
	req.localPort = p->myLocalPort;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeHeartBeat(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);
	int n = MySendToSrv(p, sendBuf, sendLen, 0, p->srvIp, p->srvPort);
	int ret = (int) sendLen == n ? 0 : -2;

	return ret;
}

int videoInnerHeartBeat(p2pnet_t *p) 
{
	if (p->videoSock == -1)
	{
		return -1;
	}

	if (p->myAccount == 0) 
	{
		return -1;
	}

	CmdHeartBeat req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	strncpy(req.localIp, p->myLocalIp, sizeof(req.localIp) - 1);
	req.localPort = p->myLocalPort;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeHeartBeat(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);
	int n = MySendToVideo(p, sendBuf, sendLen, 0, p->videoIp, p->videoPort);
	int ret = (int) sendLen == n ? 0 : -2;

	return ret;
}

int audioInnerHeartBeat(p2pnet_t *p) 
{
	if (p->audioSock == -1) 
	{
		return -1;
	}

	if (p->myAccount == 0) 
	{
		return -1;
	}

	CmdHeartBeat req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	strncpy(req.localIp, p->myLocalIp, sizeof(req.localIp) - 1);
	req.localPort = p->myLocalPort;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeHeartBeat(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);
	int n = MySendToAudio(p, sendBuf, sendLen, 0, p->audioIp, p->audioPort);
	int ret = (int) sendLen == n ? 0 : -2;

	return ret;
}

int c2cInnerHole(p2pnet_t *p) 
{
	if (p->srvSock == -1) 
	{
		return -1;
	}

	if (p->myAccount == 0|| p->toAccount == 0 || p->toState == 1) 
	{
		return -1;
	}

	CmdHole req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	req.toAccount = p->toAccount;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeHole(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);

	char *sendIp;
	uint16_t sendPort;
	c2cGetIpAndPort(p, &sendIp, &sendPort);
	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	int ret = (int) sendLen == n ? 0 : -2;

	LOGI("c2cInnerHole|toip:%s, toport:%u|myAccount:%lld, myIp:%s, myPort:%u, toAccount:%lld, toIp:%s, toPort:%u, ret:%d", sendIp, sendPort, p->myAccount, p->myIp, p->myPort, p->toAccount, p->toIp, p->toPort, ret);
	return ret;
}

int c2cInnerHeartBeat(p2pnet_t *p)
{
	if (p->srvSock == -1 || p->toState != 1)
	{
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0) 
	{
		return -1;
	}
	
	if (strlen(p->myIp) == 0 || p->myPort == 0 || strlen(p->myLocalIp) == 0 || p->myLocalPort == 0)
	{
		return -1;
	}
	
	if (strlen(p->toIp) == 0 || p->toPort == 0 || strlen(p->toLocalIp) == 0 || p->toLocalPort == 0)
	{
		return -1;
	}

	CmdC2CHeartBeat req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	strncpy(req.ip, p->myIp, sizeof(req.ip) - 1);
	req.port = p->myPort;
	strncpy(req.localIp, p->myLocalIp, sizeof(req.localIp) - 1);
	req.localPort = p->myLocalPort;
	req.toAccount = p->toAccount;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeC2CHeartBeat(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);

	char *sendIp;
	uint16_t sendPort;
	c2cGetIpAndPort(p, &sendIp, &sendPort);
	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	int ret = (int) sendLen == n ? 0 : -2;

	LOGI("c2cInnerHeartBeat|toip:%s, toport:%u|myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,ret:%d", sendIp, sendPort, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, ret);

	return ret;
}

int c2cInnerRequest(p2pnet_t *p)
{
	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cInnerRequest|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("c2cInnerRequest|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}
	
	CmdRequest req;
	bzero(&req, sizeof(req));
	req.type = p->chatSave;
	req.account = p->myAccount;
	req.toAccount = p->toAccount;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeRequest(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);

	char *sendIp = p->srvIp;
	uint16_t sendPort = p->srvPort;;
	int ret = 0;
	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	ret = (int) sendLen == n ? 0 : -2;

	LOGI("c2cInnerRequest|toip:%s, toport:%u|myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,ret:%d", sendIp, sendPort, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, ret);
	return ret;
}

int c2cAccept(int accept, int type) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cAccept|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("c2cAccept|peer not connect, myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}

	if (accept == 0) 
	{
		c2cInnerHole(p);
		
		if (type == P2P_CHAT_TYPE_VIDEO) 
		{
			p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_VIDEO);
			p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_AUDIO);
			resume_video();
		} 
		else if (type == P2P_CHAT_TYPE_AUDIO) 
		{
			p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
			p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_AUDIO);
			pause_video();
		} 
		else 
		{
			p->chatType = p->chatType | (1 << type);
		}
		
		p->chatState = 1;
		p->chatLastTime = time(NULL);
	}
	else 
	{
		if (type == P2P_CHAT_TYPE_VIDEO) 
		{
			p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
			p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
			pause_video();
		} 
		else if (type == P2P_CHAT_TYPE_AUDIO) 
		{
			p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
			p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
			pause_video();
		} 
		else 
		{
			p->chatType = p->chatType & ~(1 << type);
		}
	}

	CmdRequestRsp rsp;
	bzero(&rsp, sizeof(rsp));
	rsp.type = type;
	rsp.account = p->myAccount;
	rsp.toAccount = p->toAccount;
	rsp.accept = accept;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeRequestRsp(p->srvSendSeq++, 0, &rsp, sendBuf, &sendLen);

	char *sendIp = p->srvIp;
	uint16_t sendPort = p->srvPort;;
	int ret = 0;
	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	ret = (int) sendLen == n ? 0 : -2;

	LOGI("c2cAccept|toip:%s, toport:%u|accept:%d,type:%d,myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,ret:%d", sendIp, sendPort, accept, type, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, ret);

	return ret;
}

int c2cCancelRequest(int64_t myAccount, int64_t toAccount, int type) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	if (type == P2P_CHAT_TYPE_VIDEO) 
	{
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
		pause_video();
	} 
	else if (type == P2P_CHAT_TYPE_AUDIO) 
	{
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
		pause_video();
	} 
	else
	{
		p->chatType = p->chatType & ~(1 << type);
	}

	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cCancelRequest|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0) 
	{
		LOGI("c2cCancelRequest|peer not connect, myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}

	CmdCancelRequest req;
	bzero(&req, sizeof(req));
	req.type = type;
	req.account = myAccount;
	req.toAccount = toAccount;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeCancelRequest(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);

	char *sendIp = p->srvIp;
	uint16_t sendPort = p->srvPort;;
	int ret = 0;
	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	ret = (int) sendLen == n ? 0 : -2;

	LOGI("c2cCancelRequest|toip:%s, toport:%u|type:%d,myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,ret:%d", sendIp, sendPort, type, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, ret);

	return ret;
}

int c2cClose(int64_t myAccount, int64_t toAccount, int type) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;
	
	p->chatState = 0;
	
	pause_video();
	p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
	p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);

	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cClose|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0) 
	{
		LOGI("c2cClose|peer not connect, myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}

	CmdClose req;
	bzero(&req, sizeof(req));
	req.type = type;
	req.account = p->myAccount;
	req.toAccount = p->toAccount;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeClose(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);

	char *sendIp = p->srvIp;
	uint16_t sendPort = p->srvPort;;
	int ret = 0;
	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	ret = (int) sendLen == n ? 0 : -2;

	if (type == P2P_CHAT_TYPE_FILE && p->fileLen > 0)
	{
		p->fileType = 0;
		p->blocks = 0;
		p->bid = 0;
		p->blockTime = 0;
		p->fileLen = 0;
		if (p->fileBuf) 
		{
			free(p->fileBuf);
			p->fileName = NULL;
		}
		if (p->fileName) 
		{
			free(p->fileName);
			p->fileName = NULL;
		}
	}
	
	p->toAccount = 0;
	bzero(p->toIp, sizeof(p->toIp));
	p->toPort = 0;
	bzero(p->toLocalIp, sizeof(p->toLocalIp));
	p->toLocalPort = 0;
	p->toState = 0;
	
	LOGI("c2cClose|toip:%s, toport:%u|type:%d,myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,ret:%d", sendIp, sendPort, type, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, ret);
	return ret;
}

int c2cPause(int64_t myAccount, int64_t toAccount, int type) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	if (type == P2P_CHAT_TYPE_VIDEO) 
	{
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
		pause_video();
	} 
	else if (type == P2P_CHAT_TYPE_AUDIO) 
	{
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
	} 
	else 
	{
		p->chatType = p->chatType & ~(1 << type);
	}

	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cPause|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0) 
	{
		LOGI("c2cPause|peer not connect, myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}

	CmdPause req;
	bzero(&req, sizeof(req));
	req.type = type;
	req.account = p->myAccount;
	req.toAccount = p->toAccount;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodePause(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);

	char *sendIp = p->srvIp;
	uint16_t sendPort = p->srvPort;;
	int ret = 0;
	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	ret = (int) sendLen == n ? 0 : -2;

	LOGI("c2cPause|toip:%s, toport:%u|type:%d,myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,ret:%d", sendIp, sendPort, type, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, ret);

	return ret;
}

int c2cResume(int64_t myAccount, int64_t toAccount, int type) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cResume|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0) 
	{
		LOGI("c2cResume|peer not connect, myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}

	if (type == P2P_CHAT_TYPE_VIDEO) 
	{
		p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_VIDEO);
		p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_AUDIO);
		resume_video();
	} 
	else if (type == P2P_CHAT_TYPE_AUDIO) 
	{
		p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_AUDIO);
	} 
	else 
	{
		p->chatType = p->chatType | (1 << type);
	}

	CmdResume req;
	bzero(&req, sizeof(req));
	req.type = type;
	req.account = p->myAccount;
	req.toAccount = p->toAccount;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeResume(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);

	char *sendIp = p->srvIp;
	uint16_t sendPort = p->srvPort;;
	int ret = 0;
	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	ret = (int) sendLen == n ? 0 : -2;

	LOGI("c2cResume|toip:%s, toport:%u|type:%d,myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,ret:%d", sendIp, sendPort, type, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, ret);

	return ret;
}

int c2cSwitch(int64_t myAccount, int64_t toAccount, int type) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cSwitch|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0) 
	{
		LOGI("c2cSwitch|peer not connect, myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}

	if (type == P2P_CHAT_TYPE_VIDEO) 
	{
		p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_VIDEO);
		p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_AUDIO);
		resume_video();
	} 
	else if (type == P2P_CHAT_TYPE_AUDIO) 
	{
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
		p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_AUDIO);
		pause_video();
	}

	CmdSwitch req;
	bzero(&req, sizeof(req));
	req.type = type;
	req.account = p->myAccount;
	req.toAccount = p->toAccount;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeSwitch(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);

	char *sendIp = p->srvIp;
	uint16_t sendPort = p->srvPort;;
	int ret = 0;
	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	ret = (int) sendLen == n ? 0 : -2;

	LOGI("c2cSwitch|toip:%s, toport:%u|type:%d,myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,ret:%d", sendIp, sendPort, type, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, ret);

	return ret;
}

int c2cVideoFrame(int64_t fid, int packs, int pid, int fLen,
		unsigned char *frame, int len, int width, int height, int fps,
		int bitrate, int angle, int mirror) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	if (p->chatState != 1)
	{
		LOGI("c2cVideoFrame|not chatState");
		return -1;
	}

	if (isTerminated()) 
	{
		LOGI("c2cVideoFrame|isTerminated");
		return -1;
	}

	if (video_paused()) 
	{
		LOGI("c2cVideoFrame|paused");
		return -1;
	}

	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cVideoFrame|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0) 
	{
		LOGI("c2cVideoFrame|peer not connect, myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}

	if (!(p->chatType & P2P_CHAT_TYPE_MASK_VIDEO)) 
	{
		LOGI("c2cVideoFrame|invalid chatType:%d", p->chatType);
		return -1;
	}

	CmdVideoFrame req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	req.toAccount = p->toAccount;
	req.width = width;
	req.height = height;
	req.fps = fps;
	req.bitrate = bitrate;
	req.angle = angle;
	req.mirror = mirror;

	req.frameID = fid;
	req.frameLen = fLen;
	req.packs = packs;
	req.pid = pid;
	req.packLen = len;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	int ret = encodeVideoFrame(p->srvSendSeq++, 0, &req, frame, len, sendBuf, &sendLen);
	if (ret != 0)
	{
		LOGI("c2cVideoFrame|encodeVideoFrame fail");
		return -1;
	}

	char *sendIp = p->toIp;
	uint16_t sendPort = p->toPort;
	if (p->srvSock != -1 && p->toState == 1 && p->isTcp == 0)
	{
		c2cGetIpAndPort(p, &sendIp, &sendPort);
		int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
		ret = (int) sendLen == n ? 0 : -2;
	}
	else if (p->videoSock != -1 && p->videoConnected == 1 && p->videoState == 1)
	{
		sendIp = p->videoIp;
		sendPort = p->videoPort;

		int n = MySendToVideo(p, sendBuf, sendLen, 0, sendIp, sendPort);
		ret = (int) sendLen == n ? 0 : -2;
	}
	else
	{
		ret = -3;
	}

	if (ret != 0)
	{
		LOGI("c2cVideoFrame|toip:%s, toport:%u|size:%d,myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,ret:%d", sendIp, sendPort, sendLen,p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort,ret);
	}

	return ret;
}

int c2cVideoFrameEx(unsigned char *frame, int len, int width, int height, int fps,
		int bitrate, int angle, int mirror) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	if (p->chatState != 1)
	{
		LOGI("c2cVideoFrameEx|not chatState");
		return -1;
	}

	if (isTerminated()) 
	{
		LOGI("c2cVideoFrameEx|isTerminated");
		return -1;
	}

	if (video_paused()) 
	{
		LOGI("c2cVideoFrameEx|paused");
		return -1;
	}
	
	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cVideoFrameEx|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0) 
	{
		LOGI("c2cVideoFrameEx|peer not connect, myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}

	if (!(p->chatType & P2P_CHAT_TYPE_MASK_VIDEO)) 
	{
		LOGI("c2cVideoFrameEx|invalid chatType,  not accepted. myAccount:%lld, toAccount:%lld, chatType:%d", p->myAccount, p->toAccount, p->chatType);
		return -1;
	}

	CmdVideoFrameEx req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	req.toAccount = p->toAccount;
	req.width = width;
	req.height = height;
	req.fps = fps;
	req.bitrate = bitrate;
	req.angle = angle;
	req.mirror = mirror;

	char *sendBuf = (char *)malloc(P2P_MAX_BUF_SIZE);
	if (!sendBuf)
	{
		LOGI("c2cVideoFrameEx|malloc fail");
		return -1;
	}
	
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	int ret = encodeVideoFrameEx(0, 0, &req, frame, len, sendBuf, &sendLen);
	if (ret != 0)
	{
		LOGI("c2cVideoFrameEx|encodeVideoFrameEx fail");
		return -1;
	}

	char *sendIp = p->toIp;
	uint16_t sendPort = p->toPort;
	if (p->srvSock != -1 && p->toState == 1 && p->isTcp == 0)
	{
		c2cGetIpAndPort(p, &sendIp, &sendPort);
		int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
		ret = (int) sendLen == n ? 0 : -2;
	}
	else if (p->videoSock != -1 && p->videoConnected == 1 && p->videoState == 1)
	{
		sendIp = p->videoIp;
		sendPort = p->videoPort;

		int n = MySendToVideo(p, sendBuf, sendLen, 0, sendIp, sendPort);
		ret = (int) sendLen == n ? 0 : -2;
	}
	else
	{
		ret = -3;
	}
	
	if (ret != 0)
	{
		LOGI("c2cVideoFrameEx|toip:%s, toport:%u|size:%d,myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,ret:%d", sendIp, sendPort, sendLen,p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort,ret);
	}

	free(sendBuf);
	return ret;
}

int c2cAudioFrame(unsigned char *frame, int len)
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	if (p->chatState != 1)
	{
		LOGI("c2cAudioFrame|not chatState");
		return -1;
	}

	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cAudioFrame|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0) 
	{
		LOGI("c2cAudioFrame|peer not connect, myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}

	if (!(p->chatType & P2P_CHAT_TYPE_MASK_AUDIO)) 
	{
		LOGI("c2cAudioFrame|invalid chatType. myAccount:%lld, toAccount:%lld, chatType:%d", p->myAccount, p->toAccount, p->chatType);
		return -1;
	}

	CmdAudioFrame req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	req.toAccount = p->toAccount;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	int ret = encodeAudioFrame(p->srvSendSeq++, 0, &req, frame, len, sendBuf, &sendLen);
	if (ret != 0)
	{
		LOGI("c2cAudioFrame|encodeAudioFrame fail");
		return -1;
	}
	
	char *sendIp = p->toIp;
	uint16_t sendPort = p->toPort;
	
	if (p->srvSock != -1 && p->toState == 1 && p->isTcp == 0)
	{
		c2cGetIpAndPort(p, &sendIp, &sendPort);
		int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
		ret = (int) sendLen == n ? 0 : -2;
	}
	else if (p->audioSock != -1 && p->audioState == 1)
	{
		sendIp = p->audioIp;
		sendPort = p->audioPort;

		int n = MySendToAudio(p, sendBuf, sendLen, 0, sendIp, sendPort);
		ret = (int) sendLen == n ? 0 : -2;
	}
	else
	{
		ret = -3;
	}

	if (ret != 0)
	{
		LOGI("c2cAudioFrame|toip:%s, toport:%u|myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,ret:%d", sendIp, sendPort, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort,ret);
	}
	
	return ret;
}

int c2cSendText(unsigned char *text) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cSendText|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0) 
	{
		LOGI("c2cSendText|peer not connect, myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}

	CmdText req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	req.toAccount = p->toAccount;
	req.len = strlen(text);

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	int ret = encodeText(p->srvSendSeq++, 0, &req, text, strlen(text), sendBuf, &sendLen);
	if (ret != 0)
	{
		LOGI("c2cSendText|encodeText fail");
		return -1;
	}
	
	char *sendIp = p->srvIp;
	uint16_t sendPort = p->srvPort;;
	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	ret = (int) sendLen == n ? 0 : -2;
	if (ret != 0)
	{
		LOGI("c2cSendText|toip:%s, toport:%u|myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,text:%s,len:%d,ret:%d", sendIp, sendPort, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, text, req.len, ret);
	}

	return ret;
}

int c2cSendFile(unsigned char *content, char *name, int type, int len) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cSendFile|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0) 
	{
		LOGI("c2cSendFile|peer not connect, myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}

	if (p->fileBuf) 
	{
		free(p->fileBuf);
		p->fileBuf = NULL;
	}
	if (p->fileName) 
	{
		free(p->fileName);
		p->fileName = NULL;
	}
	p->fileBuf = (uint8_t *) malloc(len);
	p->fileName = (uint8_t *) malloc(64);
	memcpy(p->fileBuf, content, len);
	memcpy(p->fileName, name, 64);
	p->fileLen = len;
	p->fileType = type;
	p->bid = 0;
	p->blocks = len % P2P_MAX_BUF_SIZE / 2 == 0 ? len / (P2P_MAX_BUF_SIZE / 2) : len / (P2P_MAX_BUF_SIZE / 2) + 1;
	c2cSendFileBlock(0);
}

int c2cSendFileBlock(int bid) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;

	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2cSendFileBlock|not login");
		return -1;
	}

	if (p->myAccount == 0 || p->toAccount == 0) 
	{
		LOGI("c2cSendFileBlock|peer not connect, myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return -1;
	}

	int len = p->fileLen - p->bid * (P2P_MAX_BUF_SIZE / 2);
	len = len < P2P_MAX_BUF_SIZE / 2 ? len : P2P_MAX_BUF_SIZE / 2;
	uint8_t * block = (uint8_t *) malloc(len);
	if (!block) return -1;
	memcpy(block, p->fileBuf + p->bid * (P2P_MAX_BUF_SIZE / 2), len);

	CmdFileBlock req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	req.toAccount = p->toAccount;
	req.blocks = p->blocks;
	req.bid = bid;
	req.len = p->fileLen;
	memcpy(&req.name, p->fileName, 64);

	p->toSendTime = time(NULL);
	p->blockTime = time(NULL);

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	int ret = encodeFileBlock(p->srvSendSeq++, 0, &req, block, len, sendBuf, &sendLen);
	if (ret != 0)
	{
		LOGI("c2cSendFileBlock|encodeFileBlock fail");
		free(block);
		return -1;
	}

	char *sendIp = p->srvIp;
	uint16_t sendPort = p->srvPort;

	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	ret = (int) sendLen == n ? 0 : -2;
	
	if (ret != 0)
	{
		LOGI("c2cSendFileBlock|toip:%s, toport:%u|bid:%d,myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,ret:%d", sendIp, sendPort, bid, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, ret);
	}

	free(block);
	block = NULL;

	return ret;
}

void c2cGetIpAndPort(p2pnet_t *p, char **pIp, uint16_t *pPort) 
{
	int ret = 0;
	if (strcmp(p->myIp, p->toIp) == 0)
	{
		*pIp = p->toLocalIp;
		*pPort = p->toLocalPort;
		ret = 1;
	} 
	else 
	{
		*pIp = p->toIp;
		*pPort = p->toPort;
		ret = 2;
	}
	//LOGI("c2cGetIpAndPort ip:%s, port:%u, ret:%d", *pIp, *pPort, ret);
}

void c2cSetIpAndPort(p2pnet_t *p, char *ip, uint16_t port) 
{
	int ret = 0;

	if (ip == NULL || strcmp(ip, "0.0.0.0") == 0 || strcmp(ip, "127.0.0.1") == 0 || port == 0) 
	{
		return;
	}

	if (strcmp(p->myIp, p->toIp) == 0) 
	{
		if (strcmp(p->toLocalIp, ip) != 0 || p->toLocalPort != port) 
		{
			bzero(p->toLocalIp, sizeof(p->toLocalIp));
			strncpy(p->toLocalIp, ip, sizeof(p->toLocalIp) - 1);
			p->toLocalPort = port;
			ret = 1;
		}
	} 
	else 
	{
		if (strcmp(p->toIp, ip) != 0 || p->toPort != port) 
		{
			bzero(p->toIp, sizeof(p->toIp));
			strncpy(p->toIp, ip, sizeof(p->toIp) - 1);
			p->toPort = port;
			ret = 2;
		}
	}
	LOGI("c2cSetIpAndPort ip:%s, port:%u, ret:%d", ip, port, ret);
}

void onC2SLoginRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0)
	{
		LOGI("onC2SLoginRsp|invalid myAccount");
		return;
	}

	Header header;
	CmdLoginRsp rsp;
	int ret = decodeLoginRsp(recvBuf, recvLen, &header, &rsp);
	if (ret != 0) 
	{
		LOGI("onC2SLoginRsp|decode fail");
		return;
	}
	
	if (rsp.account != p->myAccount)
	{
		LOGI("onC2SLoginRsp|invalid account:%lld, myAccount:%lld", rsp.account, p->myAccount);
		return;
	}
	
	if (header.CmdStatus != 0)
	{
		LOGI("onC2SLoginRsp|not login");
		p->srvState = 0;
		return;
	}
	
	bzero(p->myIp, sizeof(p->myIp));
	strncpy(p->myIp, rsp.ip, sizeof(p->myIp) - 1);
	p->myPort = rsp.port;
	
	if (p->srvState != 1)
	{
		p->srvState = 1;
		p2pcallback(EVENT_P2S_CONNECT, p->myAccount, NULL, 0);
	}

	c2sInnerHeartBeat(p);

	LOGI("onC2SLoginRsp|fromip:%s, fromport:%u|myAccount:%lld, myIp:%s, myPort:%u, myLocalIp:%s, myLocalPort:%u", ip, port, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort);
}

void onC2SHeartBeatRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0)
	{
		LOGI("onC2SHeartBeatRsp|invalid myAccount");
		return;
	}
	
	Header header;
	CmdHeartBeatRsp rsp;
	int ret = decodeHeartBeatRsp(recvBuf, recvLen, &header, &rsp);
	if (ret != 0) 
	{
		LOGI("onC2SHeartBeatRsp|decode fail");
		return;
	}
	
	if (rsp.account != p->myAccount)
	{
		LOGI("onC2SHeartBeatRsp|invalid account:%lld, myAccount:%lld", rsp.account, p->myAccount);
		return;
	}
	
	if (header.CmdStatus != 0)
	{
		LOGI("onC2SLoginRsp|not login");
		p->srvState = 0;
		return;
	}
	
	if ((int) strlen(rsp.ip) < (int) sizeof(p->myIp) && (strcmp(p->myIp, rsp.ip) != 0 || p->myPort != rsp.port)) 
	{
		strncpy(p->myIp, rsp.ip, sizeof(p->myIp) - 1);
		p->myIp[strlen(rsp.ip)] = 0;
		p->myPort = rsp.port;
	}
	if ((int) strlen(rsp.localIp) < (int) sizeof(p->myLocalIp) && (strcmp(p->myLocalIp, rsp.localIp) != 0 || p->myLocalPort != rsp.localPort)) 
	{
		strncpy(p->myLocalIp, rsp.localIp, sizeof(p->myLocalIp) - 1);
		p->myLocalIp[strlen(rsp.localIp)] = 0;
		p->myLocalPort = rsp.localPort;
	}
	
	if (p->srvState != 1) 
	{
		p->srvState = 1;
		p2pcallback(EVENT_P2S_CONNECT, p->myAccount, NULL, 0);
	}
}

void onC2CHole(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CHole|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	Header header;
	CmdHole req;
	int ret = decodeHole(recvBuf, recvLen, &header, &req);
	if (ret != 0) 
	{
		LOGI("onC2CHole|decode fail");
		return;
	}

	if (req.toAccount != p->myAccount || req.account != p->toAccount) 
	{
		LOGI("onC2CHole|fromip:%s, fromport:%u|invalid account. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, req.toAccount, p->toAccount, req.account);
		return;
	}

	c2cSetIpAndPort(p, ip, port);

	CmdHoleRsp rsp;
	bzero(&rsp, sizeof(rsp));
	rsp.account = p->myAccount;
	rsp.toAccount = p->toAccount;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeHoleRsp(header.SeqId, 0, &rsp, sendBuf, &sendLen);
	int n = MySendToSrv(p, sendBuf, sendLen, 0, ip, port);
	ret = sendLen == n ? 0 : -2;

	LOGI("onC2CHole|fromip:%s, fromport:%u|myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u, ret:%d", ip, port, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, ret);
	
	if (p->toState != 1) 
	{
		LOGI("onC2CHoleRsp|fromip:%s, fromport:%u|myAccount:%lld, toAccount:%lld, myIp:%s, myPort:%u, myLocalIp:%s, myLocalPort:%u, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u|p2p succ", ip, port, p->myAccount, p->toAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort);
		
		p->toState = 1;
		p2pcallback(EVENT_P2P_CONNECT, p->toAccount, NULL, 0);
	}
	else
	{
		LOGI("onC2CHoleRsp|fromip:%s, fromport:%u|myAccount:%lld, toAccount:%lld, myIp:%s, myPort:%u, myLocalIp:%s, myLocalPort:%u, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u", ip, port, p->myAccount, p->toAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort);
	}
}

void onC2CHoleRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CHoleRsp|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	Header header;
	CmdHoleRsp rsp;
	int ret = decodeHoleRsp(recvBuf, recvLen, &header, &rsp);
	if (ret != 0) 
	{
		LOGI("onC2CHoleRsp|decode fail");
		return;
	}

	if (rsp.toAccount != p->myAccount || rsp.account != p->toAccount) 
	{
		LOGI("onC2CHoleRsp|fromip:%s, fromport:%u|invalid account. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, rsp.toAccount, p->toAccount, rsp.account);
		return;
	}
	
	c2cSetIpAndPort(p, ip, port);

	if (p->toState != 1) 
	{
		LOGI("onC2CHoleRsp|fromip:%s, fromport:%u|myAccount:%lld, toAccount:%lld, myIp:%s, myPort:%u, myLocalIp:%s, myLocalPort:%u, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u|p2p succ", ip, port, p->myAccount, p->toAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort);
		
		p->toState = 1;
		p2pcallback(EVENT_P2P_CONNECT, p->toAccount, NULL, 0);
	}
	else
	{
		LOGI("onC2CHoleRsp|fromip:%s, fromport:%u|myAccount:%lld, toAccount:%lld, myIp:%s, myPort:%u, myLocalIp:%s, myLocalPort:%u, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u", ip, port, p->myAccount, p->toAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort);
	}
}

void onC2CRequest(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CRequest|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	Header header;
	CmdRequest req;
	int ret = decodeRequest(recvBuf, recvLen, &header, &req);
	if (ret != 0) 
	{
		LOGI("onC2CRequest|decode fail");
		return;
	}

	if (req.toAccount != p->myAccount || req.account != p->toAccount) 
	{
		LOGI("onC2CRequest|fromip:%s, fromport:%u|invalid account. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, req.toAccount, p->toAccount, req.account);
		return;
	}

	LOGI("onC2CRequest|fromip:%s, fromport:%u|myAccount:%lld, myIp:%s, myPort:%u, toAccount:%lld, toIp:%s, toPort:%u,type:%d", ip, port, p->myAccount, p->myIp, p->myPort, p->toAccount, p->toIp, p->toPort, req.type);

	c2cInnerHole(p);

	if (req.type == P2P_CHAT_TYPE_AUDIO) 
	{
		p2pcallback(EVENT_REQUEST_AUDIO_BY_FRIEND, p->toAccount, NULL, 0);
	} 
	else if (req.type == P2P_CHAT_TYPE_VIDEO) 
	{
		p2pcallback(EVENT_REQUEST_VIDEO_BY_FRIEND, p->toAccount, NULL, 0);
	} 
	else if (req.type == P2P_CHAT_TYPE_FILE) 
	{
		p2pcallback(EVENT_REQUEST_FILE_BY_FRIEND, p->toAccount, NULL, 0);
	}
}

void onC2CRequestRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CRequestRsp|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	Header header;
	CmdRequestRsp rsp;
	int ret = decodeRequestRsp(recvBuf, recvLen, &header, &rsp);
	if (ret != 0) 
	{
		LOGI("onC2CRequestRsp|decode fail");
		return;
	}

	if (rsp.toAccount != p->myAccount || rsp.account != p->toAccount) 
	{
		LOGI("onC2CRequestRsp|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, rsp.toAccount, p->toAccount, rsp.account);
		return;
	}

	if (rsp.accept == 0) 
	{
		LOGI("onC2CRequestRsp|fromip:%s, fromport:%u|accept,type:%d,myAccount:%lld, myIp:%s, myPort:%u, toAccount:%lld, toIp:%s, toPort:%u, type:%u", ip, port, rsp.type, p->myAccount, p->myIp, p->myPort, p->toAccount, p->toIp, p->toPort, rsp.type);

		c2cInnerHole(p);

		if (rsp.type == P2P_CHAT_TYPE_VIDEO) 
		{
			p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_VIDEO);
			p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_AUDIO);
			resume_video();
			p2pcallback(EVENT_ACCEPT_VIDEO_BY_FRIEND, p->toAccount, NULL, 0);
		} 
		else if (rsp.type == P2P_CHAT_TYPE_AUDIO) 
		{
			p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
			p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_AUDIO);
			pause_video();
			p2pcallback(EVENT_ACCEPT_AUDIO_BY_FRIEND, p->toAccount, NULL, 0);
		} 
		else if (rsp.type == P2P_CHAT_TYPE_FILE) 
		{
			p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_FILE);
			p2pcallback(EVENT_ACCEPT_FILE_BY_FRIEND, p->toAccount, NULL, 0);
		}
		
		p->chatState = 1;
		p->chatLastTime = time(NULL);
	}
	else 
	{
		LOGI("onC2CRequestRsp|fromip:%s, fromport:%u|reject,type:%d myAccount:%lld, myIp:%s, myPort:%u, toAccount:%lld, toIp:%s, toPort:%u, type:%u", ip, port, rsp.type, p->myAccount, p->myIp, p->myPort, p->toAccount, p->toIp, p->toPort, rsp.type);

		if (rsp.type == P2P_CHAT_TYPE_VIDEO) 
		{
			pause_video();
			p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
			p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
			p2pcallback(EVENT_REJECT_AUDIO_BY_FRIEND, p->toAccount, NULL, 0);
		} 
		else if (rsp.type == P2P_CHAT_TYPE_AUDIO) 
		{
			pause_video();
			p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
			p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
			p2pcallback(EVENT_REJECT_VIDEO_BY_FRIEND, p->toAccount, NULL, 0);
		} 
		else if (rsp.type == P2P_CHAT_TYPE_FILE) 
		{
			p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_FILE);
			p2pcallback(EVENT_REJECT_FILE_BY_FRIEND, p->toAccount, NULL, 0);
		}
	}
}

void onC2CCancleRequest(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CCancleRequest|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	Header header;
	CmdCancelRequest req;
	int ret = decodeCancelRequest(recvBuf, recvLen, &header, &req);
	if (ret != 0) 
	{
		LOGI("onC2CCancleRequest|decode fail");
		return;
	}

	if (req.toAccount != p->myAccount || req.account != p->toAccount) 
	{
		LOGI("onC2CCancleRequest|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, req.toAccount, p->toAccount, req.account);
		return;
	}

	LOGI("onC2CCancleRequest|fromip:%s, fromport:%u|myAccount:%lld, myIp:%s, myPort:%u, toAccount:%lld, toIp:%s, toPort:%u, type:%u", ip, port, p->myAccount, p->myIp, p->myPort, p->toAccount, p->toIp, p->toPort, req.type);

	if (req.type == P2P_CHAT_TYPE_VIDEO) 
	{
		pause_video();
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
		p2pcallback(EVENT_CANCEL_REQUEST_VIDEO_BY_FRIEND, p->toAccount, NULL, 0);
	} 
	else if (req.type == P2P_CHAT_TYPE_AUDIO) 
	{
		pause_video();
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
		p2pcallback(EVENT_CANCEL_REQUEST_AUDIO_BY_FRIEND, p->toAccount, NULL, 0);
	} 
	else if (req.type == P2P_CHAT_TYPE_FILE) 
	{
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_FILE);
		p2pcallback(EVENT_CANCEL_REQUEST_FILE_BY_FRIEND, p->toAccount, NULL, 0);
	}
}

void onC2CClose(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	p->chatState = 0;
	
	uint8_t chatType = p->chatType;
	int64_t toAccount = p->toAccount;
			
	pause_video();
	p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
	p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);

	p->toAccount = 0;
	bzero(p->toIp, sizeof(p->toIp));
	p->toPort = 0;
	bzero(p->toLocalIp, sizeof(p->toLocalIp));
	p->toLocalPort = 0;
	p->toState = 0;

	if (toAccount != 0)
	{
		if (chatType & P2P_CHAT_TYPE_MASK_VIDEO)
		{
			p2pcallback(EVENT_CLOSED_VIDEO_BY_FRIEND, toAccount, NULL, 0);
		}
		else if (chatType & P2P_CHAT_TYPE_MASK_AUDIO)
		{
			p2pcallback(EVENT_CLOSED_AUDIO_BY_FRIEND, toAccount, NULL, 0);
		}
	}

	LOGI("onC2CClose|fromip:%s, fromport:%u|myAccount:%lld, myIp:%s, myPort:%u", ip, port, p->myAccount, p->myIp, p->myPort);
}

void onC2CPause(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CPause|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	Header header;
	CmdPause req;
	int ret = decodePause(recvBuf, recvLen, &header, &req);
	if (ret != 0) 
	{
		LOGI("onC2CPause|decode fail");
		return;
	}

	if (req.toAccount != p->myAccount || req.account != p->toAccount) 
	{
		LOGI("onC2CPause|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, req.toAccount, p->toAccount, req.account);
		return;
	}

	LOGI("onC2CPause|fromip:%s, fromport:%u|myAccount:%lld, myIp:%s, myPort:%u, toAccount:%lld, toIp:%s, toPort:%u, type:%u", ip, port, p->myAccount, p->myIp, p->myPort, p->toAccount, p->toIp, p->toPort, req.type);

	if (req.type == P2P_CHAT_TYPE_VIDEO) 
	{
		pause_video();
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
		p2pcallback(EVENT_PAUSE_VIDEO_BY_FRIEND, p->toAccount, NULL, 0);
	} 
	else if (req.type == P2P_CHAT_TYPE_AUDIO) 
	{
		p2pcallback(EVENT_PAUSE_AUDIO_BY_FRIEND, p->toAccount, NULL, 0);
	}
}

void onC2CResume(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CResume|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	Header header;
	CmdResume req;
	int ret = decodeResume(recvBuf, recvLen, &header, &req);
	if (ret != 0) 
	{
		LOGI("onC2CResume|decode fail");
		return;
	}

	if (req.toAccount != p->myAccount || req.account != p->toAccount) 
	{
		LOGI("onC2CResume|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, req.toAccount, p->toAccount, req.account);
		return;
	}

	LOGI("onC2CResume|fromip:%s, fromport:%u|myAccount:%lld, myIp:%s, myPort:%u, toAccount:%lld, toIp:%s, toPort:%u, type:%u", ip, port, p->myAccount, p->myIp, p->myPort, p->toAccount, p->toIp, p->toPort, req.type);

	if (req.type == P2P_CHAT_TYPE_VIDEO) 
	{
		p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_VIDEO);
		p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_AUDIO);
		resume_video();
		p2pcallback(EVENT_RESUME_VIDEO_BY_FRIEND, p->toAccount, NULL, 0);
	} 
	else if (req.type == P2P_CHAT_TYPE_AUDIO) 
	{
		p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_AUDIO);
		p2pcallback(EVENT_RESUME_AUDIO_BY_FRIEND, p->toAccount, NULL, 0);
	}
}

void onC2CSwitch(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CSwitch|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	Header header;
	CmdSwitch req;
	int ret = decodeSwitch(recvBuf, recvLen, &header, &req);
	if (ret != 0) 
	{
		LOGI("onC2CSwitch|decode fail");
		return;
	}

	if (req.toAccount != p->myAccount || req.account != p->toAccount) 
	{
		LOGI("onC2CSwitch|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, req.toAccount, p->toAccount, req.account);
		return;
	}

	LOGI("onC2CSwitch|fromip:%s, fromport:%u|myAccount:%lld, myIp:%s, myPort:%u, toAccount:%lld, toIp:%s, toPort:%u, type:%u", ip, port, p->myAccount, p->myIp, p->myPort, p->toAccount, p->toIp, p->toPort, req.type);

	if (req.type == P2P_CHAT_TYPE_VIDEO) 
	{
		p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_VIDEO);
		p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_AUDIO);
		resume_video();
		p2pcallback(EVENT_P2S_SWITCH_VIDEO, p->toAccount, NULL, 0);
	} 
	else if (req.type == P2P_CHAT_TYPE_AUDIO) 
	{
		p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
		p->chatType = p->chatType | (1 << P2P_CHAT_TYPE_AUDIO);
		pause_video();
		p2pcallback(EVENT_P2S_SWITCH_AUDIO, p->toAccount, NULL, 0);
	}
}

void onC2CVideoFrame(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	p->chatLastTime = time(NULL);
	
	if (p->chatState != 1)
	{
		LOGI("onC2CVideoFrame|not chatState");
		return;
	}
	
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CVideoFrame|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	if (!(p->chatType & P2P_CHAT_TYPE_MASK_VIDEO)) 
	{
		LOGI("onC2CVideoFrame|not video state");
		p->frameID = 0;
		p->videoLen = 0;
		return;
	}

	if (isTerminated()) 
	{
		LOGI("onC2CVideoFrame|terminated");
		p->frameID = 0;
		p->videoLen = 0;
		return;
	}

	if (video_paused()) 
	{
		LOGI("onC2CVideoFrame|paused");
		p->frameID = 0;
		p->videoLen = 0;
		return;
	}

	Header header;
	CmdVideoFrame req;

	uint16_t swapLen = P2P_MAX_BUF_SIZE;
	int ret = decodeVideoFrame(recvBuf, recvLen, &header, &req, p->swapBuf, &swapLen);
	if (ret != 0) 
	{
		LOGI("onC2CVideoFrame|decode fail");
		p->frameID = 0;
		p->videoLen = 0;
		return;
	}

	if (req.toAccount != p->myAccount || req.account != p->toAccount) 
	{
		LOGI("onC2CVideoFrame|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, req.toAccount, p->toAccount, req.account);
		p->frameID = 0;
		p->videoLen = 0;
		return;
	}

	int packs = req.packs;
	int pid = req.pid;
	int fLen = req.frameLen;
	int packLen = req.packLen;

	if (packLen > P2P_VIDEO_SLICE_SIZE) 
	{
		LOGI("onC2CVideoFrame|invalid. frameId:%llu, packNum:%d, packId:%d, packLen:%d, frameLen:%d", req.frameID, packs, pid, packLen, fLen);
		p->frameID = 0;
		p->videoLen = 0;
		return;
	}

	if (p->frameID == req.frameID)
	{
		p->videoLen += packLen;
	}
	else
	{
		p->frameID = req.frameID;
		p->videoLen = packLen;
	}

	if ((int) (pid * P2P_VIDEO_SLICE_SIZE + packLen) > (int) (P2P_MAX_BUF_SIZE))
	{
		LOGI("onC2CVideoFrame|too long. fid:%llu,packs:%d, pid:%d, len:%d,packLen:%d", req.frameID, packs, pid, fLen, packLen);
		p->frameID = 0;
		p->videoLen = 0;
		return;
	}
	
	memcpy(p->videoBuf + pid * P2P_VIDEO_SLICE_SIZE, p->swapBuf, packLen);

	if (fLen < 0 || fLen > (int) (P2P_MAX_BUF_SIZE))
	{
		LOGI("onC2CVideoFrame|invalid fLen:%d", fLen);
		p->frameID = 0;
		p->videoLen = 0;
		return;
	}
	else if (fLen > p->videoLen)
	{
		LOGI("onC2CVideoFrame|fromip:%s, fromport:%u|frameId:[%llu, %llu], packNum:%d, packId:%d, packLen:%d, frameLen:%d, videoLen:%d|not enough", ip, port, p->frameID, req.frameID, packs, pid, packLen, fLen, p->videoLen);
		return;
	}
	else if (fLen < p->videoLen)
	{
		LOGI("onC2CVideoFrame|fromip:%s, fromport:%u|frameId:[%llu, %llu], packNum:%d, packId:%d, packLen:%d, frameLen:%d, videoLen:%d|ignore", ip, port, p->frameID, req.frameID, packs, pid, packLen, fLen, p->videoLen);
		p->frameID = 0;
		p->videoLen = 0;
		return;
	}
	
	video_buffer_t buffer;
	buffer.buf = p->videoBuf;
	buffer.size = fLen;
	buffer.len = fLen;
	buffer.width = req.width;
	buffer.height = req.height;
	buffer.fps = req.fps;
	buffer.bitrate = req.bitrate;
	buffer.angle = req.angle;
	buffer.mirror = req.mirror;
	
	ret = video_queue_push(&g_video_recv_queue, &buffer);
	if (ret != 0)
	{
		video_queue_clear(&g_video_recv_queue);
		video_queue_push(&g_video_recv_queue, &buffer);

		LOGI("onC2CVideoFrame|fromip:%s, fromport:%u|frameId:[%llu, %llu], packNum:%d, packId:%d, packLen:%d, frameLen:%d, videoLen:%d|video_queue_push fail:%d", ip, port, p->frameID, req.frameID, packs, pid, packLen, fLen, p->videoLen, ret);
	}
	else
	{
		LOGI("onC2CVideoFrame|fromip:%s, fromport:%u|frameId:[%llu, %llu], packNum:%d, packId:%d, packLen:%d, frameLen:%d, videoLen:%d|succ", ip, port, p->frameID, req.frameID, packs, pid, packLen, fLen, p->videoLen);
	}
	p->frameID = 0;
	p->videoLen = 0;
	return;
}

void onC2CVideoFrameEx(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	p->chatLastTime = time(NULL);
	
	if (p->chatState != 1)
	{
		LOGI("onC2CVideoFrameEx|not chatState");
		return;
	}
	
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CVideoFrameEx|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	if (!(p->chatType & P2P_CHAT_TYPE_MASK_VIDEO)) 
	{
		LOGI("onC2CVideoFrameEx|not video state");
		return;
	}

	if (isTerminated()) 
	{
		LOGI("onC2CVideoFrameEx|terminated");
		return;
	}

	if (video_paused()) 
	{
		LOGI("onC2CVideoFrameEx|paused");
		return;
	}

	Header header;
	CmdVideoFrameEx req;

	uint16_t swapLen = P2P_MAX_BUF_SIZE;
	int ret = decodeVideoFrameEx(recvBuf, recvLen, &header, &req, p->swapBuf, &swapLen);
	if (ret != 0) 
	{
		LOGI("onC2CVideoFrameEx|decode fail");
		return;
	}

	if (req.toAccount != p->myAccount || req.account != p->toAccount) 
	{
		LOGI("onC2CVideoFrameEx|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, req.toAccount, p->toAccount, req.account);
		return;
	}
	
	video_buffer_t buffer;
	buffer.buf = p->swapBuf;
	buffer.size = swapLen;
	buffer.len = swapLen;
	buffer.width = req.width;
	buffer.height = req.height;
	buffer.fps = req.fps;
	buffer.bitrate = req.bitrate;
	buffer.angle = req.angle;
	buffer.mirror = req.mirror;
	
	ret = video_queue_push(&g_video_recv_queue, &buffer);
	if (ret != 0)
	{
		LOGI("onC2CVideoFrameEx|fromip:%s, fromport:%u|frameLen:%u, video_queue_push fail:%d", ip, port, swapLen, ret);
	}
	else
	{
		LOGI("onC2CVideoFrameEx|fromip:%s, fromport:%u|frameLen:%u", ip, port, swapLen);
	}
	return;
}

void onC2CAudioFrame(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	p->chatLastTime = time(NULL);
	
	if (p->chatState != 1)
	{
		LOGI("onC2CAudioFrame|not chatState");
		return;
	}
	
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CAudioFrame|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	if (!(p->chatType & P2P_CHAT_TYPE_MASK_AUDIO)) 
	{
		LOGI("onC2CAudioFrame|chatType=%d", p->chatType);
		return;
	}

	Header header;
	CmdAudioFrame req;

	uint16_t swapLen = P2P_MAX_BUF_SIZE;
	int ret = decodeAudioFrame(recvBuf, recvLen, &header, &req, p->swapBuf, &swapLen);
	if (ret != 0) 
	{
		LOGI("onC2CAudioFrame|decode fail");
		return;
	}

	if (req.toAccount != p->myAccount || req.account != p->toAccount) 
	{
		LOGI("onC2CAudioFrame|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, req.toAccount, p->toAccount, req.account);
		return;
	}

	if (swapLen == 0) 
	{
		LOGI("onC2CAudioFrame|fromip:%s, fromport:%u|invalid swapLen:%d, req.account:%lld, req.toAccount:%lld", ip, port, swapLen, req.account, req.toAccount);
		return;
	}

	if (!playAudio((char *)(p->swapBuf), (int)swapLen))
	{
		LOGI("onC2CAudioFrame|fromip:%s, fromport:%u|myAccount:%lld, toAccount:%lld|myIp:%s, myPort:%u, myLocalIp:%s, myLocalPort:%u|push fail", ip, port, p->myAccount, p->toAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort);
	}
	else
	{
		LOGI("onC2CAudioFrame|fromip:%s, fromport:%u|myAccount:%lld, toAccount:%lld|myIp:%s, myPort:%u, myLocalIp:%s, myLocalPort:%u|push succ", ip, port, p->myAccount, p->toAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort);
	}
	return;
}

int c2sGetAccount(int64_t toAccount, int chatType) 
{
	p2pnet_t *p = (p2pnet_t *) &g_p2pnet;
	
	p->chatState = 0;
	
	if (p->myAccount != 0 && p->toAccount != 0)
	{
		if (p->chatType & P2P_CHAT_TYPE_MASK_VIDEO)
		{
			c2cClose(p->myAccount, p->toAccount, P2P_CHAT_TYPE_VIDEO);
		}
		else if (p->chatType & P2P_CHAT_TYPE_MASK_AUDIO)
		{
			c2cClose(p->myAccount, p->toAccount, P2P_CHAT_TYPE_AUDIO);
		}
	}
	
	if (toAccount == 0)
	{
		LOGI("c2sGetAccount|invalid toAccount");
		return -1;
	}
	
	if (p->myAccount == 0)
	{
		LOGI("c2sGetAccount|invalid myAccount");
		return -1;
	}
	
	if (p->srvSock == -1 || p->srvState != 1)
	{
		LOGI("c2sGetAccount|not login");
		return -1;
	}
	
	pause_video();
	p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
	p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
	p->chatSave = chatType;

	p->toState = 0;
	p->toAccount = toAccount;
	bzero(p->toIp, sizeof(p->toIp));
	p->toPort = 0;
	bzero(p->toLocalIp, sizeof(p->toLocalIp));
	p->toLocalPort = 0;
	p->toSendTime = 0;
	p->toRecvTime = time(NULL);

	CmdC2SHole req;
	bzero(&req, sizeof(req));
	req.account = p->myAccount;
	req.toAccount = toAccount;
	strncpy(req.localIp, p->myLocalIp, sizeof(req.localIp) - 1);
	req.localPort = p->myLocalPort;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeC2SHole(p->srvSendSeq++, 0, &req, sendBuf, &sendLen);

	int n = MySendToSrv(p, sendBuf, sendLen, 0, p->srvIp, p->srvPort);
	int ret = sendLen == n ? 0 : -2;

	LOGI("c2sGetAccount|myAccount:%lld,toAccount:%lld, ret:%d", p->myAccount, toAccount, ret);
	
	return ret;
}

void onC2SGetAccountRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0)
	{
		LOGI("onC2SGetAccountRsp|invalid myAccount");
		return;
	}
	
	if (p->toAccount == 0)
	{
		LOGI("onC2SGetAccountRsp|invalid toAccount");
		return;
	}

	Header header;
	CmdC2SHoleRsp rsp;
	int ret = decodeC2SHoleRsp(recvBuf, recvLen, &header, &rsp);
	if (ret != 0) 
	{
		LOGI("onC2SGetAccountRsp|decode fail");
		return;
	}

	if (rsp.account != p->myAccount)
	{
		LOGI("onC2SGetAccountRsp|invalid rsp.account:%lld, myAccount:%lld", rsp.account, p->myAccount);
		return;
	}

	if (rsp.toAccount != p->toAccount)
	{
		LOGI("onC2SGetAccountRsp|invalid rsp.toAccount:%lld, toAccount:%lld", rsp.toAccount, p->toAccount);
		return;
	}

	if (header.CmdStatus != 0)
	{
		LOGI("onC2SGetAccountRsp|not login");
		return;
	}
	
	if (strcmp(p->myIp, rsp.ip) != 0) 
	{
		bzero(p->myIp, sizeof(p->myIp));
		strncpy(p->myIp, rsp.ip, sizeof(p->myIp) - 1);
	}
	if (p->myPort != rsp.port) 
	{
		p->myPort = rsp.port;
	}

	if (strcmp(p->myLocalIp, rsp.localIp) != 0) 
	{
		bzero(p->myLocalIp, sizeof(p->myLocalIp));
		strncpy(p->myLocalIp, rsp.localIp, sizeof(p->myLocalIp) - 1);
	}
	if (p->myLocalPort != rsp.localPort) 
	{
		p->myLocalPort = rsp.localPort;
	}

	bzero(p->toIp, sizeof(p->toIp));
	strncpy(p->toIp, rsp.toIp, sizeof(p->toIp) - 1);
	p->toPort = rsp.toPort;

	bzero(p->toLocalIp, sizeof(p->toLocalIp));
	strncpy(p->toLocalIp, rsp.toLocalIp, sizeof(p->toLocalIp) - 1);
	p->toLocalPort = rsp.toLocalPort;

	LOGI("onC2SGetAccountRsp|fromip:%s, fromport:%u|myAccount:%lld, toAccount:%lld, myIp:%s, myPort:%u, myLocalIp:%s, myLocalPort:%u, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u", ip, port, p->myAccount, p->toAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort);

	c2cInnerHole(p);
	usleep(10000);
	c2cInnerRequest(p);
}

void onC2SGetAccountNotify(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0)
	{
		LOGI("onC2SGetAccountNotify|invalid myAccount");
		return;
	}
	
	Header header;
	CmdC2SHoleNotify rsp;
	int ret = decodeC2SHoleNotify(recvBuf, recvLen, &header, &rsp);
	if (ret != 0) 
	{
		LOGI("onC2SGetAccountNotify|decode fail");
		return;
	}

	if (rsp.toAccount != p->myAccount) 
	{
		LOGI("onC2SGetAccountNotify|fromip:%s, fromport:%u|myAccount:%lld(%lld)", ip, port, p->myAccount, rsp.toAccount);
		return;
	}
	
	if (rsp.account == 0)
	{
		LOGI("onC2SGetAccountNotify|invalid account");
		return;;
	}
	
	if (p->chatState != 0)
	{
		LOGI("onC2SGetAccountNotify|chatState, toAccount:%lld, account:%lld", p->toAccount, rsp.account);
		return;
	}

	pause_video();
	p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_VIDEO);
	p->chatType = p->chatType & ~(1 << P2P_CHAT_TYPE_AUDIO);
	
	p->toAccount = rsp.account;
	bzero(p->toIp, sizeof(p->toIp));
	strncpy(p->toIp, rsp.ip, sizeof(p->toIp) - 1);
	p->toPort = rsp.port;

	bzero(p->toLocalIp, sizeof(p->toLocalIp));
	strncpy(p->toLocalIp, rsp.localIp, sizeof(p->toLocalIp) - 1);
	p->toLocalPort = rsp.localPort;

	if (strcmp(p->myIp, rsp.toIp) != 0) 
	{
		bzero(p->myIp, sizeof(p->myIp));
		strncpy(p->myIp, rsp.toIp, sizeof(p->myIp) - 1);
	}
	if (p->myPort != rsp.toPort) 
	{
		p->myPort = rsp.toPort;
	}

	if (strcmp(p->myLocalIp, rsp.toLocalIp) != 0) 
	{
		bzero(p->myLocalIp, sizeof(p->myLocalIp));
		strncpy(p->myLocalIp, rsp.toLocalIp, sizeof(p->myLocalIp) - 1);
	}
	if (p->myLocalPort != rsp.toLocalPort) 
	{
		p->myLocalPort = rsp.toLocalPort;
	}
	
	LOGI("onC2SGetAccountNotify|fromip:%s, fromport:%u|myAccount:%lld, toAccount:%lld, myIp:%s, myPort:%u, myLocalIp:%s, myLocalPort:%u, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u", ip, port, p->myAccount, p->toAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort);

	c2cInnerHole(p);
}

void onC2CRecvText(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CRecvText|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}
	
	Header header;
	CmdText req;

	uint16_t swapLen = P2P_MAX_BUF_SIZE;
	int ret = decodeText(recvBuf, recvLen, &header, &req, p->swapBuf, &swapLen);
	if (ret != 0) 
	{
		LOGI("onC2CRecvText|decode fail");
		return;
	}

	if (req.toAccount != p->myAccount || req.account != p->toAccount) 
	{
		LOGI("onC2CRecvText|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, req.toAccount, p->toAccount, req.account);
		return;
	}
	
	LOGI("onC2CRecvText|fromip:%s, fromport:%u|myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u,text:%s,len:%u", ip, port, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, p->swapBuf, swapLen);
	
	p2pcallback(EVENT_RECV_TEXT, p->toAccount, p->swapBuf, swapLen);
	
	return;
}

void onC2CRecvFileBlock(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CRecvFileBlock|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	Header header;
	CmdFileBlock req;

	uint16_t swapLen = P2P_MAX_BUF_SIZE;
	int ret = decodeFileBlock(recvBuf, recvLen, &header, &req, p->swapBuf, &swapLen);
	if (ret != 0) 
	{
		LOGI("onC2CRecvFileBlock|decode fail");
		return;
	}

	if (req.toAccount != p->myAccount || req.account != p->toAccount) 
	{
		LOGI("onC2CRecvFileBlock|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, req.toAccount, p->toAccount, req.account);
		return;
	}

	onRecvFile(p->toAccount, req.type, req.name, req.len, p->swapBuf, swapLen, req.bid, req.blocks);

	CmdFileBlockRsp rsp;
	bzero(&rsp, sizeof(rsp));
	rsp.account = p->myAccount;
	rsp.toAccount = p->toAccount;
	rsp.toAccount = p->toAccount;
	rsp.bid = req.bid;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeFileBlockRsp(p->srvSendSeq++, 0, &rsp, sendBuf, &sendLen);

	char *sendIp = p->srvIp;
	uint16_t sendPort = p->srvPort;

	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	ret = (int) sendLen == n ? 0 : -2;

	if (ret != 0)
	{
		LOGI("c2cSendFileBlock|toip:%s, toport:%u|myAccount:%lld, myIp:%s, myPort:%u, myLocalIp%s, myLocalPort:%u, toAccount:%lld, toIp:%s, toPort:%u, toLocalIp:%s, toLocalPort:%u, bid:%d, len:%d ,blocks:%d, ret:%d", sendIp, sendPort, p->myAccount, p->myIp, p->myPort, p->myLocalIp, p->myLocalPort, p->toAccount, p->toIp, p->toPort, p->toLocalIp, p->toLocalPort, req.bid, req.len, req.blocks, ret);
	}

	return;
}

void onC2CRecvFileBlockRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CRecvFileBlockRsp|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	Header header;
	CmdFileBlockRsp rsp;

	int ret = decodeFileBlockRsp(recvBuf, recvLen, &header, &rsp);
	if (ret != 0) 
	{
		LOGI("onC2CRecvFileBlockRsp|decode fail");
		return;
	}

	if (rsp.toAccount != p->myAccount || rsp.account != p->toAccount) 
	{
		LOGI("onC2CRecvFileBlockRsp|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, rsp.toAccount, p->toAccount, rsp.account);
		return;
	}

	onSendFile(p->toAccount, p->fileType, p->fileName, rsp.bid, p->blocks);
	p->bid++;
	if (p->bid < p->blocks) 
	{
		c2cSendFileBlock(p->bid);
	} 
	else 
	{
		if (p->fileBuf) 
		{
			free(p->fileBuf);
			p->fileBuf = NULL;
		}

		if (p->fileName) 
		{
			free(p->fileName);
			p->fileName = NULL;
		}
	}
}

void onC2CHeartBeat(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CHeartBeat|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	Header header;
	CmdC2CHeartBeat req;
	int ret = decodeC2CHeartBeat(recvBuf, recvLen, &header, &req);
	if (ret != 0) 
	{
		LOGI("onC2CHeartBeat|decode fail");
		return;
	}

	if (req.toAccount != p->myAccount || req.account != p->toAccount) 
	{
		LOGI("onC2CHeartBeat|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, req.toAccount, p->toAccount, req.account);
		return;
	}
	
	CmdC2CHeartBeatRsp rsp;
	bzero(&rsp, sizeof(rsp));
	rsp.account = p->myAccount;
	strncpy(rsp.ip, p->myIp, sizeof(rsp.ip) - 1);
	rsp.port = p->myPort;
	strncpy(rsp.localIp, p->myLocalIp, sizeof(rsp.localIp) - 1);
	rsp.localPort = p->myLocalPort;
	rsp.toAccount = p->toAccount;

	char sendBuf[P2P_MAX_BUF_SIZE];
	uint16_t sendLen = P2P_MAX_BUF_SIZE;
	encodeC2CHeartBeatRsp(p->srvSendSeq++, 0, &rsp, sendBuf, &sendLen);

	char *sendIp;
	uint16_t sendPort;
	c2cGetIpAndPort(p, &sendIp, &sendPort);
	int n = MySendToSrv(p, sendBuf, sendLen, 0, sendIp, sendPort);
	ret = sendLen == n ? 0 : -2;

	LOGI("onC2CHeartBeat|fromip:%s, fromport:%u|account:%lld, toAccount:%lld, ip:%s, port:%u, localIp:%s, localPort:%u, ret:%d", ip, port, req.account, req.toAccount, req.ip, req.port, req.localIp, req.localPort, ret);
}

void onC2CHeartBeatRsp(p2pnet_t *p, char *ip, uint16_t port, uint8_t *recvBuf, uint16_t recvLen) 
{
	if (p->myAccount == 0 || p->toAccount == 0)
	{
		LOGI("onC2CHeartBeatRsp|invalid myAccount:%lld, toAccount:%lld", p->myAccount, p->toAccount);
		return;
	}

	Header header;
	CmdC2CHeartBeatRsp rsp;
	int ret = decodeC2CHeartBeatRsp(recvBuf, recvLen, &header, &rsp);
	if (ret != 0) 
	{
		LOGI("onC2CHeartBeatRsp|decode fail");
		return;
	}

	if (rsp.toAccount != p->myAccount || rsp.account != p->toAccount) 
	{
		LOGI("onC2CHeartBeatRsp|fromip:%s, fromport:%u|account not equal. myAccount:%lld(%lld), toAccount:%lld(%lld)", ip, port, p->myAccount, rsp.toAccount, p->toAccount, rsp.account);
		return;
	}

	LOGI("onC2CHeartBeatRsp|fromip:%s, fromport:%u|account:%lld, toAccount:%lld, ip:%s, port:%u, localIp:%s, localPort:%u", ip, port, rsp.account, rsp.toAccount, rsp.ip, rsp.port, rsp.localIp, rsp.localPort);
	return;
}

int video_decode(JNIEnv *env, char *buf, int buf_size)
{
	p2pnet_t *p = &g_p2pnet;

	video_buffer_t buffer;
	buffer.buf = buf;
	buffer.size = buf_size;

	int ret = video_queue_pop(&g_video_recv_queue, &buffer);
	if (ret != 0)
	{
		return -1;
	}

	if (!(p->chatType & P2P_CHAT_TYPE_MASK_VIDEO))
	{
		LOGI("video_decode|not video state");
		return -1;
	}

	if (isTerminated())
	{
		LOGI("video_decode|video terminated");
		return -1;
	}

	if (video_paused())
	{
		LOGI("video_decode|video paused");
		return -1;
	}

	size_t video_size = buffer.width*buffer.height*3/2;
	if (!g_vedio_decode_buffer)
	{
		g_vedio_decode_buffer = (uint8_t *)malloc(video_size);
		g_vedio_decode_buffer_size = video_size;
	}
	else if (g_vedio_decode_buffer_size < (size_t)video_size)
	{
		g_vedio_decode_buffer = realloc(g_vedio_decode_buffer, video_size);
		g_vedio_decode_buffer_size = video_size;
	}

	unsigned char *encode_data = buffer.buf;
	int encode_size = buffer.len;

	int decode_width = 0;
	int decode_height = 0;

	struct timeval begin_time;
	struct timeval end_time;

	gettimeofday(&begin_time, NULL);

	int decode_size = h264_decode_frame(encode_data, encode_size, buffer.width, buffer.height, buffer.fps, buffer.bitrate, g_vedio_decode_buffer, &decode_width, &decode_height);

	gettimeofday(&end_time, NULL);

	int diff = 1000000 * (end_time.tv_sec - begin_time.tv_sec) + end_time.tv_usec - begin_time.tv_usec;

	if (decode_size > 0)
	{
		FrameBuffer fb;
		fb.mpData = g_vedio_decode_buffer;
		fb.mSize = decode_width * decode_height * 3 / 2;
		fb.width = decode_width;
		fb.height = decode_height;
		fb.mAngle = buffer.angle;
		fb.mType = def_DataType_YUV420P;
		fb.mfMirror =  buffer.mirror ? true : false;

		setFrame(&fb);

		if (!isTerminated() && !video_paused() && (p->chatType & P2P_CHAT_TYPE_MASK_VIDEO) && g_render_cls && g_render_obj && JNI_TRUE != (*env)->IsSameObject(env, g_render_cls, NULL) && JNI_TRUE != (*env)->IsSameObject(env, g_render_obj, NULL))
		{
			jmethodID render_mid = (*env)->GetStaticMethodID(env, g_render_cls, "onNativeNotify", "(Ljava/lang/Object;ILjava/lang/Object;)V");
			if (render_mid != 0)
			{
				char extraInfo[64];
				bzero(extraInfo, sizeof(extraInfo));
				snprintf(extraInfo, sizeof(extraInfo), "%d,%d,%d,%d", fb.width, fb.height, fb.mAngle, fb.mfMirror?1:0);

				jstring js_data = (*env)->NewStringUTF(env, extraInfo);
				(*env)->CallStaticVoidMethod(env, g_render_cls, render_mid, g_render_obj, 0, js_data);
				(*env)->DeleteLocalRef(env, js_data);
			}
			else
			{
				LOGI("video_decode|render_mid is null");
			}
		}
	}
	else
	{
		LOGE("video_decode|h264_decode_frame fail:%d, cost us:%d", decode_size, diff);
	}
	return 0;
}
*/
