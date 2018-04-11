//
//  CollectionVC.m
//  LiveDemo
//
//  Created by 李泽宇 on 2018/4/11.
//  Copyright © 2018年 丶信步沧桑. All rights reserved.
//

#import "CollectionVC.h"
#import <AVFoundation/AVFoundation.h>



@interface CollectionVC () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>


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


@end

@implementation CollectionVC

#pragma mark - ###################### LifeCycle Methods ####################

- (void)viewDidLoad {
    [super viewDidLoad];
    [self creatCapture];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [self destroyCaptureSession];
}

#pragma mark - ###################### Public Methods #######################
//销毁会话
- (void)destroyCaptureSession {
    if (self.captureSession) {
        [self.captureSession removeInput:self.audioInput];
        [self.captureSession removeInput:self.videoInput];
        [self.captureSession removeOutput:self.self.videoDataOutput];
        [self.captureSession removeOutput:self.self.audioDataOutput];
    }
    self.captureSession = nil;
}

#pragma mark - ###################### Events Methods #######################
#pragma mark - ###################### Delegate Methods #####################

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
        if ([self.videoDataOutput isEqual:captureOutput]) {
            // TODO : 编码, 发送数据.
            NSLog(@"\n\n\n--%@\n\n--%@\n\n\n", sampleBuffer, connection);
        } else if ([self.audioDataOutput isEqual:captureOutput]) {
            // TODO : 编码, 发送数据.
            NSLog(@"\n\n\n--%@\n\n--%@\n\n\n", sampleBuffer, connection);
        }
    
}

#pragma mark - ###################### Private Methods ######################

- (void)creatCapture {
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    self.frontCamera = [AVCaptureDeviceInput deviceInputWithDevice:devices.firstObject error:nil];
    self.backCamera = [AVCaptureDeviceInput deviceInputWithDevice:devices.lastObject error:nil];
    
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    self.audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    
    self.videoInput = self.frontCamera;
    
    dispatch_queue_t captureQueue = dispatch_queue_create("com.caputreQueue.queue", DISPATCH_QUEUE_SERIAL);
    
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoDataOutput setSampleBufferDelegate:self queue:captureQueue];
    
    // 抛弃延迟的帧
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
    // 设置像素输出格式
    NSNumber *formatType = [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
    NSDictionary *outputSetting = [NSDictionary dictionaryWithObject:formatType forKey:(__bridge NSString *)kCVPixelBufferPixelFormatTypeKey];
    [self.videoDataOutput setVideoSettings:outputSetting];
    
    
    self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioDataOutput setSampleBufferDelegate:self queue:captureQueue];
    
    
    
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
