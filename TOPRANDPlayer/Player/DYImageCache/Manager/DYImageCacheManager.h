//
//  DYImageCacheManager.h
//  DYImageCache
//
//  Created by apple on 16/5/27.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DYImageDownloader.h"

@interface DYImageCacheManager : NSObject

+ (DYImageCacheManager *) shareCacheManagerInstance;
- (void) downImageWithURL:(NSString *)urlString
  DownloaderProgressBlock:(DownloaderProgressBlock)progressBlock
 DownloaderCompletedBlock:(DownloaderCompletedBlock)completedBlock;


@end
