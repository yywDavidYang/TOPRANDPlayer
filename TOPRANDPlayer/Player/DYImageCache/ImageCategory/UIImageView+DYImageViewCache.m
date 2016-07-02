//
//  UIImageView+DYImageViewCache.m
//  DYImageCache
//
//  Created by apple on 16/5/27.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import "UIImageView+DYImageViewCache.h"
#import "DYImageCacheManager.h"

@implementation UIImageView (DYImageViewCache)

- (void) dy_setImageWithUrl:(NSString *)url progressBlock:(DownloaderProgressBlock)progressBlock complect:(DownloaderCompletedBlock)completedBlock{
    __weak __typeof(self)weaks = self;
    [[DYImageCacheManager shareCacheManagerInstance] downImageWithURL:url DownloaderProgressBlock:^(NSInteger alreadyDownloadSize,NSInteger expectedContentLength){
        
        if (progressBlock) {
            NSLog(@"进度1");
            progressBlock(alreadyDownloadSize,expectedContentLength);
        }
    } DownloaderCompletedBlock:^(NSData *data,UIImage *image,NSError *error,BOOL finished){
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            weaks.image = image;
            [weaks setNeedsLayout];
            if (completedBlock) {
                completedBlock(data,image,error,YES);
            }
        });
    }];
}

- (void) dy_setImageWithUrl:(NSString *)url placeholderImage:(UIImage *)placeholderImage{
    __weak __typeof(self)weaks = self;
    self.image = placeholderImage;
    [[DYImageCacheManager shareCacheManagerInstance] downImageWithURL:url DownloaderProgressBlock:^(NSInteger alreadyDownloadSize,NSInteger expectedContentLength){
        
    } DownloaderCompletedBlock:^(NSData *data,UIImage *image,NSError *error,BOOL finished){
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image) {
                
                weaks.image = placeholderImage;
            }
            else{
                
                weaks.image = image;
            }
            [weaks setNeedsLayout];
        });
    }];
}

@end
