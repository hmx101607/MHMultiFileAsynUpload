//
//  MHUploadManager.m
//  Module-Common
//
//  Created by mason on 2018/8/2.
//

#import "MHUploadManager.h"
#import "MHURLSessionTaskOperation.h"
#import <AFNetworking/AFNetworking.h>
#import "MHUtil.h"

#define kMaxConcurrentOperationCount 3

@interface MHUploadManager ()
<
NSURLSessionDataDelegate
>

/** 操作队列 */
@property (strong, nonatomic) NSOperationQueue *operationQueue;
/** 上传的任务数 */
@property (strong, nonatomic) NSMutableArray *uploadTasks;
/** 队列最大操作数 */
@property (assign, nonatomic) NSInteger maxConcurrentOperationCount;

@end

@implementation MHUploadManager

+ (instancetype)shareManager {
    static MHUploadManager *uploadManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uploadManager = [[MHUploadManager alloc] init];
        uploadManager.operationQueue = [[NSOperationQueue alloc] init];
        uploadManager.uploadTasks = [NSMutableArray array];
        uploadManager.maxConcurrentOperationCount = kMaxConcurrentOperationCount;
        [uploadManager.operationQueue setMaxConcurrentOperationCount:kMaxConcurrentOperationCount];
        
    });
    return uploadManager;
}

+ (void)setMaxConcurrentOperationCount:(NSInteger)count {
    [MHUploadManager shareManager].maxConcurrentOperationCount = count;
    [[MHUploadManager shareManager].operationQueue setMaxConcurrentOperationCount:count];
}

/**
 添加队列
 
 @param uploadModel 对象
 */
- (void)addDownloadQueue:(MHUploadModel *)uploadModel {
    NSAssert(![MHUtil stringIsEmpty:uploadModel.uploadRequestUrl], @"服务器地址不能为空！");
    NSAssert(![MHUtil stringIsEmpty:uploadModel.fileName], @"文件名称不能为空！");
    MHUploadModel *originModel = [self fetchUploadModelWithFileName:uploadModel.fileName];
    if (originModel) {
        return;
    }
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,  NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:uploadModel.fileName];
    NSLog(@"path : %@", path);
    uploadModel.filePath = path;
    BOOL success = [[NSFileManager defaultManager] createFileAtPath:path contents:uploadModel.fileData attributes:nil];
    if (success) {
        [self.uploadTasks addObject:uploadModel];
        [self startUploadWithModel:uploadModel];
    }
}

#pragma mark - 开始下载
- (void)startUploadWithModel:(MHUploadModel *)uploadModel {
    uploadModel.uploadStatus = MHUploadStatusUploadWait;
    NSURLSessionDataTask *task = uploadModel.task;
    if (task && task.state == NSURLSessionTaskStateRunning) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    MHURLSessionTaskOperation *operation = [MHURLSessionTaskOperation operationWithURLSessionTask:nil sessionBlock:^NSURLSessionTask *{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSLog(@"thread : %@, MHCustomOperation operationWithURLSessionTask", [NSThread currentThread]);
        return [strongSelf uploadTaskWithUploadModel:uploadModel];
    }];
    [self.operationQueue addOperation:operation];
}

- (NSURLSessionUploadTask *) uploadTaskWithUploadModel:(MHUploadModel *)uploadModel
{
    NSDictionary *params = uploadModel.customParameter;
    NSString *path = uploadModel.filePath;
    // 请求的Url
    NSString *urlStr = [uploadModel.uploadRequestUrl stringByAppendingFormat:@"&fileName=%@",uploadModel.fileName];
    NSURL *url = [NSURL URLWithString:urlStr];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    
    NSString *boundary = [self generateBoundaryString];
    // 设置ContentType
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    NSString *fieldName = uploadModel.fileName;
    NSData *httpBody = [self createBodyWithBoundary:boundary parameters:params paths:@[path] fieldName:fieldName];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    NSLog(@"thread : %@, 执行下载 --- %s", [NSThread currentThread], __func__);
    
    NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request fromData:httpBody];
    uploadModel.task = uploadTask;
    return uploadTask;
}

