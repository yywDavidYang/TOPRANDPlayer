//
//  TRDDownloadManager.m
//  TOPRANDPlayer
//
//  Created by apple on 16/6/14.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

// 缓存主目录
#define HSCachesDirectory [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"HSCache"]
// 保存文件名
#define HSFileName(url) url.md5String
// 文件的存放路径（caches）
#define HSFileFullpath(url) [HSCachesDirectory stringByAppendingPathComponent:HSFileName(url)]
// 文件的已下载长度
#define HSDownloadLength(url) [[[NSFileManager defaultManager] attributesOfItemAtPath:HSFileFullpath(url) error:nil][NSFileSize] integerValue]
// 存储文件总长度的文件路径（caches）
#define HSTotalLengthFullpath [HSCachesDirectory stringByAppendingPathComponent:@"totalLength.plist"]

#import "TRDDownloadManager.h"
#import "NSString+Hash.h"

@interface TRDDownloadManager()<NSCopying, NSURLSessionDelegate>

/** 保存所有任务(注：用下载地址md5后作为key) */
@property (nonatomic, strong) NSMutableDictionary *tasks;
/** 保存所有下载相关信息 */
@property (nonatomic, strong) NSMutableDictionary *sessionModels;

@end

@implementation TRDDownloadManager



- (NSMutableDictionary *)tasks{
    
    if (!_tasks) {
        
        _tasks = [NSMutableDictionary dictionary];
    }
    
    return _tasks;
}

- (NSMutableDictionary *)sessionModels{
    
    if (!_sessionModels) {
        
        _sessionModels = [NSMutableDictionary dictionary];
    }
    
    return _sessionModels;
}

static TRDDownloadManager *_downloadManager;

//当用户使用alloc init方法创建实体类是，也可以保证所创建的事例对象是同一个。
+(instancetype)allocWithZone:(struct _NSZone *)zone{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        _downloadManager = [super allocWithZone:zone];
    });
    return _downloadManager;
}

//重写copyWithZone方法，可以保证用户在使用copy关键字时，创建的类的实例是同一个。
- (nonnull id) copyWithZone:(NSZone *)zone{
    
    return _downloadManager;
}

// 单例
+ (instancetype)sharedInstance{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _downloadManager = [[self alloc]init];
    });
    return _downloadManager;
}

// 创建缓存目录文件
- (void) createCacheDirectory{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:HSCachesDirectory]) {
        
        [fileManager createDirectoryAtPath:HSCachesDirectory
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:NULL];
    }
}

// 开启任务
- (void) download:(NSString *)url progress:(void (^)(NSInteger,NSInteger,CGFloat))progressBlock state:(void (^)(DownloadState))stateBlock{
    
    //判断url是否为空
    if(!url) return;
    // 是否已经下载完成
    if([self isCompletion:url]){
        
        stateBlock(DownloadStateCompleted);
        NSLog(@"----该资源已下载完成");
        return;
    }
    // 暂停
    if([self.tasks valueForKey:HSFileName(url)]){
        
        [self handle:url];
        return;
    }
    // 创建缓存目录文件
    [self createCacheDirectory];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[[NSOperationQueue alloc]init]];
    // 创建流,将数据流写到路径文件中
    NSOutputStream *stream = [NSOutputStream outputStreamToFileAtPath:HSFileFullpath(url) append:YES];
    // 创建请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    
    // 设置请求头
    NSString *range = [NSString stringWithFormat:@"bytes=%zd-",HSDownloadLength(url)];
    [request setValue:range forHTTPHeaderField:@"Range"];
    
    // 创建一个Data任务
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    NSUInteger taskIdentifier = arc4random() %((arc4random() % 10000 + arc4random()% 10000));
    [task setValue:@(taskIdentifier) forKeyPath:@"taskIdentifier"];
    // 保存已经创建的任务
    [self.tasks setValue:task forKey:HSFileName(url)];
    
    TRDSessionModel *sessionModel = [[TRDSessionModel alloc]init];
    sessionModel.url = url;
    sessionModel.ProgressBlock = progressBlock;
    sessionModel.stateBlock = stateBlock;
    sessionModel.stream = stream;
    [self.sessionModels setValue:sessionModel forKey:@(task.taskIdentifier).stringValue];
    [self start:url];
}
// 判断是否已经下载完成
- (BOOL) isCompletion:(NSString *)url{
    
    if ([self fileTotalLength:url] && HSDownloadLength(url) == [self fileTotalLength:url]) {
        
        return YES;
    }
    return NO;
}

// 获取该资源的总大小

- (NSInteger)fileTotalLength:(NSString *)url{
    
    return [[NSDictionary dictionaryWithContentsOfFile:HSTotalLengthFullpath][HSFileName(url)] integerValue];
}

- (void) handle:(NSString *)url{
    
    NSURLSessionDataTask *task = [self getTask:url];
    if (task.state == NSURLSessionTaskStateRunning) {
        
        [self pause:url];
    }
    else{
        
        [self start:url];
    }
}

// 开始下载
- (void) start:(NSString *)url{
    
    NSURLSessionDataTask *task = [self getTask:url];
    [task resume];
    [self getSessionModel:task.taskIdentifier].stateBlock(DownloadSateStart);
}

