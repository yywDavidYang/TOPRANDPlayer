//
//  DYImageDownloader.m
//  DYImageCache
//
//  Created by apple on 16/5/26.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import "DYImageDownloader.h"
#import "DYDownloaderOperation.h"

@interface DYImageDownloader()

// 下载对列
@property (nonatomic, strong) NSOperationQueue *downloadQueue;

/**
 *  将所有的下载回调信息存储在这里，Key是URL，Value是多组回调信息
 */
@property (nonatomic, strong) NSMutableDictionary *downloaderCallBack;

@property (nonatomic, strong) dispatch_queue_t concurrentQueue;

@end

@implementation DYImageDownloader

- (instancetype) init{
    
    self = [super init];
    if (self) {
        
        _downloadQueue = [[NSOperationQueue alloc]init];
        _downloadQueue.maxConcurrentOperationCount = 4;
        _concurrentQueue = dispatch_queue_create("com.toprand.DYImageCache", DISPATCH_QUEUE_CONCURRENT);
        _downloaderCallBack = [[NSMutableDictionary alloc]init];
    }
    return self;
}

+ (instancetype) shareDownloadInstance{
   
    static DYImageDownloader *downloader;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
    
        downloader  = [[DYImageDownloader alloc]init];
        
    });
    return downloader;
}


- (void) downloaderImageWithUrl:(NSURL *)url
        DownloaderProgressBlock:(DownloaderProgressBlock)progressBlock
       DownloaderCompletedBlock:(DownloaderCompletedBlock)completedBlock{
    
    __weak __typeof(self)weakSelf = self;
    __block DYDownloaderOperation *operation;
    
    [self addWithDownloaderProgressBlock:progressBlock DownloaderCompletedBlock:completedBlock Url:url DownloaderCreateBlock:^{
    
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url
                                                                    cachePolicy: NSURLRequestReloadIgnoringLocalCacheData
                                                                timeoutInterval:30];
        operation = [[DYDownloaderOperation alloc]initWithRequest:request
                                                DownloaderOptions:1
                                          DownloaderProgressBlock:^(NSInteger alreadyDownloadSize,NSInteger expectedContentLength){
                                              
                                              
                                              NSLog(@"下载进度3 alreadyReceiveSize = %ld,expectedContentLength = %ld",(long)alreadyDownloadSize,(long)expectedContentLength);
                                             
                                              __block NSArray *urlCallBacks;
                                              dispatch_sync(self.concurrentQueue, ^{
                                              
                                                  urlCallBacks = [weakSelf.downloaderCallBack[url] copy];
                                              });
                                              
                                              for (NSDictionary *callbacks in  urlCallBacks) {
                                                  // 主线程刷新UI
                                                  dispatch_async(dispatch_get_main_queue(), ^{
                                                  
                                                      DownloaderProgressBlock progress = callbacks[@"progress"];
                                                      if (progressBlock) {
                                                          
                                                          progress(alreadyDownloadSize,expectedContentLength);
                                                      }
                                                  });
                                              }
                                              
                                          } DownloaderCompletedBlock:^(NSData *data,UIImage *image,NSError *error,BOOL finished){
                                              __block NSArray *urlCallBacks;
                                              dispatch_barrier_sync(weakSelf.concurrentQueue, ^{
                                                  
                                                  urlCallBacks = [weakSelf.downloaderCallBack[url] copy];
                                                  if (finished) {
                                                      
                                                      [weakSelf.downloaderCallBack removeObjectForKey:url];
                                                  }
                                              });
                                              for (NSDictionary *callBack in  urlCallBacks) {
                                                  
                                                  dispatch_sync(self.concurrentQueue, ^{
                                                  
                                                      DownloaderCompletedBlock completed = callBack[@"completed"];
                                                      if (completed) {
                                                          
                                                          completed(data,image,error,finished);
                                                      }
                                                  
                                                  });
                                              }
        
                                          } cancelled:^{
                                              
                                              dispatch_barrier_sync(weakSelf.concurrentQueue, ^{
                                              
                                                  [weakSelf.downloaderCallBack removeObjectForKey:url];
                                              });
                                              
                                          }];
        
       [weakSelf.downloadQueue addOperation:operation];
    
    }];
    
}

- (void) addWithDownloaderProgressBlock:(DownloaderProgressBlock)progressBlock
               DownloaderCompletedBlock:(DownloaderCompletedBlock )completedBlock
                                    Url:(NSURL *)url
                  DownloaderCreateBlock:(DownloaderCreateBlock )downloaderCreateBlock{
    
   // 判断url是否为空
    if ([url isEqual:nil]) {
        
        completedBlock(nil,nil,nil,NO);
    }
    //
    dispatch_barrier_sync(self.concurrentQueue, ^{
    
        BOOL firstDownload = NO;
        
        // 添加回调信息，处理同一个url信息,url为key，array为Value
        if (!self.downloaderCallBack[url]) {
            
            self.downloaderCallBack[url] = [NSMutableArray new];
            firstDownload = YES;
        }
       
        NSMutableArray *callBacksArray = self.downloaderCallBack[url];
        NSMutableDictionary *callBacks = [[NSMutableDictionary alloc]init];
        // 添加key-value
        if (progressBlock) {
            
            callBacks[@"progress"] = [progressBlock copy];
        }
        
        if (completedBlock) {
            callBacks[@"completed"] = [completedBlock copy];
        }
        
        [callBacksArray addObject:callBacks];
        self.downloaderCallBack[url] = callBacksArray;
        if (firstDownload) {
            downloaderCreateBlock();
        }
    });
}
@end












































