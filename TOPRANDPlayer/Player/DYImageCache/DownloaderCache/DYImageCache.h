//
//  DYImageCache.h
//  DYImageCache
//
//  Created by apple on 16/5/27.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger,ImageCacheType){
    /**
     * 无类型
     */
    ImageCacheTypeNone,
    /**
     * 磁盘中缓存
     */
    ImageCacheTypeDisk,
    /**
     * 内存中缓存
     */
    ImageCacheTypeMemory
};

/**
 *  CompletedBlock
 *
 *  @param image 图片
 *  @param error 错误信息
 *  @param type  读取类型
 */
typedef void(^CompletedBlock)(UIImage *image,NSError *error,ImageCacheType type);

/**
 *  无参Block
 */
typedef void(^NoParamsBlock)();

@interface DYImageCache : NSObject

/**
 *  最大缓存大小
 */
@property (assign, nonatomic) NSUInteger maxCacheSize;

+ (DYImageCache *) shareInstance;
- (instancetype) initWithCacheSpace:(NSString *)path;
- (void) saveImageWithMemoryCache:(NSCache *)memoryCache
                            image:(UIImage *)image
                        imageData:(NSData *)imageData
                           urlKey:(NSString *)urlKey
                     isSaveToDisk:(BOOL) isSaveToDisk;
// 查询图片
- (void) selectImageWithKey:(NSString *)urlKey
             completedBlock:(CompletedBlock)completed;
// 全部清空
- (void) clearDiskOnCompletion:(NoParamsBlock)completion;
// 按条件进行清空（主要是时间）
- (void) clearDiskWithNoPatamsBlock:(NoParamsBlock)noParamsBlock;


@end
