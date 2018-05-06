//
//  ViewController.m
//  LiveDemo
//
//  Created by 李泽宇 on 2018/4/9.
//  Copyright © 2018年 丶信步沧桑. All rights reserved.
//

#import "ViewController.h"
#import "CollectionVC.h"
#import <objc/runtime.h>


@interface ViewController ()


@property (nonatomic, strong) UIButton *collection;
@property (nonatomic, strong) UIButton *play;

@property (nonatomic, copy) NSString *s;
@property (nonatomic, weak) NSString *w;

@end

@implementation ViewController


#pragma mark - ###################### LifeCycle Methods ####################

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    self.s = [NSString stringWithFormat:@"ssss"];
//    self.w = self.s;
//    self.s = nil;
//    NSLog(@"%@",self.w);
//    
////    class_addIvar(<#Class  _Nullable __unsafe_unretained cls#>, <#const char * _Nonnull name#>, <#size_t size#>, <#uint8_t alignment#>, <#const char * _Nullable types#>)
////    NSGetSizeAndAlignment(<#const char * _Nonnull typePtr#>, <#NSUInteger * _Nullable sizep#>, <#NSUInteger * _Nullable alignp#>)
//    
//    
//    
////    unsigned int numIvars;
////    Ivar *vars = class_copyIvarList(NSClassFromString(@"UIView"), &numIvars);
////
////    NSString *key = nil;
////
////    for (int i =0; i < numIvars; i++) {
////
////        Ivar this = vars[i];
////
////        key = [NSString stringWithUTF8String:ivar_getName(this)];
////        NSLog(@"variable name: %@", key);
////        key = [NSString stringWithUTF8String:ivar_getTypeEncoding(this)];
////        NSLog(@"variable type: %@", key);
////    }
////    free(vars);
//    
//    
//    NSUInteger size;
//    NSUInteger alignment;
//    NSGetSizeAndAlignment("NSString", &size, &alignment);
//    NSLog(@"%lu, %lu", size, alignment);
//    NSGetSizeAndAlignment("*", &size, &alignment);
//    NSLog(@"%lu, %lu", size, alignment);
//    NSGetSizeAndAlignment("int", &size, &alignment);
//    NSLog(@"%lu, %lu", size, alignment);
//    
////    Class c = objc_getClass("NSObject");
//    
//    
//    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
//    
//    for (int i = 0 ; i< 9999; i++) {
//        
//        @autoreleasepool{
//        UITableView *view = [[UITableView alloc] initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStylePlain];
//        view.separatorColor = [UIColor redColor];
//        }
////        NSLog(@"%@", s);
//    }
//    CFAbsoluteTime link = CFAbsoluteTimeGetCurrent() - start;
//    
//    NSLog(@"%f", link*1000.0);
//    
    
    
    
    [self setUpLayout];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSLog(@"%@", self.w);
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
