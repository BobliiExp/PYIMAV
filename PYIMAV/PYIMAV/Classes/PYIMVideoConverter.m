//
//  PYIMVideoConverter.m
//  PYIMAV
//
//  Created by 002 on 2018/5/16.
//  Copyright © 2018年 Ponyo. All rights reserved.
//

#import "PYIMVideoConverter.h"

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <inttypes.h>
#include "x264.h"

#include "libavcodec/avcodec.h"
#include "libavformat/avformat.h"
#include "libswscale/swscale.h"

static uint8_t *g_vedio_buffer;

@interface PYIMVideoConverter() {
    x264_t                  *pX264Handle;
    x264_param_t            *pX264Param;
    x264_picture_t          *pPicIn;
    x264_picture_t          *pPicOut;
    
    x264_nal_t              *pNals;
    int                      iNal;
    
    STMVideoFrameYUV *frameYUV;
    AVCodecContext *codecCtx;
    AVFrame *pFrame;
}

@end

@implementation PYIMVideoConverter

- (instancetype)init {
    self = [super init];
    if(self){
        avcodec_register_all();
        
        AVCodec *codec = avcodec_find_decoder(AV_CODEC_ID_H264);
        
        codecCtx = avcodec_alloc_context3(codec);
        //更改g_pCodecCtx的一些成员变量的值，您应该从解码方得到这些变量值：
        codecCtx->time_base.num = 1; //这两行：一秒钟帧数
        codecCtx->time_base.den = VIDEO_FPS;
        codecCtx->bit_rate = VIDEO_BITRATE; //初始化
        codecCtx->frame_number = 1; //每包一个视频帧
        codecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
        codecCtx->width = ENCODE_FRMAE_WIDTH; //这两行：视频的宽度和高度
        codecCtx->height = ENCODE_FRMAE_HEIGHT;
        
        //打开codec。如果打开成功的话，分配AVFrame：
        if(avcodec_open2(codecCtx, codec, NULL) >= 0)
        {
            pFrame = av_frame_alloc();// Allocate video frame
        }
        
        avcodec_open2(codecCtx, codec, nil);
        
        [self setupConverter];
    }
    
    return self;
}

