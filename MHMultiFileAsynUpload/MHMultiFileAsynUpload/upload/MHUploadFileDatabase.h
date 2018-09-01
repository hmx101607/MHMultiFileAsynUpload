//
//  MHUploadFileDatabase.h
//  MHMultiFileAsynUpload
//
//  Created by mason on 2018/8/30.
//  Copyright © 2018年 mason. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MHUploadModel.h"

@interface MHUploadFileDatabase : NSObject

+ (instancetype)shareInstance;


/**
 创建表格

 @return 是否创建成功
 */
- (BOOL)createTable;

/**
 插入基本数据

 @param fileName 文件名称
 @param filePath 沙盒路径
 @param uploadFileType 上传文件类型：图片，视频，文件
 @param uploadStatus 上传状态
 @param customPatameter 自定义的上传参数
 @return 操作结果
 */
- (BOOL)insertFileWithFileName:(NSString *)fileName
                      filePath:(NSString *)filePath
                uploadFileType:(MHUploadFileType)uploadFileType
                  uploadStatus:(MHUploadStatus)uploadStatus
               customPatameter:(NSDictionary *)customPatameter;

/**
 更新上传状态及上传成功获取到的路径

 @param fileName 文件名称
 @param uploadStatus 上传状态
 @param uploadRequestUrl 文件路径
 @return 操作结果
 */
- (BOOL)updateUploadStatusWithFileName:(NSString *)fileName
                          uploadStatus:(MHUploadStatus )uploadStatus
                      uploadRequestUrl:(NSString *)uploadRequestUrl;

/**
 删除所有文件

 @return 操作结果
 */
- (BOOL)deleteAllFile;

@end
