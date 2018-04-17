//
//  CollectionVC.m
//  LiveDemo
//
//  Created by 李泽宇 on 2018/4/11.
//  Copyright © 2018年 丶信步沧桑. All rights reserved.
//

#import "CollectionVC.h"
#import <AVFoundation/AVFoundation.h>

#import <VideoToolbox/VideoToolbox.h>


@interface CollectionVC () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
{
    int frameID;
    
}


@property (nonatomic, strong) AVCaptureDeviceInput *frontCamera;
@property (nonatomic, strong) AVCaptureDeviceInput *backCamera;
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previedLayer;
@property (nonatomic, strong) UIView *previedView;
@property (nonatomic, weak) AVCaptureConnection *videoConnection;

@property (nonatomic, assign) VTCompressionSessionRef encodingSession;
@property (nonatomic, assign) CMFormatDescriptionRef format;

@property (nonatomic, assign) dispatch_queue_t captureQueue;
@property (nonatomic, assign) dispatch_queue_t encoderQueue;

@property (nonatomic, strong) NSFileHandle *fileHandle;

@end

@implementation CollectionVC

#pragma mark - ###################### LifeCycle Methods ####################

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.captureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.encoderQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"xbcs.h264"];
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
    
    [self createCapture];
    [self createEncoder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [self destroyCaptureSession];
}

#pragma mark - ###################### Public Methods #######################
#pragma mark - ###################### Events Methods #######################
#pragma mark - ###################### Delegate & CallBack #####################

#pragma mark VTCompressionOutputCallback

void didCompressionOutputCallback(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    
    if (status != 0) {
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    
    CollectionVC *encoder = (__bridge CollectionVC *)outputCallbackRefCon;
    
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

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
        if ([self.videoDataOutput isEqual:captureOutput]) {
            
            [self encode:sampleBuffer];
            // TODO : 发送数据.
            
            
        } else if ([self.audioDataOutput isEqual:captureOutput]) {
            
            
            // TODO : 编码, 发送数据.
            
        }
    
}

#pragma mark - ###################### Private Methods ######################

- (void)createCapture {
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    self.frontCamera = [AVCaptureDeviceInput deviceInputWithDevice:devices.firstObject error:nil];
    self.backCamera = [AVCaptureDeviceInput deviceInputWithDevice:devices.lastObject error:nil];
    
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    self.audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    
    self.videoInput = self.frontCamera;
    
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.captureQueue];
    
    // 抛弃延迟的帧
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    // 设置像素输出格式
    NSNumber *formatType = [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    NSDictionary *outputSetting = [NSDictionary dictionaryWithObject:formatType forKey:(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey];
    [self.videoDataOutput setVideoSettings:outputSetting];
    
    
    self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioDataOutput setSampleBufferDelegate:self queue:self.captureQueue];
    
    
    
    // 创建会话
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession beginConfiguration];
    
    if ([self.captureSession canAddInput:self.videoInput]) {
        [self.captureSession addInput:self.videoInput];
    }
    
    if ([self.captureSession canAddInput:self.audioInput]) {
        [self.captureSession addInput:self.audioInput];
    }
    
    if ([self.captureSession canAddOutput:self.videoDataOutput]) {
        [self.captureSession addOutput:self.videoDataOutput];
    }
    
    if ([self.captureSession canAddOutput:self.audioDataOutput]) {
        [self.captureSession addOutput:self.audioDataOutput];
    }
    

    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    }
    
    [self.captureSession commitConfiguration];
    
    [self.captureSession startRunning];
    [self previedLayer];
}

- (void)createEncoder {
    
    dispatch_sync(self.encoderQueue, ^{
        self->frameID = 0;
        int width = 480;
        int height = 640;
        
        /*
         1. 创建Session
         
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

- (void)encode:(CMSampleBufferRef)sampleBuffer {
    
    CVImageBufferRef imageBuffer =CMSampleBufferGetImageBuffer(sampleBuffer);
    CMTime presentationTimeStamp = CMTimeMake(frameID++, 1000);
    VTEncodeInfoFlags flags;
    OSStatus status = VTCompressionSessionEncodeFrame(self.encodingSession, imageBuffer, presentationTimeStamp, kCMTimeInvalid, NULL, NULL, &flags);
    
    if (status != noErr) {
        
        NSLog(@"H264: FAILED with %d", (int)status);
        VTCompressionSessionInvalidate(self.encodingSession);
        CFRelease(self.encodingSession);
        self.encodingSession = NULL;
        return;
    }
    
    NSLog(@"H264: SUCCEED with %d", (int)status);
}

- (void)gotSps:(NSData *)sps pps:(NSData *)pps {
    
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
    
    [self.fileHandle writeData:byteHeader];
    [self.fileHandle writeData:sps];
    [self.fileHandle writeData:byteHeader];
    [self.fileHandle writeData:pps];
    
}

- (void)gotEncodedData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame {
    
    if (self.fileHandle != NULL) {
        
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1;
        NSData *byteHeader = [NSData dataWithBytes:bytes length:length];
        [self.fileHandle writeData:byteHeader];
        [self.fileHandle writeData:data];
    }
    
    
}




//销毁会话
- (void)destroyCaptureSession {
    if (self.captureSession) {
        [self.captureSession removeInput:self.audioInput];
        [self.captureSession removeInput:self.videoInput];
        [self.captureSession removeOutput:self.self.videoDataOutput];
        [self.captureSession removeOutput:self.self.audioDataOutput];
        self.captureSession = nil;
    }
    [self.fileHandle closeFile];
    self.fileHandle = NULL;
}

- (void)destroyEncoderSession {
    VTCompressionSessionCompleteFrames(self.encodingSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(self.encodingSession);
    CFRelease(self.encodingSession);
    self.encodingSession = NULL;
}

#pragma mark - ###################### Getter & Setter ######################

- (UIView *)previedView {
    if (!_previedView) {
        _previedView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [self.view addSubview:_previedView];
    }
    return _previedView;
}

- (AVCaptureVideoPreviewLayer *)previedLayer {
    if (!_previedLayer) {
        _previedLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
        _previedLayer.frame = self.previedView.bounds;
        [self.previedView.layer addSublayer:_previedLayer];
    }
    return _previedLayer;
}





@end
