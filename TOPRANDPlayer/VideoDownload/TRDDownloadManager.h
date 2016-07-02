//
//  TRDDownloadManager.h
//  TOPRANDPlayer
//
//  Created by apple on 16/6/14.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TRDSessionModel.h"

@interface TRDDownloadManager : NSObject
/**
 *  单例
 *
 *  @return 返回单例的对象
 */
+ (instancetype)sharedInstance;

/**
 *  开启任务下载资源
 *
 *  @param url           视频下载的链接
 *  @param progressBlock 下载进度回调
 *  @param stateBlock    下载状态回调
 */
- (void) download:(NSString *)url
         progress:(void (^)(NSInteger,NSInteger,CGFloat))progressBlock
            state:(void (^)(DownloadState))stateBlock;

/**
 *  查询该资源的下载进度值
 *
 *  @param url 下载地址
 *
 *  @return 返回下载进度值
 */
- (CGFloat)progress:(NSString *)url;

/**
 *  获取该资源总大小
 *
 *  @param url 下载地址
 *
 *  @return 资源总大小
 */
- (NSInteger)fileTotalLength:(NSString *)url;

/**
 *  判断该资源是否下载完成
 *
 *  @param url 下载地址
 *
 *  @return YES: 完成
 */
- (BOOL)isCompletion:(NSString *)url;

/**
 *  删除该资源
 *
 *  @param url 下载地址
 */
- (void)deleteFile:(NSString *)url;

/**
 *  清空所有下载资源
 */
- (void)deleteAllFile;

/**
 *  开始下载
 *
 *  @param url 下载视频的链接
 */
- (void) start:(NSString *)url;

/**
 *  暂停下载
 *
 *  @param url 下载视频的链接
 */
- (void)pause:(NSString *)url;

/**
 *  返回视频保存的地址
 *
 *  @param url 视频下载链接
 *
 *  @return 视频保存的本地地址
 */
- (NSString *)videoDownloadUrl:(NSString *)url;

@end
