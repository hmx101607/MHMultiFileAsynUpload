//
//  MHUploadFileDatabase.m
//  MHMultiFileAsynUpload
//
//  Created by mason on 2018/8/30.
//  Copyright © 2018年 mason. All rights reserved.
//

#import "MHUploadFileDatabase.h"
#import <FMDB.h>
#import "MHUtil.h"

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
            result = [db executeUpdate:@"CREATE TABLE IF NOT EXISTS upload_file (file_id integer PRIMARY KEY AUTOINCREMENT, file_name text NOT NULL, file_path text NOT NULL, upload_file_type integer NOT NULL, upload_status integer NOT NULL, upload_request_url text, custom_parameter text);"];
            if (result) {
                NSLog(@"创建表成功");
            }
        }];
    });
    return result;
}

/*
 1.选择图片开始上传后，添加到队列并同时保存到数据（等待上传状态）
 2.正在执行上传，修改数据库中上传的状态
 3.暂停上传，修改数据库状态为暂停，移除出上传队列
 4.上传失败，修改数据库状态为失败，移除出上传队列
 5.上传成功，修改数据库状态为成功，并保存放回的路径，移除出上传队列
 6.该组数据上传成功，返回上传完成
 */
- (BOOL)insertFileWithFileName:(NSString *)fileName
                      filePath:(NSString *)filePath
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
        [sql appendString:@"insert into upload_file (file_name, file_path, upload_file_type, upload_status"];
        if (![MHUtil stringIsEmpty:customPatameterJson]) {
            [sql appendString:@", custom_parameter"];
        }
        [sql appendFormat:@") values (%@,%@,%ld,%ld", fileName, filePath, (long)uploadFileType, uploadStatus];
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
                      uploadRequestUrl:(NSString *)uploadRequestUrl {
    __block BOOL result = NO;
    [[MHUploadFileDatabase shareInstance].databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        NSMutableString *sql = [[NSMutableString alloc] init];
        [sql appendFormat:@"update upload_file set upload_status = %ld",(long)uploadStatus];
        if (![MHUtil stringIsEmpty:uploadRequestUrl]) {
            [sql appendFormat:@" upload_request_url = %@", uploadRequestUrl];
        }
        [sql appendFormat:@" where file_name = %@;", fileName];
        result = [db executeUpdate:sql];
    }];
    return result;
}

- (BOOL)deleteAllFile {
    __block BOOL result = NO;
    [[MHUploadFileDatabase shareInstance].databaseQueue inDatabase:^(FMDatabase * _Nonnull db) {
        result = [db executeUpdateWithFormat:@"delete from upload_file]"];
    }];
    return result;
}

@end


