- (void)setupConverter {
    pX264Param = (x264_param_t *)malloc(sizeof(x264_param_t));
    assert(pX264Param);
    /* 配置参数
     * 使用默认参数，在这里因为我的是实时网络传输，所以我使用了zerolatency的选项，使用这个选项之后就不会有delayed_frames，如果你使用的不是这样的话，还需要在编码完成之后得到缓存的编码帧
     * 在使用中，开始总是会有编码延迟，导致我本地编码立即解码回放后也存在巨大的视频延迟，主要是zerolatency该参数。
     * 后来发现设置x264_param_default_preset(&param, "fast" , "zerolatency" );后就能即时编码了
     */
    x264_param_default_preset(pX264Param, "fast", "zerolatency");
    
    
    pX264Param->i_level_idc = 30; // 编码复杂度
    // 视频选项
    pX264Param->i_width   = ENCODE_FRMAE_WIDTH; // 要编码的图像宽度.
    pX264Param->i_height  = ENCODE_FRMAE_HEIGHT; // 要编码的图像高度
    
    pX264Param->b_deterministic = 1;
    
    // cpuFlags
    pX264Param->i_threads = 1;// X264_SYNC_LOOKAHEAD_AUTO; // 取空缓冲区继续使用不死锁的保证
    
    pX264Param->i_csp = X264_CSP_I420;//X264_CSP_NV12;//X264_CSP_I420;
    
    // 帧率，值越小质量越好
    pX264Param->i_fps_num  = VIDEO_FPS; // 帧率分子
    pX264Param->i_fps_den  = 1; // 帧率分母
    pX264Param->i_bframe = 0;
    pX264Param->i_keyint_max = VIDEO_FPS * 2;
    
    //i_rc_method很关键，判断cpu核数，如果为单核，则使用X264_RC_CQP，减少编码时间，但相应增大了编码后的图像体积，增大后约4-5k/帧，增大前约2-3k。
    //如果为多核，则使用X264_RC_CRF，因为多核本来就快，使用最佳压缩率最好。
    pX264Param->rc.i_rc_method = X264_RC_CRF;// X264_RC_ABR; // 码率控制，CQP(恒定质量)，CRF(恒定码率)，ABR(平均码率)
    
    // 速率控制参数
    pX264Param->rc.i_bitrate = VIDEO_BITRATE / 1000; // 码率(比特率), x264使用的bitrate需要/1000。
    pX264Param->rc.i_qp_constant = 26; //qp的初始值，如果为恒定质量，就是用该值
    
    // 下面检查bitrate级别
    // 图像质量
    pX264Param->rc.f_rf_constant = 26;// 15; // rc.f_rf_constant是实际质量，越大图像越花，越小越清晰
    //    pX264Param->rc.f_rf_constant_max = 45; // param.rc.f_rf_constant_max ，图像质量的最大值。
    pX264Param->analyse.b_transform_8x8 = 1;
    pX264Param->rc.f_aq_strength = 1.5;
    
    pX264Param->rc.i_aq_mode = 0;
    pX264Param->rc.f_qcompress = 0.0;
    pX264Param->rc.f_ip_factor = 0.5;
    pX264Param->rc.f_rate_tolerance = 0.1;
    
    pX264Param->analyse.i_direct_mv_pred = X264_DIRECT_PRED_AUTO;
    pX264Param->analyse.i_me_method = X264_ME_DIA;
    pX264Param->analyse.i_me_range = 16;
    pX264Param->analyse.i_subpel_refine = 2;
    pX264Param->i_slice_max_size = 1200;
    pX264Param->b_deblocking_filter = 1;
    pX264Param->i_deblocking_filter_alphac0 = 4;
    pX264Param->i_deblocking_filter_beta = 4;
    
    pX264Param->rc.b_mb_tree = 0;
    
    // Log参数，不需要打印编码信息时直接注释掉就行
    //    pX264Param->i_log_level  = X264_LOG_DEBUG;
    
    
    // 设置Profile.使用Baseline profile
    x264_param_apply_profile(pX264Param, "baseline");
    
    // 流参数
    //    pX264Param->b_cabac =0;
    //    pX264Param->b_interlaced = 0;
    
    //    pX264Param->rc.i_vbv_max_bitrate=(int)((m_bitRate * 1.2) / 1000) ; // 平均码率模式下，最大瞬时码率，默认0(与-B设置相同)
    
    // 使用实时视频传输时，需要实时发送sps,pps数据
    //    pX264Param->b_repeat_headers = 1;  // 重复SPS/PPS 放到关键帧前面。该参数设置是让每个I帧都附带sps/pps。
    
    //    pX264Param->i_timebase_den = pX264Param->i_fps_num;
    //    pX264Param->i_timebase_num = pX264Param->i_fps_den;
    
    /* I帧间隔
     * 我是将I帧间隔与帧率挂钩的，以控制I帧始终在指定时间内刷新。
     * 以下是2秒刷新一个I帧
     */
    //    pX264Param->b_intra_refresh = 1;
    //    pX264Param->b_annexb = 1;
    
    
    
    /* ---------------------------------------------------------------------- */
    // 编码需要的辅助变量
    iNal = 0;
    pNals = NULL;
    
    pPicIn = (x264_picture_t *)malloc(sizeof(x264_picture_t));
    memset(pPicIn, 0, sizeof(x264_picture_t));
    // TODO:这里有内存泄漏问题，后面要分析处理
    x264_picture_alloc(pPicIn, X264_CSP_I420, pX264Param->i_width, pX264Param->i_height);
    pPicIn->i_type = X264_TYPE_AUTO;
    
    pPicOut = (x264_picture_t *)malloc(sizeof(x264_picture_t));
    memset(pPicOut, 0, sizeof(x264_picture_t));
    x264_picture_init(pPicOut);
    
    /* ---------------------------------------------------------------------- */
    // 打开编码器句柄,通过x264_encoder_parameters得到设置给X264
    // 的参数.通过x264_encoder_reconfig更新X264的参数
    pX264Handle = x264_encoder_open(pX264Param);
    assert(pX264Handle);
}



