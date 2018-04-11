//
//  ViewController.m
//  LiveDemo
//
//  Created by 李泽宇 on 2018/4/9.
//  Copyright © 2018年 丶信步沧桑. All rights reserved.
//

#import "ViewController.h"
#import "CollectionVC.h"


@interface ViewController ()


@property (nonatomic, strong) UIButton *collection;
@property (nonatomic, strong) UIButton *play;

@end

@implementation ViewController


#pragma mark - ###################### LifeCycle Methods ####################

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setUpLayout];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}
#pragma mark - ###################### Public Methods #######################

#pragma mark - ###################### Events Methods #######################


#pragma mark - ###################### Delegate Methods #####################

#pragma mark - ###################### Private Methods ######################
- (void)setUpLayout {
    [self.collection mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_offset(100.f);
        make.left.right.mas_equalTo(self.view);
        make.height.mas_equalTo(80.f);
    }];
    
    [self.play mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.collection.mas_bottom).offset(20.f);
        make.left.right.height.mas_equalTo(self.collection);
    }];
    
}

#pragma mark - ###################### Getter & Setter ######################

- (UIButton *)collection {
    
    if (!_collection) {
        _collection = [[UIButton alloc] init];
        [self.view addSubview:_collection];
        [_collection setTitle:@"采集编码" forState:UIControlStateNormal];
        [_collection setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        typeof(self) __weak tsWeakSelf = self;
        
        [[_collection rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(__kindof UIControl * _Nullable x) {
            
            // Open Camera
            CollectionVC *vc = [[CollectionVC alloc] init];
            [tsWeakSelf.navigationController pushViewController:vc animated:YES];
            NSLog(@"collection");
            
        }];
        
    }
    return _collection;
}

- (UIButton *)play {
    if (!_play) {
        _play = [[UIButton alloc] init];
        [_play setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
        [self.view addSubview:_play];
        [_play setTitle:@"拉流解码播放" forState:UIControlStateNormal];
        [[_play rac_signalForControlEvents:UIControlEventTouchUpInside] subscribeNext:^(__kindof UIControl * _Nullable x) {
           // Open ijk
            NSLog(@"play");
        }];
    }
    return _play;
}


@end
