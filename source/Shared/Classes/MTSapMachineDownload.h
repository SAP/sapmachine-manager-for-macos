/*
     MTSapMachineDownload.h
     Copyright 2023-2024 SAP SE
     
     Licensed under the Apache License, Version 2.0 (the "License");
     you may not use this file except in compliance with the License.
     You may obtain a copy of the License at
     
     http://www.apache.org/licenses/LICENSE-2.0
     
     Unless required by applicable law or agreed to in writing, software
     distributed under the License is distributed on an "AS IS" BASIS,
     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
     See the License for the specific language governing permissions and
     limitations under the License.
*/

#import <Foundation/Foundation.h>
#import "MTSapMachineAsset.h"

/*!
 @class         MTSapMachineDownload
 @abstract      This class provides properties to associate a NSURLSessionDownloadTask
                object with a MTSapMachineAsset object. This makes it easy to access
                the corresponding MTSapMachineAsset object in the delegate methods of
                NSURLSessionDownloadTask.
*/

@interface MTSapMachineDownload : NSObject

/*!
 @property      asset
 @abstract      A property to store the asset that should be downloaded.
 @discussion    The value of this property is MTSapMachineAsset.
*/
@property (nonatomic, strong, readwrite) MTSapMachineAsset *asset;

/*!
 @property      task
 @abstract      A property to store the download task that belongs to the asset.
 @discussion    The value of this property is NSURLSessionDownloadTask.
*/
@property (nonatomic, strong, readwrite) NSURLSessionDownloadTask *task;

/*!
 @property      semaphore
 @abstract      A property to store  a semaphore for the download task.
 @discussion    The value of this property is dispatch_semaphore_t. This property
                is used to keep the download task in our operations queue until
                the download task has been finished.
*/
@property (nonatomic, strong, readwrite) dispatch_semaphore_t semaphore;

@end
