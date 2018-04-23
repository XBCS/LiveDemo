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
#import "H264VideoEncoder.h"

@interface CollectionVC () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, H264VideoEncoderDelegate>

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

@property (nonatomic, assign) dispatch_queue_t captureQueue;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) H264VideoEncoder *videoEncoder;

@end

@implementation CollectionVC

#pragma mark - ###################### LifeCycle Methods ####################

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.captureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    self.videoEncoder = [H264VideoEncoder h264VideoEncoderWithDelegate:self];
    
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"xbcs.h264"];
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
    
    [self createCapture];
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
#pragma mark  H264VideoEncoderDelegate

- (void)encodedSPS:(NSData *)sps pps:(NSData *)pps byteHeader:(NSData *)byteHeader {
    if (self.fileHandle != NULL) {
        [self.fileHandle writeData:byteHeader];
        [self.fileHandle writeData:sps];
        [self.fileHandle writeData:byteHeader];
        [self.fileHandle writeData:pps];
    }
}
- (void)encodedNALU:(NSData *)nalu isKeyFrame:(BOOL)isKeyFrame byteHeader:(NSData *)byteHeader {
    
    if (self.fileHandle != NULL) {
        [self.fileHandle writeData:byteHeader];
        [self.fileHandle writeData:nalu];
    }
}

#pragma mark  AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
        if ([self.videoDataOutput isEqual:captureOutput]) {
            
            [self.videoEncoder encode:sampleBuffer];
            
        } else if ([self.audioDataOutput isEqual:captureOutput]) {
            
            // TODO : 编码.
            
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
    
    [self previedLayer];
    // 创建编码会话
    [self.videoEncoder createEncoder];
    [self.captureSession startRunning];
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
