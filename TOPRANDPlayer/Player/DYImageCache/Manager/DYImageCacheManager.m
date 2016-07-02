//
//  DYImageCacheManager.m
//  DYImageCache
//
//  Created by apple on 16/5/27.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import "DYImageCacheManager.h"
#import "DYImageDownloader.h"
#import "DYImageCache.h"

@implementation DYImageCacheManager

+ (DYImageCacheManager *) shareCacheManagerInstance{
    
    static DYImageCacheManager *cacheManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        cacheManager  = [[DYImageCacheManager  alloc]init];
        
    });
    return cacheManager;
}

- (void) downImageWithURL:(NSString *)urlString
  DownloaderProgressBlock:(DownloaderProgressBlock)progressBlock
 DownloaderCompletedBlock:(DownloaderCompletedBlock)completedBlock{
    
    NSURL *url = [NSURL URLWithString:urlString];
    [[DYImageCache shareInstance] selectImageWithKey:urlString completedBlock:^(UIImage *image,NSError *error,ImageCacheType type){
    
        if (image) {
            dispatch_async(dispatch_get_main_queue(), ^{
            
                NSData *data = UIImagePNGRepresentation(image);
                completedBlock(data,image,error,YES);
                NSLog(@"读取缓存");
            });
        }
        else{
            NSLog(@"进入下载");
            [[DYImageDownloader shareDownloadInstance] downloaderImageWithUrl:url DownloaderProgressBlock:^(NSInteger alreadyReceiveSize,NSInteger expectedContentLength){
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"下载进度2 alreadyReceiveSize = %ld,expectedContentLength = %ld",(long)alreadyReceiveSize,(long)expectedContentLength);
                    progressBlock(alreadyReceiveSize,expectedContentLength);
                });
            } DownloaderCompletedBlock:^(NSData *data,UIImage *image,NSError *error,BOOL finished){
            
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                    
                    [[DYImageCache shareInstance]saveImageWithMemoryCache:nil image:image imageData:data urlKey:urlString isSaveToDisk:YES];
                });
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    completedBlock(data,image,error,YES);
                });
            }];
        }
    
    }];
}

@end
































