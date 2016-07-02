//
//  DYDownloaderOperation.m
//  DYImageCache
//
//  Created by apple on 16/5/26.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import "DYDownloaderOperation.h"

@interface  DYDownloaderOperation()<NSURLSessionDataDelegate>

@property (nonatomic, strong) NSMutableData *imageData;

@end

@implementation DYDownloaderOperation

- (instancetype) initWithRequest:(NSMutableURLRequest *)request
               DownloaderOptions:(DownloaderOption)options
         DownloaderProgressBlock:(DownloaderProgressBlock)progressBlock
        DownloaderCompletedBlock:(DownloaderCompletedBlock)completedBlock
                       cancelled:(DownloaderCreateBlock)canclledBlock{

    self = [super init];
    if (self) {
        _request        = request;
        _cancelBlock    = canclledBlock;
        _progressBlock  = progressBlock;
        _options        = options;
        _completedBlock = completedBlock;
        _expectedContentLength = 0;
    }
    return self;
}

- (void) start{
    
    if (self.cancelled) {
        
        return;
    }
    /**
     * 创建NSURLSessionConfiguration类的对象, 这个对象被用于创建NSURLSession类的对象.
     */
    NSURLSessionConfiguration *configure = [NSURLSessionConfiguration defaultSessionConfiguration];
    /**
     * 2. 创建NSURLSession的对象.
     * 参数一 : NSURLSessionConfiguration类的对象.(第1步创建的对象.)
     * 参数二 : session的代理人. 如果为nil, 系统将会提供一个代理人.
     * 参数三 : 一个队列, 代理方法在这个队列中执行. 如果为nil, 系统会自动创建一系列的队列.
     * 注: 只能通过这个方法给session设置代理人, 因为在NSURLSession中delegate属性是只读的.
     */
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configure delegate:self delegateQueue:nil];
    /**
     *  创建request
     */
    NSMutableURLRequest *request = self.request;
    /**
     *  创建数据类型任务
     */
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request];
    /**
     *  开始任务
     */
    [dataTask resume];
    /**
     *  在session中的所有任务都完成之后, 使session失效.
     */
    [session finishTasksAndInvalidate];
}
// 结束线程
- (void) cancel{
    
    if (self.cancelBlock) {
        
        self.cancelBlock();
        [self clear];
    }
}
// 最先调用，做数据的初始化。
- (void) URLSession:(NSURLSession *)session
           dataTask:(NSURLSessionDataTask *)dataTask
 didReceiveResponse:(nonnull NSURLResponse *)response
  completionHandler:(nonnull void (^)(NSURLSessionResponseDisposition))completionHandler{
    NSLog(@"最先调用");
    self.imageData = [[NSMutableData alloc]init];
    self.expectedContentLength = response.expectedContentLength;
    if (self.isCancelled) {
        
        _imageData = nil;
    }
    if (self.progressBlock) {
        
        self.progressBlock(0,self.expectedContentLength);
    }
    // 这必须要实现，否则下载过程无法回调
    completionHandler(NSURLSessionResponseAllow);
}
// 下载过程响应
- (void) URLSession:(NSURLSession *)session
           dataTask:(NSURLSessionDataTask *)dataTask
     didReceiveData:(NSData *)data{
    // 将下载回来的数据进行拼接
    [self.imageData appendData:data];
    if (self.progressBlock) {
        
        self.progressBlock(self.imageData.length,self.expectedContentLength);
    }
}
// 下载完成后的回调
- (void) URLSession:(NSURLSession *)session
               task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error{
    
    NSLog(@"下载完成");
    if(!error){
        
        UIImage *image = [UIImage imageWithData:self.imageData];
        self.completedBlock(self.imageData,image,nil,YES);
        [self cancel];
    }
    else{
        NSLog(@"error = %@",error);
        self.completedBlock(self.imageData,nil,error,NO);
        [self cancel];
    }
}

/**
 *  清空
 */
-(void)clear{
    
    _request        = nil;
    _cancelBlock    = nil;
    _progressBlock  = nil;
    _options        = 1;
    _completedBlock = nil;
    _expectedContentLength = 0;
}


@end

























