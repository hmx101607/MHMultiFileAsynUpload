//
//  MHUploadModel.m
//  MHMultiFileAsynUpload
//
//  Created by mason on 2018/8/29.
//  Copyright © 2018年 mason. All rights reserved.
//

#import "MHUploadModel.h"
#import "MHUtil.h"

@implementation MHUploadModel


+ (MHUploadModel *)assetConvertUploadModel:(PHAsset *)asset {
    __block MHUploadModel *uploadModel = [MHUploadModel new];
    if (asset.mediaType == PHAssetMediaTypeImage) {
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.version = PHImageRequestOptionsVersionCurrent;
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        options.synchronous = YES;
        uploadModel.uploadFileType = MHUploadFileTypeImage;
        [[PHImageManager defaultManager] requestImageDataForAsset:asset options:options resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            uploadModel.fileData = imageData;
            uploadModel.fileName = [NSString stringWithFormat:@"%@.%@", [MHUtil stringWithUUID], [MHUtil typeForImageData:imageData]];
        }];
    } else if (asset.mediaType == PHAssetMediaTypeVideo) {
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.version = PHImageRequestOptionsVersionCurrent;
        options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        uploadModel.uploadFileType = MHUploadFileTypeVideo;
        [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
            AVURLAsset *urlAsset = (AVURLAsset *)asset;
            NSData *data = [NSData dataWithContentsOfURL:urlAsset.URL];
            uploadModel.fileData = data;
            uploadModel.fileName = [NSString stringWithFormat:@"%@.mov", [MHUtil stringWithUUID]];
        }];
    }
    return uploadModel;
}

@end
