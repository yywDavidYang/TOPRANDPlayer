//
//  DYImageCache.m
//  DYImageCache
//
//  Created by apple on 16/5/27.
//  Copyright © 2016年 TOPRAND. All rights reserved.
//

#import "DYImageCache.h"
#import <CommonCrypto/CommonDigest.h>

@interface DYImageCache()

@property (nonatomic, strong) NSCache *memoryCache;
@property (nonatomic, strong) NSString *diskCachePath;
@property (nonatomic, strong) dispatch_queue_t ioSerialQueue;
@property (nonatomic, strong) NSFileManager *fileManager;

@end

@implementation DYImageCache

+ (DYImageCache *) shareInstance{
    
    static DYImageCache *imageCache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        imageCache  = [[DYImageCache  alloc]init];
        
    });
    return imageCache;
}

- (id)init{

    return [self initWithCacheSpace:@"default"];
}

- (instancetype) initWithCacheSpace:(NSString *)path{
    
    self = [super init];
    if (self) {
        
        NSString *filePath = [@"com.toprand.DYImageCache" stringByAppendingString:path];
        // 创建串行队列
        _ioSerialQueue = dispatch_queue_create("com.toprand.ioSerialQueue", DISPATCH_QUEUE_SERIAL);
        // 初始化内存缓存
        _memoryCache = [[NSCache alloc]init];
        _memoryCache.name = filePath;
        // 获取Cache目录路径，初始化磁盘缓存路径
        NSArray *cacPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        _diskCachePath = [[cacPath objectAtIndex:0] stringByAppendingString:filePath];
        
        // 初始化fileManager
        dispatch_sync(self.ioSerialQueue, ^{
        
            _fileManager = [NSFileManager defaultManager];
        });
    }
    return  self;
}

- (void) saveImageWithMemoryCache:(NSCache *)memoryCache image:(UIImage *)image imageData:(NSData *)imageData urlKey:(NSString *)urlKey isSaveToDisk:(BOOL) isSaveToDisk{
    NSLog(@"---->image = %@, urlKey = %@",image,urlKey);
    // 防止image为空
    if (image) {
         // 保存在默认的路径
        if(memoryCache == nil){
        
            [_memoryCache setObject:image forKey:urlKey];
        }
        else{
            // 保存在用户指定的内存
            [memoryCache setObject:image forKey:urlKey];
        }
    
        // 磁盘缓存
        if(isSaveToDisk){
        
            dispatch_sync(self.ioSerialQueue, ^{
        
                if ([_fileManager fileExistsAtPath:_diskCachePath]) {
                
                    [_fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:nil];
                }

                NSString *pathForKey = [self defaultCachePathForKey:urlKey];
                NSLog(@"%@",pathForKey);
                [_fileManager createFileAtPath:pathForKey contents:imageData attributes:nil];
            });
        }
    }
}


// 查询图片
- (void) selectImageWithKey:(NSString *)urlKey completedBlock:(CompletedBlock)completed{
    // 从内存中读取图片
    UIImage *image = [self.memoryCache objectForKey:urlKey];
    if (image != nil) {
        
        completed(image,nil,ImageCacheTypeMemory);
    }
    else{
        // 从文件中读取图片
        // 获取图片的文件路径
        NSString *pathForKey = [self defaultCachePathForKey:urlKey];
        NSLog(@"%@",pathForKey);
        NSData *imageData = [NSData dataWithContentsOfFile:pathForKey];
        UIImage *diskImage = [UIImage imageWithData:imageData];
        dispatch_async(dispatch_get_main_queue(), ^{
        
            completed(diskImage,nil,ImageCacheTypeDisk);
        });
    }
}

// 全部清空
- (void) clearDiskOnCompletion:(NoParamsBlock)completion{
    
    dispatch_async(self.ioSerialQueue, ^{

        [_fileManager removeItemAtPath:self.diskCachePath error:nil];
        [_fileManager createDirectoryAtPath:self.diskCachePath
                withIntermediateDirectories:YES
                                 attributes:nil error:NULL];
        if (completion) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
            
                completion();
            });
        }
    });
}

