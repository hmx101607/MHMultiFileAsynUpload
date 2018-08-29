//
//  MHUploadManager.h
//  Module-Common
//
//  Created by mason on 2018/8/2.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

typedef void(^uploadSuccessBlock)(id responseObject);
typedef void(^uploadFailureBlock)(NSError *error);
typedef  void(^uploadProgressBlock)(NSInteger *index, NSProgress *uploadProgress);

@interface MHUploadManager : NSObject



+ (void) uploadImages:(NSArray *)images
             progress:(uploadProgressBlock)uploadProgressBlock
              success:(uploadSuccessBlock)successBlock
              failure:(uploadFailureBlock)failureBlock;

/**
 最大并发数

 @param count 数值
 */
+ (void)setMaxConcurrentOperationCount:(NSInteger)count;

/**
 上传地址

 @param requestUrl
 */
+ (void)setUploadRequestUrl:(NSString *)requestUrl;

/**
 自定义参数

 @param customParameter
 */
+ (void)setCustomParameter:(NSDictionary *)customParameter;

/** 取消上传 */
+ (void)cancel;
/** 取消上传 */
+ (void)suspend;
/** 重新开始上传 */
+ (void)restart;

@end
