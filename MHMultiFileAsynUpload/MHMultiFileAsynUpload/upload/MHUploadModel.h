//
//  MHUploadModel.h
//  MHMultiFileAsynUpload
//
//  Created by mason on 2018/8/29.
//  Copyright © 2018年 mason. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

typedef NS_ENUM(NSInteger, MHUploadFileType) {
    /** 图片 */
    MHUploadFileTypeImage,
    /** 视频 */
    MHUploadFileTypeVideo,
    /** 音频 */
    MHUploadFileTypeAudio,
    /** 其他 */
    MHUploadFileTypeOther
};

typedef NS_ENUM(NSInteger, MHUploadStatus) {
    /** 等待上传 */
   MHUploadStatusUploadWait,
    /** 暂停上传 */
    MHUploadStatusUploadSuspend,
    /** 正在上传 */
    MHUploadStatusUploading,
    /** 上传完成 */
    MHUploadStatusUploadComplete,
    /** 上传失败 */
    MHUploadStatusUploadFail,
    /** 取消上传 */
    MHUploadStatusUploadCancel
};

@interface MHUploadModel : NSObject

/** 文件id（可不用） */
@property (strong, nonatomic) NSString *fileId;
/** 文件名称：自定义<##> */
@property (strong, nonatomic) NSString *fileName;
/** 本地沙盒路径 */
@property (strong, nonatomic) NSString *filePath;
/** NSData */
@property (strong, nonatomic) NSData * fileData;
/** 总大小 : KB */
@property (assign, nonatomic) NSInteger totalSize;
/** 当前下载大小 : KB */
@property (assign, nonatomic) NSInteger currentSize;
/** 文件类型 */
@property (assign, nonatomic) MHUploadFileType uploadFileType;
/** 上传状态 */
@property (assign, nonatomic) MHUploadStatus uploadStatus;
/** <##> */
@property (strong, nonatomic) NSURLSessionDataTask *task;
/** 服务器地址 */
@property (strong, nonatomic) NSString *uploadRequestUrl;
/** 自定义参数 */
@property (strong, nonatomic) NSDictionary *customParameter;


+ (MHUploadModel *)assetConvertUploadModel:(PHAsset *)asset
                          uploadRequestUrl:(NSString *)uploadRequestUrl
                           customParameter:(NSDictionary *)customParameter;
@end