+ (NSData*)convertSample:(CMSampleBufferRef)sample {
    NSData *data = nil;
    
    @autoreleasepool{
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sample);
        
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        //    UInt8 *bufferbasePtr = (UInt8 *)CVPixelBufferGetBaseAddress(imageBuffer);
        UInt8 *bufferPtr = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
        UInt8 *bufferPtr1 = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,1);
        
        //    size_t buffeSize = CVPixelBufferGetDataSize(imageBuffer);
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        
        //    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        size_t bytesrow0 = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,0);
        size_t bytesrow1  = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,1);
        //    size_t bytesrow2 = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,2);
        
        size_t video_size = width * height *3/2;
        UInt8 *yuv420_data = (UInt8 *)malloc(video_size);//buffer to store YUV with layout YYYYYYYYUUVV
        
        
        /* convert NV12 data to YUV420*/
        UInt8 *pY = bufferPtr ;
        UInt8 *pUV = bufferPtr1;
        UInt8 *pU = yuv420_data + width * height;
        UInt8 *pV = pU + width * height / 4;
        for(int i = 0; i < height; i++)
        {
            memcpy(yuv420_data + i * width, pY + i * bytesrow0, width);
        }
        for(int j = 0;j < height/2; j++)
        {
            for(int i = 0; i < width/2; i++)
            {
                *(pU++) = pUV[i<<1];
                *(pV++) = pUV[(i<<1) + 1];
            }
            pUV += bytesrow1;
        }
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
        if (!g_vedio_buffer){
            g_vedio_buffer = (uint8_t *)malloc(video_size);
        }
        
        // picked with 640*480 resize to 320*240 for mobile device
        bzero(g_vedio_buffer, video_size);
        int ret = resize_frame(yuv420_data, (int)width, (int)height, g_vedio_buffer, (int)width/2, (int)height/2);
        if(ret==0){
            data = [NSData dataWithBytes:g_vedio_buffer length:video_size];
        }
        free(yuv420_data);
    }
    
    return data;
}

- (NSData*)encode:(NSData*)data {
    // 整合编码数据
    NSMutableData *mData = nil;
    
    @synchronized(self){
        pPicIn->img.i_plane = 3;
        pPicIn->img.plane[0] = (uint8_t*)data.bytes; // yuv420_data <==> pInFrame
        pPicIn->img.plane[1] = pPicIn->img.plane[0] + ENCODE_FRMAE_WIDTH * ENCODE_FRMAE_HEIGHT;
        pPicIn->img.plane[2] = pPicIn->img.plane[1] + (ENCODE_FRMAE_WIDTH * ENCODE_FRMAE_HEIGHT / 4);
        pPicIn->img.i_stride[0] = ENCODE_FRMAE_WIDTH;
        pPicIn->img.i_stride[1] = ENCODE_FRMAE_WIDTH / 2;
        pPicIn->img.i_stride[2] = ENCODE_FRMAE_WIDTH / 2;
        
        // 编码
        int frame_size = x264_encoder_encode(pX264Handle, &pNals, &iNal, pPicIn, pPicOut);
        if(frame_size > 0) {
            mData = [NSMutableData data];
            for (int i = 0; i < iNal; ++i) {
                [mData appendBytes:pNals[i].p_payload length:pNals[i].i_payload];
            }
        }
    }
    
    return mData;
}

