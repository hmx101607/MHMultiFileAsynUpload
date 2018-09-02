//
//  MHUploadFileDatabase.m
//  MHMultiFileAsynUpload
//
//  Created by mason on 2018/8/30.
//  Copyright © 2018年 mason. All rights reserved.
//

/*
 1.选择图片开始上传后，添加到队列并同时保存到数据（等待上传状态）
 2.正在执行上传，修改数据库中上传的状态
 3.暂停上传，修改数据库状态为暂停，移除出上传队列
 4.上传失败，修改数据库状态为失败，移除出上传队列
 5.上传成功，修改数据库状态为成功，并保存放回的路径，移除出上传队列
 6.该组数据上传成功，返回上传完成
 */

#import "MHUploadFileDatabase.h"
#import <FMDB.h>
#import "MHUtil.h"
#import "MHUploadModel.h"


@interface MHUploadFileDatabase()

/** <##> */
@property (strong, nonatomic) FMDatabaseQueue *databaseQueue;

@end

@implementation MHUploadFileDatabase

+ (instancetype)shareInstance {
    static MHUploadFileDatabase *fileDatabase;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fileDatabase = [MHUploadFileDatabase new];
        NSString *sqliteName = [NSString stringWithFormat:@"%@.sqlite", NSStringFromClass([self class])];
        NSString *fileName = [MHUtil cacheDocumentPathWithFileName:sqliteName];
        NSLog(@"fileName : %@", fileName);
        fileDatabase.databaseQueue = [FMDatabaseQueue databaseQueueWithPath:fileName];
    });
    return fileDatabase;
}

/**
 只执行一次，
 */
- (BOOL)createTable {
    __block BOOL result = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[MHUploadFileDatabase shareInstance].databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
            result = [db executeUpdate:@"CREATE TABLE IF NOT EXISTS upload_file (file_id integer PRIMARY KEY AUTOINCREMENT, file_name text NOT NULL, file_url text NOT NULL, upload_file_type integer NOT NULL, upload_status integer NOT NULL, upload_request_url text, custom_parameter text, faile_retry_count integer);"];
            if (result) {
                NSLog(@"创建表成功");
            }
        }];
    });
    return result;
}

- (BOOL)insertFileWithFileName:(NSString *)fileName
              uploadRequestUrl:(NSString *)uploadRequestUrl
                uploadFileType:(MHUploadFileType)uploadFileType
                  uploadStatus:(MHUploadStatus)uploadStatus
               customPatameter:(NSDictionary *)customPatameter {
    __block BOOL result = NO;
    NSString *customPatameterJson = @"";
    if (customPatameter) {
        customPatameterJson = [MHUtil dictionaryToJson:customPatameter];
    }
    [[MHUploadFileDatabase shareInstance].databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableString *sql = [[NSMutableString alloc] init];
        [sql appendString:@"insert into upload_file (file_name, upload_request_url, upload_file_type, upload_status, faile_retry_count"];
        if (![MHUtil stringIsEmpty:customPatameterJson]) {
            [sql appendString:@", custom_parameter"];
        }
        [sql appendFormat:@") values (%@,%@,%ld,%ld, %d", fileName, uploadRequestUrl, (long)uploadFileType, uploadStatus, 0];
        if (![MHUtil stringIsEmpty:customPatameterJson]) {
            [sql appendFormat:@",%@", customPatameterJson];
        }
        [sql appendString:@");"];
        result = [db executeUpdate:sql];
    }];
    return result;
}

- (BOOL)updateUploadStatusWithFileName:(NSString *)fileName
                          uploadStatus:(MHUploadStatus )uploadStatus
                               fileUrl:(NSString *)fileUrl
                       faileRetryCount:(NSInteger)faileRetryCount{
    __block BOOL result = NO;
    [[MHUploadFileDatabase shareInstance].databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableString *sql = [[NSMutableString alloc] init];
        [sql appendFormat:@"update upload_file set upload_status = %ld, faile_retry_count = %ld;",(long)uploadStatus, faileRetryCount];
        if (![MHUtil stringIsEmpty:fileUrl]) {
            [sql appendFormat:@" file_url = %@", fileUrl];
        }
        [sql appendFormat:@" where file_name = %@;", fileName];
        result = [db executeUpdate:sql];
    }];
    return result;
}

- (NSArray *)findAllFile {
    return [self findAllFileWithUplaodStatus:MHUploadStatusUploadWait all:YES];
}

- (NSArray *)findAllFileWithUplaodStatus:(MHUploadStatus)uploadStatus {
    return [self findAllFileWithUplaodStatus:uploadStatus all:NO];
}

//all:为yes时，uploadStatus可以为任意值
- (NSArray *)findAllFileWithUplaodStatus:(MHUploadStatus)uploadStatus all:(BOOL)all{
    __block FMResultSet *results;
    __block NSMutableArray *list = [NSMutableArray array];
    [[MHUploadFileDatabase shareInstance].databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableString *sql = [[NSMutableString alloc] init];
        [sql appendString:@"select * from upload_file"];
        if (!all) {
            [sql appendFormat:@" where upload_status = %ld;", uploadStatus];
        }
        results =[db executeQuery:sql];
    }];
    while ([results  next]) {
        MHUploadModel *uploadModel = [MHUploadModel new];
        uploadModel.fileName = [results objectForColumn:@"file_name"];
        //直接根据路径查询文件是否存在：1.不存在：数据可能存在错误，将对应数据删除
        if ([MHUtil isFileExist:uploadModel.fileName]) {
            //删除该条数据
            [self deleteFileWithFileName:uploadModel.fileName];
            continue;
        }
        uploadModel.fileUrl = [results objectForColumn:@"file_url"];
        uploadModel.uploadStatus = [results intForColumn:@"download_status"];
        [list addObject:uploadModel];
    }
    return nil;
}

- (BOOL)deleteAllFile {
    return [self deleteFileWithFileName:nil];
}

- (BOOL)deleteFileWithFileName:(NSString *)fileName {
    __block BOOL result = NO;
    [[MHUploadFileDatabase shareInstance].databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableString *sql = [[NSMutableString alloc] init];
        [sql appendString:@"delete from upload_file"];
        if (![MHUtil stringIsEmpty:fileName]) {
            [sql appendFormat:@" where file_name = %@", fileName];
        }
        result = [db executeUpdate: sql];
    }];
    return YES;
}

@end


















