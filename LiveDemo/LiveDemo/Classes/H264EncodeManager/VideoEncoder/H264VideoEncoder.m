//
//  H264VideoEncoder.m
//  LiveDemo
//
//  Created by 李泽宇 on 2018/4/23.
//  Copyright © 2018年 丶信步沧桑. All rights reserved.
//

#import "H264VideoEncoder.h"
#import <VideoToolbox/VideoToolbox.h>


@interface H264VideoEncoder ()
{
    int frameID;
}

@property (nonatomic, assign) VTCompressionSessionRef encodingSession;
@property (nonatomic, assign) dispatch_queue_t encoderQueue;
@property (nonatomic, strong) NSData *byteHeader;
@property (nonatomic, assign) CMFormatDescriptionRef format;

@end



@implementation H264VideoEncoder

+ (instancetype)h264VideoEncoderWithDelegate:(id)delegate {
    
    static id instance = nil;
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        instance = [[H264VideoEncoder alloc] initWithDelegate:delegate];
    });
    return instance;
}



- (instancetype)initWithDelegate:(id)delegate {
    
    if (self = [super init]) {
        _delegate = delegate;
        _encoderQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        // 每一帧的所有NALU数据前四个字节变成0x00 00 00 01之后再写入文件
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1;
        _byteHeader = [NSData dataWithBytes:bytes length:length];
    }
    return self;
}


- (void)createEncoder {
    
    dispatch_sync(self.encoderQueue, ^{
        self->frameID = 0;
        int width = 480;
        int height = 640;
        
        /*
         1. VTCompressionSessionCreate 创建压缩会话 Session
         参数1: 会话分配器,NULL为默认;
         参数2: 帧宽度, 单位像素;
         参数3: 帧高度, 单位像素;
         参数4: 编码格式, kCMVideoCodecType_H264;
         参数5: 视频编码器, NULL为自动选择;
         参数6: 像素缓冲区中的源帧, NULL为不创建;
         参数7: 压缩数据的分配器, NULL为默认;
         参数8: 压缩回调
         参数9: 客户端定义的输出回调
         参数10:新的压缩对象的指针地址.
         */
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressionOutputCallback, (__bridge void *)(self), &self->_encodingSession);
        NSLog(@"H264: %d", (int)status);
        
        // 2. 设置实时编码输出 (避免延时)
        VTSessionSetProperty(self.encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(self.encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        // 3. 设置关键帧间隔 GOPsize
        int frameInterval = 10;
        CFNumberRef frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
        VTSessionSetProperty(self.encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
        // 4. 设置期望帧率
        int fps = 10;
        CFNumberRef fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
        VTSessionSetProperty(self.encodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
        // 5. 设置码率均值, 单位byte
        int bitRate = width * height * 3 * 4 * 8;
        CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
        VTSessionSetProperty(self.encodingSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
        // 6. 设置码率界限, 单位bps
        int bitRateLimit = width * height * 3 * 4;
        CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRateLimit);
        VTSessionSetProperty(self.encodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
        
        // 7. 开始编码
        VTCompressionSessionPrepareToEncodeFrames(self.encodingSession);
    });
}

#pragma mark VTCompressionOutputCallback

void didCompressionOutputCallback(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    
    if (status != 0) {
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    
    H264VideoEncoder *encoder = (__bridge H264VideoEncoder *)outputCallbackRefCon;
    
    bool keyFrame = !CFDictionaryContainsKey(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), kCMSampleAttachmentKey_NotSync);
    
    // 判断当前帧是否为关键帧
    // 获取SPS & PPS 数据
    if (keyFrame)
    {
        
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t sParameterSetSize, sParameterSetCount;
        
        const uint8_t *sParameterSet;
        
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sParameterSet, &sParameterSetSize, &sParameterSetCount, 0);
        
        if (statusCode == noErr)
        {
            // 查找sps 检测pps
            size_t pParameterSetSize, pParameterSetCount;
            const uint8_t *pParameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pParameterSet, &pParameterSetSize, &pParameterSetCount, 0);
            
            if (statusCode == noErr)
            {
                //                查找pps
                NSData *sps = [NSData dataWithBytes:sParameterSet length:sParameterSetSize];
                NSData *pps = [NSData dataWithBytes:pParameterSet length:pParameterSetSize];
                
                if (encoder) {
                    [encoder gotSps:sps pps:pps];
                }

            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus sta = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    
    if (sta == noErr) {
        size_t bufferOffset = 0;
        //
        static const int AVCCHeaderLength = 4;
        
        // 循环获取NALU数据
        
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            uint32_t NALUnitLength = 0;
            
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData *data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];

            
            [encoder gotEncodedData:data isKeyFrame:keyFrame];
            
            bufferOffset += AVCCHeaderLength + NALUnitLength;
            
        }
        
    }
    
}

- (void)encode:(CMSampleBufferRef)sampleBuffer {
    // 1. 获取媒体数据中的imageBuffer.
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 2. 创建时间戳  参数1: value  参数2: 时间刻度.
    CMTime presentationTimeStamp = CMTimeMake(frameID++, 1000);
    // 3. 声明编码状态信息Flags(此信息Flags非错误信息Flags)
    VTEncodeInfoFlags flags;
    
    /* 4. VTCompressionSessionEncodeFrame 将帧呈现给压缩会话进行编码.
     参数1: 压缩会话.
     参数2: 要压缩的视频帧的CVImageBuffer对象, 此对象引用计数不能为0.
     参数3: 时间戳, 传递给会话的每个时间戳必须大于上一个时间戳.
     参数4: 帧的持续呈现时间?  如果没有, 用kCMTimeInvalid初始化一个无效的CMTime.
     参数5: 包含用于编码该帧的附加属性的键/值对, 改变之后, 会影响后续的编码帧.
     参数6: 回传到输出回调函数的 sourceFrame值.
     参数7: 编码状态信息指针
     */
    OSStatus status = VTCompressionSessionEncodeFrame(self.encodingSession, imageBuffer, presentationTimeStamp, kCMTimeInvalid, NULL, NULL, &flags);
    
    if (status != noErr) {
        NSLog(@"H264: FAILED with %d", (int)status);
        [self destroyEncoderSession];
        return;
    }
    
    NSLog(@"H264: SUCCEED with %d", (int)status);
}

- (void)destroyEncoderSession {
    // 1. 强制压缩会话完成编码帧
    VTCompressionSessionCompleteFrames(self.encodingSession, kCMTimeInvalid);
    // 2. 完成压缩后调用VTCompressionSessionInvalidate 使会话无效.
    VTCompressionSessionInvalidate(self.encodingSession);
    // 3. 调用CFRelease释放压缩会话.
    CFRelease(self.encodingSession);
    // 4. 置为NULL;
    self.encodingSession = NULL;
}



- (void)gotSps:(NSData *)sps pps:(NSData *)pps {
    
    if ([self.delegate respondsToSelector:@selector(encodedSPS:pps:byteHeader:)]) {
        [self.delegate encodedSPS:sps pps:pps byteHeader:self.byteHeader];
    }
}

- (void)gotEncodedData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame {
    
    if ([self.delegate respondsToSelector:@selector(encodedNALU:isKeyFrame:byteHeader:)]) {
        
        [self.delegate encodedNALU:data isKeyFrame:isKeyFrame byteHeader:self.byteHeader];
    }
}




@end