// 暂停下载
- (void)pause:(NSString *)url{
    
    NSURLSessionDataTask *dataTask = [self getTask:url];
    [dataTask suspend];
    [self getSessionModel:dataTask.taskIdentifier].stateBlock(DownloadStateSuspended);
}

// 根据url获取对应的下载任务
- (NSURLSessionDataTask *)getTask:(NSString *)url{
    
    return (NSURLSessionDataTask *)[self.tasks valueForKey:HSFileName(url)];
}

// 根据url获取对应的下载信息模型
- (TRDSessionModel *)getSessionModel:(NSUInteger)taskIdentify{
    
    return (TRDSessionModel *)[self.sessionModels valueForKey:@(taskIdentify).stringValue];
}

/**
 *  查询资源的下载进度
 */
- (CGFloat)progress:(NSString *)url{
    
    return [self fileTotalLength:url] == 0?0.0:1.0*HSDownloadLength(url) / [self fileTotalLength:url];
}

/**
 *  删除已下载的资源
 */
- (void) deleteFile:(NSString *)url{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:HSFileFullpath(url)]) {
        
        // 删除沙盒中的资源
        [fileManager removeItemAtPath:HSFileFullpath(url) error:nil];
        // 删除任务
        [self.tasks removeObjectForKey:HSFileName(url)];
        [self.sessionModels removeObjectForKey:@([self getTask:url].taskIdentifier).stringValue];
        // 删除资源的总长度
        if ([fileManager fileExistsAtPath:HSTotalLengthFullpath]) {
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:HSTotalLengthFullpath];
            [dict removeObjectForKey:HSFileName(url)];
            [dict writeToFile:HSTotalLengthFullpath atomically:YES];
        }
    }
}

/**
 *  清空所有的下载资源
 */

- (void)deleteAllFile{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:HSCachesDirectory]) {
        
        // 删除沙河中所有资源
        [fileManager removeItemAtPath:HSCachesDirectory error:nil];
        // 删除任务
        [[self.tasks allValues] makeObjectsPerformSelector:@selector(cancel)];
        [self.tasks removeAllObjects];
        
        for (TRDSessionModel *sessionModel in [self.sessionModels allValues]) {
            
            [sessionModel.stream close];
        }
        [self.sessionModels removeAllObjects];
        
        // 删除资源的总长度
        if ([fileManager fileExistsAtPath:HSTotalLengthFullpath]) {
            
            [fileManager removeItemAtPath:HSTotalLengthFullpath error:nil];
        }
    }
}

#pragma mark - 代理
#pragma mark NSURLSessionDataDelegate
/**
 *  接收响应
 */
- (void) URLSession:(NSURLSession *)session
           dataTask:(nonnull NSURLSessionDataTask *)dataTask
 didReceiveResponse:(nonnull NSURLResponse *)response
  completionHandler:(nonnull void (^)(NSURLSessionResponseDisposition))completionHandler{
    
    TRDSessionModel *sessionModel = [self getSessionModel:dataTask.taskIdentifier];
    // 打开流
    [sessionModel.stream open];
    // 获得服务器首次请求，返回数据的总长度
    NSInteger totalLength = response.expectedContentLength + HSDownloadLength(sessionModel.url);
    sessionModel.totalLength = totalLength;
    // 存储总长度
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:HSTotalLengthFullpath];
    if (dict == nil) {
        
        dict = [NSMutableDictionary dictionary];
    }
    dict[HSFileName(sessionModel.url)] = @(totalLength);
    [dict writeToFile:HSTotalLengthFullpath atomically:YES];
    // 接收这个请求，
    completionHandler(NSURLSessionResponseAllow);
}

/**
 *  接收服务器返回的数据
 */
- (void) URLSession:(NSURLSession *)session
           dataTask:(nonnull NSURLSessionDataTask *)dataTask
     didReceiveData:(nonnull NSData *)data{
    
    TRDSessionModel *sessionModel = [self getSessionModel:dataTask.taskIdentifier];
    // 写入数据
    [sessionModel.stream write:data.bytes maxLength:data.length];
    // 下载进度
    NSUInteger receivedSize = HSDownloadLength(sessionModel.url);
    NSUInteger expectedSize = sessionModel.totalLength;
    CGFloat progress = 1.0 * receivedSize / expectedSize;
    sessionModel.ProgressBlock(receivedSize,expectedSize,progress);
}

/**
 *  请求完毕，成功或者失败
 */
- (void) URLSession:(NSURLSession *)session task:(nonnull NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error{
    
    TRDSessionModel *sessionModel = [self getSessionModel:task.taskIdentifier];
    if (!sessionModel) return;
    
    if ([self isCompletion:sessionModel.url]) {
        
        NSLog(@"下载完成");
        sessionModel.stateBlock(DownloadStateCompleted);
    }
    else if (error){
        NSLog(@"下载失败");
        sessionModel.stateBlock(DownloadStateFailed);
    }
    
    // 关闭流
    [sessionModel.stream close];
    sessionModel.stream = nil;
    
    // 清除任务
    [self.tasks removeObjectForKey:HSFileName(sessionModel.url)];
    [self.sessionModels removeObjectForKey:@(task.taskIdentifier).stringValue];
}
/**
 *  获取video的本地路径
 */
- (NSString *)videoDownloadUrl:(NSString *)url{
    
    return HSFileFullpath(url);
}

@end










