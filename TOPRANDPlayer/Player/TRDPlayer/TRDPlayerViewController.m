//
//  TRDPlayerViewController.m
//  TOPRANDPlayer
//
//  Created by apple on 16/6/2.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import "TRDPlayerViewController.h"
#include "avformat.h"
#include "avcodec.h"
#import "TRDPlayerView.h"
#import "TRDPlayer.h"

@interface TRDPlayerViewController ()

@property (nonatomic,strong) TRDPlayerView *playerView;
@property (nonatomic,strong) TRDPlayer *player;

@end

@implementation TRDPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor yellowColor];
   
    
    [self createUI];
}

- (void) createUI{
    NSString *path = @"rtmp://live.hkstv.hk.lxdns.com/live/hks";
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
//  远程播放
//  path = @"http://120.25.226.186:32812/resources/videos/minion_01.mp4";
//  本地播放
//    path = [[[NSBundle mainBundle] URLForResource:@"02" withExtension:@"mov"] absoluteString];
    NSString *imagePath = @"http://vimg3.ws.126.net/image/snapshot/2016/5/2/C/VBNGGTN2C.jpg";
    if (!path)return;
    if ([path.pathExtension isEqualToString:@"wmv"])
        parameters[KxMovieParameterMinBufferedDuration] = @(5.0);
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        parameters[KxMovieParameterDisableDeinterlacing] = @(YES);
    CGRect frame = CGRectMake(0, 150,self.view.bounds.size.width, 250);
    _player = [[TRDPlayer alloc]initWithContentPath:path
                                         parameters:parameters
                                    backgorundImage:imagePath
                                              frame:frame];
    
    [self.view addSubview:_player];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
   
}

- (void)dealloc{
    // 返回后，要清除播放器
    [_playerView deallocRemovePlayerResource];
    NSLog(@"返回");
}

@end
