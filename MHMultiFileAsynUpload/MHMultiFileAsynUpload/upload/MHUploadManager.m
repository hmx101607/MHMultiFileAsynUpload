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
#import "MHUploadFileDatabase.h"

/*
 1.选择图片开始上传后，添加到队列并同时保存到数据（等待上传状态）
 2.正在执行上传，修改数据库中上传的状态
 3.暂停上传，修改数据库状态为暂停，移除出上传队列
 4.上传失败，修改数据库状态为失败，移除出上传队列
 5.上传成功，修改数据库状态为成功，并保存放回的路径，移除出上传队列
 6.该组数据上传成功，返回上传完成
 */

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
/** 失败重试次数<##> */
@property (assign, nonatomic) NSInteger faileRetryCount;
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
        uploadManager.faileRetryCount = 3;
        
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
    uploadModel.uploadStatus = MHUploadStatusUploadWait;
    BOOL success = [[NSFileManager defaultManager] createFileAtPath:path contents:uploadModel.fileData attributes:nil];
    if (success) {
        //将基础数据插入数据库
        [[MHUploadFileDatabase shareInstance] insertFileWithFileName:uploadModel.fileName uploadRequestUrl:uploadModel.uploadRequestUrl uploadFileType:uploadModel.uploadFileType uploadStatus:MHUploadStatusUploadWait customPatameter:uploadModel.customParameter];
        
        //加入上传队列
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
    NSString *path = [MHUtil cacheDocumentPathWithFileName:uploadModel.fileName];
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
        //更新下载状态
        [[MHUploadFileDatabase shareInstance] updateUploadStatusWithFileName:uploadModel.fileName uploadStatus:uploadModel.uploadStatus fileUrl:nil faileRetryCount:1];
        //回调
        if ([self.delegate respondsToSelector:@selector(uploadStartWithUploadModel:)]) {
            [self.delegate uploadStartWithUploadModel:uploadModel];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(uploadProgressWithUploadModel:)]) {
            [self.delegate uploadProgressWithUploadModel:uploadModel];
        }
    }
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    NSLog(@"didReceiveData--%@",[NSThread currentThread]);
    NSString *fileName = [self fetchFileNameWithUrl:dataTask.currentRequest.URL.absoluteString];
    if ([MHUtil stringIsEmpty:fileName]) {
        return;
    }
    MHUploadModel *uploadModel = [self fetchUploadModelWithFileName:fileName];
    NSMutableData *responData = [[NSMutableData alloc] init];
    [responData appendData:uploadModel.responseData];
    [responData appendData:data];
    uploadModel.responseData = responData;
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
        //失败自动重传三次
        if (uploadModel.faileRetryCount < [MHUploadManager shareManager].faileRetryCount) {
            MHUploadModel *model = uploadModel;
            [self removeUploadModelWithFileName:uploadModel.fileName];
            model.uploadStatus = MHUploadStatusUploadWait;
            model.faileRetryCount++;
            //更新下载状态
            [[MHUploadFileDatabase shareInstance] updateUploadStatusWithFileName:model.fileName uploadStatus:model.uploadStatus fileUrl:nil faileRetryCount:model.faileRetryCount];
            //加入上传队列
            [self.uploadTasks addObject:uploadModel];
            [self startUploadWithModel:uploadModel];
        } else {
            //终止所有请求，并清除数据
            [[MHUploadManager shareManager].operationQueue cancelAllOperations];
            NSError *error = [NSError errorWithDomain:@"上传失败" code:1001 userInfo:nil];
            [self completeUploadTaskError:error];
        }
    } else {
        uploadModel.uploadStatus = MHUploadStatusUploadComplete;
        //拼接服务器返回的数据
        NSError *error;
        NSDictionary *jsonDic = [NSJSONSerialization JSONObjectWithData:uploadModel.responseData options:NSJSONReadingMutableContainers error:&error];
        if (!error) {
            if ([self.delegate respondsToSelector:@selector(fetchUrlWithResponse:)]) {
                NSString *fileUrl = [self.delegate fetchUrlWithResponse:jsonDic];
                uploadModel.fileUrl = fileUrl;
                //更新下载状态
                [[MHUploadFileDatabase shareInstance] updateUploadStatusWithFileName:uploadModel.fileName uploadStatus:uploadModel.uploadStatus fileUrl:fileUrl faileRetryCount:uploadModel.faileRetryCount];
            }
        }
        if ([MHUploadManager shareManager].operationQueue.operationCount == 0) {
            [self completeUploadTaskError:nil];
        }
    }
}

- (void) completeUploadTaskError:(NSError *)error {
    
    //删除沙盒中的文件数据
    NSArray *uploadFiles = [[MHUploadFileDatabase shareInstance] findAllFile];
    [uploadFiles enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        MHUploadModel *model = obj;
        [[NSFileManager defaultManager] removeItemAtPath:[MHUtil cacheDocumentPathWithFileName:model.fileName] error:nil];
    }];
    //上传完成，删除所有数据
    [[MHUploadFileDatabase shareInstance] deleteAllFile];
    //队列中的任务全部结束
    if ([self.delegate respondsToSelector:@selector(uploadAllTaskCompletionWithUploadModel:error:)]) {
        [self.delegate uploadAllTaskCompletionWithUploadModel:self.uploadTasks error:error];
    }
    [self.uploadTasks removeAllObjects];
}

#pragma mark - 根据filePath移除下载任务
- (void)removeUploadModelWithFileName:(NSString *)fileName {
    @synchronized(self.uploadTasks) {
        for (MHUploadModel *model in self.uploadTasks) {
            if ([model.fileName isEqualToString:fileName]) {
                [self.uploadTasks removeObject:model];
                break;
            }
        }
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
