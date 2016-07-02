//
//  DYImageDownloader.h
//  DYImageCache
//
//  Created by apple on 16/5/26.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_OPTIONS(NSInteger, DownloaderOption){
    
    // 默认下载操作
    DownloaderDefault = 1,
    
    // 允许后台操作
    DownloaderContinueInBackground = 2
    
};

typedef NS_ENUM(NSInteger, DownloaderOrder) {

    // 默认下载顺序，先进先出
    DownloaderFIFO,
    
    // 先进后出
    DownloaderLIFO
};

// 无参数回调
typedef void (^DownloaderCreateBlock)();

// 下载回调进度
typedef void(^DownloaderProgressBlock)(NSInteger alreadyDownloadSize,NSInteger expectedContentLength);

// 下载完成回调Block
typedef void(^DownloaderCompletedBlock)(NSData *data,UIImage *image,NSError *error,BOOL finished);


@interface DYImageDownloader : NSObject

+ (instancetype) shareDownloadInstance;
- (void) downloaderImageWithUrl:(NSURL *)url
        DownloaderProgressBlock:(DownloaderProgressBlock)progressBlock
       DownloaderCompletedBlock:(DownloaderCompletedBlock)completedBlock;

@end