// 按条件进行清空（主要是时间）
- (void) clearDiskWithNoPatamsBlock:(NoParamsBlock)noParamsBlock{
    
    dispatch_async(self.ioSerialQueue, ^{
    
        NSURL *diskCache = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
        NSArray *resourcKyes = @[NSURLIsDirectoryKey,NSURLContentModificationDateKey,NSURLTotalFileAllocatedSizeKey];
        // 枚举器预先获取缓存文件的有用的属性
        NSDirectoryEnumerator *fileEnumerator =  [_fileManager enumeratorAtURL:diskCache
                                                    includingPropertiesForKeys:resourcKyes
                                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                  errorHandler:NULL];
        NSDate *expirationData = [NSDate dateWithTimeIntervalSinceNow:-60 * 60 * 24 * 7];
        NSMutableDictionary *cacheFiles = [NSMutableDictionary dictionary];
        NSInteger currentCacheSize = 0;
        NSMutableArray *urlsToDelete = [[NSMutableArray alloc]init];
        
        for (NSURL *fileUrl in fileEnumerator) {
            
            NSDictionary *resourceValues = [fileUrl resourceValuesForKeys:resourcKyes error:NULL];
            // 跳过文件夹
            if([resourceValues[NSURLIsDirectoryKey]  boolValue]){
                
                continue;
            }
            
            NSDate *modificationDate = resourceValues[NSURLContentModificationDateKey];
            if ([[modificationDate laterDate:expirationData] isEqualToDate:expirationData]) {
                
                [urlsToDelete addObject:fileUrl];
                continue;
            }
            
            // 存储文件的引用并计算所有的文件的总大小，以备后用
            NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
            currentCacheSize += [totalAllocatedSize unsignedIntegerValue];
            [cacheFiles setObject:resourceValues forKey:fileUrl];
        }
        
        for (NSURL *fileUrl in urlsToDelete) {
            
            [self.fileManager removeItemAtURL:fileUrl error:NULL];
        }
        if (self.maxCacheSize > 0 && currentCacheSize > self.maxCacheSize) {
            
            const NSUInteger desiredCacheSize = self.maxCacheSize/2;
            // Sort the remaining cache files by their last modification time (oldest first).
            NSArray *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent usingComparator:^NSComparisonResult (id obj1,id obj2){
              
                return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
            }];
            // Delete files until we fall below our desired cache size.
            for (NSURL *fileURL in sortedFiles) {
                
                if ([_fileManager removeItemAtURL:fileURL error:nil]) {
                    
                    NSDictionary *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= [totalAllocatedSize unsignedIntegerValue];
                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        if (noParamsBlock) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
            
                noParamsBlock();
            });
        }
    
    });
}


- (NSString *) defaultCachePathForKey:(NSString *)key{
    
    return [self cachePathForKey:key inPath:self.diskCachePath];
}

- (NSString *)cachePathForKey:(NSString *)key inPath:(NSString *) path{
    
    NSString *fileName = [self cacheFileNameForKey:key];
    return [path stringByAppendingString:fileName];
}

/**
 *  盗用了SDWebImage的设计,将文件名按照MD5进行命名，保持唯一性
 *
 *  @param key urlKey
 *
 *  @return 文件名是对key值做MD5摘要后的串
 */
- (NSString *) cacheFileNameForKey:(NSString *)key{
    
    const char *str = [key UTF8String];
    if (str == NULL) {
        
        str = "";
    }
    
    unsigned char r[16];
    CC_MD5(str, (uint32_t)strlen(str), r);
    NSString *fileName = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",r[0],r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8],r[9],r[10],r[11],r[12],r[13],r[14],r[15]];
    return fileName;
}

@end