#pragma mark - +++++++++++++++++++++ NSURLSessionDataDelegate start ++++++++++++++++++++++++
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSLog(@"thread : %@, 开始下载 --- %s", [NSThread currentThread], __func__);
    
    completionHandler (NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend {
    NSString *fileName = [self fetchFileNameWithUrl:task.currentRequest.URL.absoluteString];
    if ([MHUtil stringIsEmpty:fileName]) {
        return;
    }
    MHUploadModel *uploadModel = [self fetchUploadModelWithFileName:fileName];
    uploadModel.currentSize = totalBytesSent;
    uploadModel.totalSize = totalBytesExpectedToSend;
    if (bytesSent == totalBytesExpectedToSend) {
        //说明正式开始上传：更新数据库文件的状态，以及需要上传的文件总大小
        uploadModel.uploadStatus = MHUploadStatusUploading;
        if ([self.delegate respondsToSelector:@selector(uploadStartWithUploadModel:)]) {
            [self.delegate uploadStartWithUploadModel:uploadModel];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(uploadProgressWithUploadModel:)]) {
            [self.delegate uploadProgressWithUploadModel:uploadModel];
        }
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error{
    NSLog(@"thread : %@, 下载完成 --- %s", [NSThread currentThread], __func__);
    NSString *fileName = [self fetchFileNameWithUrl:task.currentRequest.URL.absoluteString];
    if ([MHUtil stringIsEmpty:fileName]) {
        return;
    }
    MHUploadModel *uploadModel = [self fetchUploadModelWithFileName:fileName];
    if (error) {
        uploadModel.uploadStatus = MHUploadStatusUploadFail;
    } else {
        uploadModel.uploadStatus = MHUploadStatusUploadComplete;
    }
}

#pragma mark - +++++++++++++++++++++ NSURLSessionDataDelegate end ++++++++++++++++++++++++
- (NSData *)createBodyWithBoundary:(NSString *)boundary
                        parameters:(NSDictionary *)parameters
                             paths:(NSArray *)paths
                         fieldName:(NSString *)fieldName {
    NSMutableData *httpBody = [NSMutableData data];
    // 文本参数
    [parameters enumerateKeysAndObjectsUsingBlock:^(NSString *parameterKey, NSString *parameterValue, BOOL *stop) {
        [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", parameterKey] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"%@\r\n", parameterValue] dataUsingEncoding:NSUTF8StringEncoding]];
    }];
    // 本地文件的NSData
    for (NSString *path in paths) {
//        NSString *filename  = [path lastPathComponent];
        NSData   *data      = [NSData dataWithContentsOfFile:path];
        NSString *mimetype  = [self mimeTypeForPath:path];
        
        [httpBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", @"file", fieldName] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", mimetype] dataUsingEncoding:NSUTF8StringEncoding]];
        [httpBody appendData:data];
        [httpBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [httpBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    return httpBody;
}

- (NSString *)mimeTypeForPath:(NSString *)path {
    CFStringRef extension = (__bridge CFStringRef)[path pathExtension];
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, extension, NULL);
    NSString *mimetype = CFBridgingRelease(UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType));
    CFRelease(UTI);
    return mimetype;
}

- (NSString *)generateBoundaryString {
    return [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
}

- (NSString *)fetchFileNameWithUrl:(NSString *)url {
    __block NSString *fileName;
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:url];
    [components.queryItems enumerateObjectsUsingBlock:^(NSURLQueryItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.name isEqualToString:@"fileName"]) {
            fileName = obj.value;
            *stop = YES;
        }
    }];
    return fileName;
}

- (MHUploadModel *)fetchUploadModelWithFileName:(NSString *)fileName {
    @synchronized(self.uploadTasks) {
        for (MHUploadModel *model in self.uploadTasks) {
            if ([model.fileName isEqualToString:fileName]) {
                return model;
            }
        }
    }
    return nil;;
}


- (void)dealloc {
    NSLog(@"%s销毁", __func__);
}

@end
