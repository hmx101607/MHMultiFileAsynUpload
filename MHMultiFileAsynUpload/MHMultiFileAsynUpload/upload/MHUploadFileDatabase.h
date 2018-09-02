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
 @param uploadRequestUrl 存放在服务器的文件地址
 @param uploadFileType 上传文件类型：图片，视频，文件
 @param uploadStatus 上传状态
 @param customPatameter 自定义的上传参数
 @return 操作结果
 */
- (BOOL)insertFileWithFileName:(NSString *)fileName
              uploadRequestUrl:(NSString *)uploadRequestUrl
                uploadFileType:(MHUploadFileType)uploadFileType
                  uploadStatus:(MHUploadStatus)uploadStatus
               customPatameter:(NSDictionary *)customPatameter;

/**
 更新上传状态及上传成功获取到的路径

 @param fileName 文件名称
 @param uploadStatus 上传状态
 @param fileUrl 文件路径
 @param faileRetryCount 失败次数
 @return 操作结果
 */
- (BOOL)updateUploadStatusWithFileName:(NSString *)fileName
                          uploadStatus:(MHUploadStatus )uploadStatus
                               fileUrl:(NSString *)fileUrl
                       faileRetryCount:(NSInteger)faileRetryCount;

/**
 获取所有文件

 @return 操作结果
 */
- (NSArray *)findAllFile;

/**
 根据状态，获取相应的所有结果

 @param uploadStatus 状态值
 @return 操作结果
 */
- (NSArray *)findAllFileWithUplaodStatus:(MHUploadStatus)uploadStatus;

/**
 删除所有文件

 @return 操作结果
 */
- (BOOL)deleteAllFile;

/**
 根据文件名称删除相应的文件

 @param fileName 文件名
 @return 操作结果
 */
- (BOOL)deleteFileWithFileName:(NSString *)fileName;

@end
