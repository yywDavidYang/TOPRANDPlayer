//
//  UIImageView+DYImageViewCache.h
//  DYImageCache
//
//  Created by apple on 16/5/27.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "DYImageDownloader.h"

@interface UIImageView (DYImageViewCache)
 
- (void) dy_setImageWithUrl:(NSString *)url
              progressBlock:(DownloaderProgressBlock)progressBlock
                   complect:(DownloaderCompletedBlock)completedBlock;
- (void) dy_setImageWithUrl:(NSString *)url
           placeholderImage:(UIImage *)placeholderImage;

@end
