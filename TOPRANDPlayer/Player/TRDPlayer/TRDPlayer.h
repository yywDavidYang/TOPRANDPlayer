//
//  TRDPlayer.h
//  TOPRANDPlayer
//
//  Created by apple on 16/6/4.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TRDPlayer : UIView


- (instancetype) initWithContentPath:(NSString *)videoPath
                          parameters:(NSDictionary *)parameters
                     backgorundImage:(NSString *)imagePath
                               frame:(CGRect)frame;
// 释放内存
- (void)freedMemmory;
@end
