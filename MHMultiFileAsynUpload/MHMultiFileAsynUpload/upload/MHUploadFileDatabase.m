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
            result = [db executeUpdate:@"CREATE TABLE IF NOT EXISTS upload_file (file_id integer PRIMARY KEY AUTOINCREMENT, file_name text NOT NULL, file_path text NOT NULL, upload_file_type integer, upload_status integer);"];
            if (result) {
                NSLog(@"创建表成功");
            }
        }];
    });
    return result;
}

@end