- (NSData*)decode:(char*)buffer length:(int)length {
    NSData *data = nil;
    
    @synchronized(self){
        AVPacket packet;
        av_new_packet(&packet, length);
        
        memcpy(packet.data, buffer, length);
        packet.size = length;
        
        int ret, got_picture;
        
        // 数据解码到pFrame中；codecCtx是解析相关的配置，可以根据数据设定
        ret = avcodec_decode_video2(codecCtx, pFrame, &got_picture, &packet);
        av_free_packet(&packet);// free 不然有内存泄漏
        
        if (ret > 0){
            if(got_picture){
                //进行下一步的处理
                size_t buf_size = pFrame->width * pFrame->height * 3 / 2;
                char *buf = (char *)malloc(buf_size);
                
                AVPicture *pict;
                int w, h;
                char *y, *u, *v;
                pict = (AVPicture *)pFrame;//这里的frame就是解码出来的AVFrame
                w = pFrame->width;
                h = pFrame->height;
                y = buf;
                u = y + w * h;
                v = u + w * h / 4;
                
                for (int i=0; i<h; i++)
                    memcpy(y + w * i, pict->data[0] + pict->linesize[0] * i, w);
                for (int i=0; i<h/2; i++)
                    memcpy(u + w / 2 * i, pict->data[1] + pict->linesize[1] * i, w / 2);
                for (int i=0; i<h/2; i++)
                    memcpy(v + w / 2 * i, pict->data[2] + pict->linesize[2] * i, w / 2);
                
                
                data = [NSData dataWithBytes:buf length:buf_size];
                free(buf);
            }
        }
        
        if(data==nil || data.length==0){
            NSLog(@"解码视频:ret %d gotpic:%d", ret, got_picture);
        }
    }
    
    return data;
}

+ (void)convertYUV:(STMGLView*)render video:(PYIMModeVideo*)video {
    // 将得到的 i420 数据赋值给 videoFrameYUV 对象
    
    int yuvWidth, yuvHeight;
    void *planY, *planU, *planV;
    
    yuvWidth = video.width;
    yuvHeight = video.height;
    
    char *buf = (char*)video.media.bytes;
    
    planY = buf;
    planU = buf + yuvWidth * yuvHeight;
    planV = buf + yuvWidth * yuvHeight * 5 / 4;
    
    STMVideoFrameYUV *frameYUV = [[STMVideoFrameYUV alloc] init];
    frameYUV.format = STMVideoFrameFormatYUV;
    frameYUV.width = yuvWidth;
    frameYUV.height = yuvHeight;
    frameYUV.luma = planY;
    frameYUV.chromaB = planU;
    frameYUV.chromaR = planV;
    
    frameYUV.angle = video.angle;
    frameYUV.cameraF = video.mirror;
    
    // 控制渲染速度
//    usleep(1000*1000*1.0/video.fps/*fps*/);
    
    // 渲染 i420
    [render render:frameYUV];
    
}

- (void)dispose {
    // 清除图像区域
    x264_picture_clean(pPicIn);
    // 关闭编码器句柄
    x264_encoder_close(pX264Handle);
    pX264Handle = NULL;
    free(pPicIn);
    pPicIn = NULL;
    free(pPicOut);
    pPicOut = NULL;
    free(pX264Param);
    pX264Param = NULL;
    
    free(g_vedio_buffer);
    g_vedio_buffer = NULL;
}

struct SwsContext *img_convert_ctx = NULL;
int resize_frame(unsigned char *in, unsigned int width, unsigned int height, unsigned char *out, unsigned int out_width, unsigned int out_height)
{
    AVFrame *pFrame = av_frame_alloc();
    AVFrame *pFrameOut = av_frame_alloc();
    if (pFrame == NULL)
    {
        return -1;
    }
    if (pFrameOut == NULL)
    {
        av_free(pFrame);
        return -2;
    }
    
    avpicture_fill((AVPicture *)pFrame, in, PIX_FMT_YUV420P, width, height);
    avpicture_fill((AVPicture *)pFrameOut, out, PIX_FMT_YUV420P, out_width, out_height);
    img_convert_ctx = sws_getCachedContext(img_convert_ctx,
                                           width,
                                           height,
                                           PIX_FMT_YUV420P,
                                           out_width,
                                           out_height,
                                           PIX_FMT_YUV420P,
                                           SWS_BICUBIC,
                                           NULL,
                                           NULL,
                                           NULL);
    
    sws_scale(img_convert_ctx,
              (const uint8_t*  const*)pFrame->data,
              pFrame->linesize,
              0,
              height,
              pFrameOut->data,
              pFrameOut->linesize);
    
    av_free(pFrame);
    av_free(pFrameOut);
    return 0;
}

@end
