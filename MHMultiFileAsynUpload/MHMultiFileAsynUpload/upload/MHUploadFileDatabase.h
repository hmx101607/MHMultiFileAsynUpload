//
//  MHUploadFileDatabase.h
//  MHMultiFileAsynUpload
//
//  Created by mason on 2018/8/30.
//  Copyright © 2018年 mason. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MHUploadFileDatabase : NSObject

+ (instancetype)shareInstance;

- (BOOL)createTable;

@end
