//
//  DYDownloaderOperation.h
//  DYImageCache
//
//  Created by apple on 16/5/26.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DYImageDownloader.h"

@interface DYDownloaderOperation : NSOperation
// 实时进度回调
@property (nonatomic, copy) DownloaderProgressBlock progressBlock;
// 下载完成回调
@property (nonatomic, copy) DownloaderCompletedBlock completedBlock;
// 无参数返回
@property (nonatomic, copy) DownloaderCreateBlock   cancelBlock;
// 
@property (nonatomic, assign) NSInteger expectedContentLength;

// 下载操作方式
@property (nonatomic, assign) DownloaderOption options;

// 缓存请求
@property (strong, nonatomic) NSMutableURLRequest *request;


- (instancetype) initWithRequest:(NSMutableURLRequest *)request
               DownloaderOptions:(DownloaderOption)options
         DownloaderProgressBlock:(DownloaderProgressBlock)progressBlock
        DownloaderCompletedBlock:(DownloaderCompletedBlock)completedBlock
                       cancelled:(DownloaderCreateBlock)canclledBlock;

@end
