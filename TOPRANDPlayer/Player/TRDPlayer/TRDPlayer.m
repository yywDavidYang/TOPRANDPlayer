//
//  TRDPlayer.m
//  TOPRANDPlayer
//
//  Created by apple on 16/6/4.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import "TRDPlayer.h"
#import "Masonry.h"
#import "TRDPlayerView.h"
#import "UIImageView+DYImageViewCache.h"

@interface TRDPlayer()<TRDPlayerViewDelegate>

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UITapGestureRecognizer *playTapGesture;
@property (nonatomic, copy) NSString *imagePath;
@property (nonatomic, copy) NSString *videoPath;
@property (nonatomic, strong) NSDictionary *dictParameter;
@property (nonatomic, strong) TRDPlayerView *player;

@end
@implementation TRDPlayer
- (instancetype) initWithContentPath:(NSString *)videoPath
                          parameters:(NSDictionary *)parameters
                     backgorundImage:(NSString *)imagePath
                               frame:(CGRect)frame{
    
    self = [self init];
    if (self) {
        self.frame = frame;
        _videoPath = videoPath;
        _imagePath = imagePath;
        _dictParameter = parameters;
        self.backgroundColor = [UIColor blueColor];
        [self setBackgroundImageView];
    }
    return self;
}

- (void) setBackgroundImageView{

    _imageView = ({

        UIImageView *imageView = [[UIImageView alloc]init];
        imageView.userInteractionEnabled = YES;
        [imageView dy_setImageWithUrl:_imagePath placeholderImage:nil];
        imageView.frame = self.bounds;
        [self addSubview:imageView];
        _playTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        _playTapGesture.numberOfTapsRequired = 1;
        [imageView addGestureRecognizer:_playTapGesture];
        imageView;
    });

    UIImageView *imageView = [[UIImageView alloc]init];
    imageView.image = [UIImage imageNamed:@"video_play_btn_bg"];
    imageView.backgroundColor = [UIColor clearColor];
    [_imageView addSubview:imageView];
    [imageView mas_makeConstraints:^(MASConstraintMaker *make){
    
        make.centerX.equalTo(_imageView.mas_centerX);
        make.centerY.equalTo(_imageView.mas_centerY);
        make.size.mas_equalTo(40);
    }];
}

- (void) handleTap:(UITapGestureRecognizer *)recognizer{
    
    [self loadPlayerView];
}
- (void)loadPlayerView{
    
    _player = [[TRDPlayerView alloc]initWithContentPath:_videoPath
                                             parameters:_dictParameter
                                                  frame:self.imageView.bounds
                                    backgroundImagePath:_imagePath];
    _player.delegate = self;
    [self.imageView addSubview:_player];
    [_player mas_makeConstraints:^(MASConstraintMaker *make){
        
        make.edges.equalTo(self.imageView);
    }];
}

- (void)deletePlayerView{
    
    [_player removeFromSuperview];
}

- (void)freedMemmory{
    
    [_player receiveMemoryWarning];
}
@end
