//
//  TRDSessionModel.h
//  TOPRANDPlayer
//
//  Created by apple on 16/6/14.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum {

    DownloadSateStart = 0,
    DownloadStateSuspended,
    DownloadStateCompleted,
    DownloadStateFailed,
    
}DownloadState;

//typedef void(^ProgressBlock)(NSInteger receivedSize,NSInteger expectedSize,CGFloat progress);

@interface TRDSessionModel : NSObject


/** 流*/
@property (nonatomic,strong) NSOutputStream *stream;
/** 下载地址*/
@property (nonatomic,copy) NSString *url;
/** 返回数据的总长度*/
@property (nonatomic,assign) NSInteger totalLength;
/** 下载的进度*/
@property(nonatomic,copy) void(^ProgressBlock)(NSInteger receivedSize,NSInteger expectedSize,CGFloat progress);

/** 下载的状态*/
@property (nonatomic,copy) void(^stateBlock)(DownloadState state);




@end
