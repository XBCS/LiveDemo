//
//  H264VideoEncoder.h
//  LiveDemo
//
//  Created by 李泽宇 on 2018/4/23.
//  Copyright © 2018年 丶信步沧桑. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol H264VideoEncoderDelegate <NSObject>

- (void)encodedSPS:(NSData *)sps pps:(NSData *)pps byteHeader:(NSData *)byteHeader;
- (void)encodedNALU:(NSData *)nalu isKeyFrame:(BOOL)isKeyFrame byteHeader:(NSData *)byteHeader;

@end

@interface H264VideoEncoder : NSObject

@property (nonatomic, weak) id<H264VideoEncoderDelegate> delegate;

+ (instancetype)h264VideoEncoderWithDelegate:(id)delegate;

- (void)createEncoder;

- (void)encode:(CMSampleBufferRef)sampleBuffer;

- (void)destroyEncoderSession;

@end
