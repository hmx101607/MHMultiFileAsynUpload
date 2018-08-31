//
//  MHUtil.m
//  OfflineBreakpointDownload
//
//  Created by mason on 2018/8/28.
//  Copyright © 2018年 mason. All rights reserved.
//

#import "MHUtil.h"

@implementation MHUtil

+ (BOOL)isFileExist:(NSString *)fileName {
    NSString*filePath =[self cacheDocumentPathWithFileName:fileName];
    BOOL fileExists=[[NSFileManager defaultManager] fileExistsAtPath:filePath];
    return fileExists;
}

+ (NSString *)cacheDocumentPathWithFileName:(NSString *)fileName {
    NSArray* paths =NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = paths.firstObject;
    fileName = [fileName stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
    NSString* filePath =[path stringByAppendingPathComponent:fileName];
    return filePath;
}

#pragma mark -
#pragma mark String
+ (BOOL)stringIsEmpty:(NSString *) aString {
    
    if ((NSNull *) aString == [NSNull null]) {
        return YES;
    }
    
    if (aString == nil) {
        return YES;
    } else if ([aString length] == 0) {
        return YES;
    } else {
        aString = [aString stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([aString length] == 0) {
            return YES;
        }
    }
    
    return NO;
}

+ (NSString *)stringWithUUID {
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    return (__bridge_transfer NSString *)string;
}

+ (NSString *)typeForImageData:(NSData *)data {

    uint8_t c;
    [data getBytes:&c length:1];
    switch (c) {
        case 0xFF:
//            return @"image/jpeg";
            return @"jpeg";
        case 0x89:
//            return @"image/png";
            return @"png";
        case 0x47:
//            return @"image/gif";
            return @"gif";
        case 0x49:
        case 0x4D:
//            return @"image/tiff";
            return @"tiff";
    }
    return nil;
    
}

@end
