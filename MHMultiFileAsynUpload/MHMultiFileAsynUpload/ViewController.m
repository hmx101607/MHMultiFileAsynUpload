//
//  ViewController.m
//  MHMultiFileAsynUpload
//
//  Created by mason on 2018/8/29.
//  Copyright © 2018年 mason. All rights reserved.
//

#import "ViewController.h"
#import <Photos/Photos.h>
#import "MHImageItemCollectionViewCell.h"
#import "MHUploadModel.h"
#import "MHUploadManager.h"

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

@interface ViewController ()
<
UINavigationControllerDelegate,
UIImagePickerControllerDelegate,
UICollectionViewDelegate,
UICollectionViewDataSource,
UICollectionViewDelegateFlowLayout,
MHUploadManagerDelegate
>

/** <##> */
@property (strong, nonatomic) NSMutableArray *fileArray;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UILabel *tipLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.collectionView registerNib:[UINib nibWithNibName:NSStringFromClass([MHImageItemCollectionViewCell class]) bundle:nil] forCellWithReuseIdentifier:NSStringFromClass([MHImageItemCollectionViewCell class])];
    self.collectionView.delegate = self;
    self.collectionView.dataSource = self;
    
    [MHUploadManager shareManager].delegate = self;
}

- (IBAction)choosePictureAction:(id)sender {
    UIImagePickerController *pickerVC = [[UIImagePickerController alloc] init];
    pickerVC.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    pickerVC.delegate = self;
    [self presentViewController:pickerVC animated:YES completion:nil];
}

- (IBAction)chooseVideoAction:(id)sender {
    UIImagePickerController *pickerVC = [[UIImagePickerController alloc] init];
    pickerVC.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    pickerVC.delegate = self;
    pickerVC.mediaTypes = [NSArray arrayWithObjects:@"public.movie", nil];
    [self presentViewController:pickerVC animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    NSURL *url = [info objectForKey:@"UIImagePickerControllerReferenceURL"];
    PHFetchResult *fetchResult = [PHAsset fetchAssetsWithALAssetURLs:@[url] options:nil];
    PHAsset *asset = fetchResult.firstObject;
    if (!asset) {
        return;
    }
    NSString * uploadRequestUrl = @"xyrcf/api/v1/FileRest/upload/?access_token=c8dd4d40-fbc8-408f-b332-b7c57bec0b64";
    NSDictionary * customParameter = nil;
    if (asset.mediaType == PHAssetMediaTypeImage) {
        customParameter = @{@"pathType" : @"1",
                            @"imgType" : @"6"
                            };
    } else if (asset.mediaType == PHAssetMediaTypeVideo) {
        customParameter = @{@"pathType" : @"2",
                            @"imgType" : @"6"
                            };
    }
    MHUploadModel *uploadModel = [MHUploadModel assetConvertUploadModel:asset uploadRequestUrl:(NSString *)uploadRequestUrl customParameter:customParameter];
    [self.fileArray addObject:uploadModel];
    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.collectionView reloadData];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}


- (IBAction)uploadFileAction:(id)sender {
    for (NSInteger i = 0; i < self.fileArray.count; i++) {
        MHUploadModel *uploadModel = self.fileArray[i];
        [[MHUploadManager shareManager] addDownloadQueue:uploadModel];
    }
}

- (IBAction)suspendFileAction:(id)sender {
    
}

- (IBAction)cancelFileAction:(id)sender {
    
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.fileArray.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MHImageItemCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:NSStringFromClass([MHImageItemCollectionViewCell class]) forIndexPath:indexPath];
    MHUploadModel *uploadModel = self.fileArray[indexPath.row];
    [cell.imageView setImage:[UIImage imageWithData:uploadModel.fileData]];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat widht = (SCREEN_WIDTH - 5) / 4;
    return CGSizeMake(widht, widht);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 1;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 1;
}

- (void)uploadStartWithUploadModel:(MHUploadModel *)uploadModel {
    NSLog(@"%s : 开始下载", __func__);
}

- (void)uploadProgressWithUploadModel:(MHUploadModel *)uploadModel {
    self.tipLabel.text = [NSString stringWithFormat:@"%.0f%%-%@", uploadModel.currentSize * 1.0 / uploadModel.totalSize * 1.0 * 100, uploadModel.fileName];
}

- (void)uploadCompletionWithUploadModel:(MHUploadModel *)uploadModel error:(NSError *)error {
    NSLog(@"%s : 完成下载", __func__);
}

- (void)uploadAllTaskCompletionWithUploadModel:(NSArray<MHUploadModel *> *)uploadModels error:(NSError *)error {
    NSLog(@"%s : 所有任务完成下载， error ： %@", __func__, error);
}

- (NSString *)fetchUrlWithResponse:(NSDictionary *)response {
    if ([[response objectForKey:@"status"] integerValue] == 1000) {
        return [response objectForKey:@"url"];
    }
    return nil;
}

- (NSMutableArray *)fileArray {
    if (!_fileArray) {
        _fileArray = [NSMutableArray array];
    }
    return _fileArray;
}


@end
















