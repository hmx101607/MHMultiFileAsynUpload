//
//  MHUploadManager.m
//  Module-Common
//
//  Created by mason on 2018/8/2.
//

#import "MHUploadManager.h"
#import "MHURLSessionTaskOperation.h"
#import <AFNetworking/AFNetworking.h>

#define kMaxConcurrentOperationCount 3

@interface MHUploadManager ()

/** 操作队列 */
@property (strong, nonatomic) NSOperationQueue *operationQueue;
/** 上传的任务数 */
@property (strong, nonatomic) NSMutableArray *uploadTask;
/** 队列最大操作数 */
@property (assign, nonatomic) NSInteger maxConcurrentOperationCount;
/** 远程地址 */
@property (strong, nonatomic) NSString *uploadRequestUrl;
/** 自定义参数<##> */
@property (strong, nonatomic) NSDictionary *customParameter;

@end

@implementation MHUploadManager

+ (instancetype)shareManager {
    static MHUploadManager *uploadManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uploadManager = [[MHUploadManager alloc] init];
        uploadManager.operationQueue = [[NSOperationQueue alloc] init];
        uploadManager.uploadTask = [NSMutableArray array];
        uploadManager.maxConcurrentOperationCount = kMaxConcurrentOperationCount;
        [uploadManager.operationQueue setMaxConcurrentOperationCount:kMaxConcurrentOperationCount];
    });
    return uploadManager;
}

+ (void)setMaxConcurrentOperationCount:(NSInteger)count {
    [MHUploadManager shareManager].maxConcurrentOperationCount = count;
    [[MHUploadManager shareManager].operationQueue setMaxConcurrentOperationCount:count];
}

+ (void)setUploadRequestUrl:(NSString *)requestUrl {
    [MHUploadManager shareManager].uploadRequestUrl = requestUrl;
}

+ (void)setCustomParameter:(NSDictionary *)customParameter {
    [MHUploadManager shareManager].customParameter = customParameter;
}

+ (void) uploadImages:(NSArray *)images
             progress:(uploadProgressBlock)uploadProgressBlock
              success:(uploadSuccessBlock)uploadSuccessBlock
              failure:(uploadFailureBlock)uploadFailureBlock
{
    __block NSMutableArray* result = [NSMutableArray array];
    [[MHUploadManager shareManager].uploadTask addObjectsFromArray:images];
    for (UIImage* images in images) {
        [result addObject:[NSNull null]];
    }
    for (NSInteger i = 0; i < [MHUploadManager shareManager].uploadTask.count; i++) {
//        HZBaseImageModel *baseImageModel = [MHUploadManager shareManager].uploadTask[i];
//        NSString *sourceName = [NSString stringWithFormat:@"%@.png",[NSString stringWithUUID]];
//        MHURLSessionTaskOperation *operation = [MHURLSessionTaskOperation operationWithURLSessionTask:nil sessionBlock:^NSURLSessionDataTask * {
//            NSURLSessionUploadTask *task = [MHUploadManager uploadTaskImage:baseImageModel.source sourceName:sourceName progress:^(NSProgress *uploadProgress) {
//                if (uploadProgressBlock) {
//                    uploadProgressBlock(i, uploadProgress);
//                }
//            } completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
//                if (!error) {
//                    @synchronized (result) {
//                        result[i] = @{@"sourceName" : STRING_OR_EMPTY(sourceName),
//                                      @"responseObject" : responseObject
//                                      };
//
//                        DLog(@"CurrentOperationCount : %ld", [MHUploadManager shareManager].operationQueue.operationCount);
//                        if ([MHUploadManager shareManager].operationQueue.operationCount == 0) {
//                            [[MHUploadManager shareManager].uploadTask removeAllObjects];
//                            if (uploadSuccessBlock) {
//                                uploadSuccessBlock(result);
//                            }
//                        }
//                    }
//                } else {
//                    if (uploadFailureBlock) {
//                        [[MHUploadManager shareManager].uploadTask removeAllObjects];
//                        [[MHUploadManager shareManager].operationQueue cancelAllOperations];
//                        uploadFailureBlock(error);
//                    }
//                }
//            }];
//            return task;
//        }];
//        [[MHUploadManager shareManager].operationQueue addOperation:operation];
    }
}

+ (NSURLSessionUploadTask *) uploadTaskImage:(UIImage *)image
                                  sourceName:(NSString *)sourceName
                                    progress:(void (^)(NSProgress *uploadProgress)) uploadProgressBlock
                           completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler {
    @autoreleasepool {
//        NSAssert(![GGUtil stringIsEmpty:[MHUploadManager shareManager].uploadRequestUrl], @"上传地址不能为空！");
        NSString *url = [MHUploadManager shareManager].uploadRequestUrl;
        NSDictionary *parameter = [MHUploadManager shareManager].customParameter;
        NSError* error = NULL;
        NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:url parameters:parameter constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
            NSData *imageData = UIImageJPEGRepresentation(image, 0.6);
            [formData appendPartWithFileData:imageData name:@"file" fileName:sourceName mimeType:@"multipart/form-data"];
        } error:&error];

        AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        AFHTTPResponseSerializer *responseSerializer = manager.responseSerializer;
        [responseSerializer setAcceptableContentTypes:[NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript",@"text/html",@"text/css",@"text/plain", @"application/javascript",@"application/json", @"application/x-www-form-urlencoded", nil]];
        
        manager.responseSerializer = responseSerializer;
        
        NSURLSessionUploadTask *task = [manager uploadTaskWithStreamedRequest:request progress:uploadProgressBlock completionHandler:completionHandler];
        return task;
    }
}

- (void)dealloc {
    NSLog(@"%s销毁", __func__);
}

@end
