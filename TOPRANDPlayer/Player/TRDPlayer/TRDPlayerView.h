//
//  TRDPlayerView.h
//  TOPRANDPlayer
//
//  Created by apple on 16/6/2.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * const KxMovieParameterMinBufferedDuration;    // Float
extern NSString * const KxMovieParameterMaxBufferedDuration;    // Float
extern NSString * const KxMovieParameterDisableDeinterlacing;   // BOOL

@protocol TRDPlayerViewDelegate <NSObject>

- (void) deletePlayerView;

@end

@interface TRDPlayerView : UIView

@property (readonly) BOOL playing;
@property (weak,nonatomic) id<TRDPlayerViewDelegate>delegate;
- (instancetype) initWithContentPath:(NSString *)path
                          parameters:(NSDictionary *)dictparameters
                               frame:(CGRect)frame
                 backgroundImagePath:(NSString *)imagePath;
// 返回以后
- (void)deallocRemovePlayerResource;

// 防止内存警告
- (void) receiveMemoryWarning;

@end
