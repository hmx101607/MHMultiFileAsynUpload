//
//  MHUploadManager.h
//  Module-Common
//
//  Created by mason on 2018/8/2.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "MHUploadModel.h"

typedef void(^uploadSuccessBlock)(id responseObject);
typedef void(^uploadFailureBlock)(NSError *error);
typedef  void(^uploadProgressBlock)(NSInteger *index, NSProgress *uploadProgress);


@protocol MHUploadManagerDelegate <NSObject>

@optional
- (void)uploadStartWithUploadModel:(MHUploadModel *)uploadModel;
- (void)uploadProgressWithUploadModel:(MHUploadModel *)uploadModel;
- (void)uploadCompletionWithUploadModel:(MHUploadModel *)uploadModel error:(NSError *)error;

- (void)uploadAllTaskCompletionWithUploadModel:(NSArray <MHUploadModel *> *)uploadModels error:(NSError *)error;

/** 获取服务器返回的数据：回调解析 */
- (NSString *)fetchUrlWithResponse:(NSDictionary *)response;

@end


@interface MHUploadManager : NSObject

@property (weak, nonatomic) id<MHUploadManagerDelegate>delegate;

+ (instancetype)shareManager;

/**
 最大并发数

 @param count 数值
 */
+ (void)setMaxConcurrentOperationCount:(NSInteger)count;

/**
 添加队列

 @param uploadModel 对象
 */
- (void)addDownloadQueue:(MHUploadModel *)uploadModel;


///** 取消上传 */
//+ (void)cancel;
///** 取消上传 */
//+ (void)suspend;
///** 重新开始上传 */
//+ (void)restart;

@end
