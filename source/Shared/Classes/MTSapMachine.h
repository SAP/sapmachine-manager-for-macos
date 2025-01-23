/*
     MTSapMachine.h
     Copyright 2023-2025 SAP SE
     
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
#import "Constants.h"

/*!
 @protocol      MTSapMachineAssetUpdateDelegate
 @abstract      Defines an interface for delegates of MTSapMachine to be notified about an asset's update progress.
*/
@protocol MTSapMachineAssetUpdateDelegate <NSObject>

/*!
 @method        updateStartedForAsset:
 @abstract      Called if the update of a MTSapMachineAsset has been started.
 @param         asset A reference to the MTSapMachineAsset instance that has changed.
 @discussion    Delegates receive this message before the download of a MTSapMachineAsset
                will start.
*/
- (void)updateStartedForAsset:(MTSapMachineAsset*)asset;

/*!
 @method        updateFinishedForAsset:
 @abstract      Called if the update of a MTSapMachineAsset has been successfully finished.
 @param         asset A reference to the MTSapMachineAsset instance that has changed.
 @discussion    Delegates receive this message after the download of a MTSapMachineAsset
                has been finished, the checksum has been successfully verified and the
                downloaded archive has been successfully unpacked.
*/
- (void)updateFinishedForAsset:(MTSapMachineAsset*)asset;

/*!
 @method        updateFailedForAsset:
 @abstract      Called if the update of a MTSapMachineAsset failed.
 @param         asset A reference to the MTSapMachineAsset instance that has changed.
 @param         error The error that caused the update to fail.
 @discussion    Delegates receive this message if the download of a MTSapMachineAsset
                failed, if the checksum of the downloaded file could not be verified or if
                the downloaded archive could not be unpacked.
*/
- (void)updateFailedForAsset:(MTSapMachineAsset*)asset withError:(NSError*)error;

/*!
 @method        downloadProgressUpdatedForAsset:
 @abstract      Called if the update progress of a MTSapMachineAsset changed.
 @param         asset A reference to the MTSapMachineAsset instance that has changed.
 @discussion    Periodically informs the delegate about the update progress. The update
                progress is provided in the asset's @c updateProgress property.
*/
- (void)downloadProgressUpdatedForAsset:(MTSapMachineAsset*)asset;

@end

/*!
 @class         MTSapMachine
 @abstract      This class provides methods to get SapMachine release infromation and download,
                verfiy and install SapMachine releases.
*/

@interface MTSapMachine : NSObject <NSURLSessionDownloadDelegate>

/*!
 @property      updateDelegate
 @abstract      The receiver's update delegate.
 @discussion    The value of this property is an object conforming to the MTSapMachineAssetUpdateDelegate protocol.
*/
@property (weak) id <MTSapMachineAssetUpdateDelegate> updateDelegate;


@property (nonatomic, strong, readwrite) NSString *effectiveUserName;

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithURL: instead.
*/
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithURL:
 @abstract      Initialize a MTSapMachine object with a given url.
 @param         url The url of the json file containing SapMachine release information.
*/
- (instancetype)initWithURL:(NSURL*)url NS_DESIGNATED_INITIALIZER;

/*!
 @method        requestReleaseDataWithCompletionHandler:
 @abstract      Returns the SapMachine release data.
 @param         completionHandler The completion handler to call when the request is complete.
 @discussion    Returns a NSDictionary representation of the json release data. The dictionary may
                be nil if an error occurred. Then the NSError object might provide information about
                the error that caused the operation to fail.
*/
- (void)requestReleaseDataWithCompletionHandler:(void (^) (NSDictionary *releaseData, NSError *error))completionHandler;

/*!
 @method        assetCatalogWithCompletionHandler:
 @abstract      Returns the asset catalog.
 @param         completionHandler The completion handler to call when the request is complete.
 @discussion    Returns a NSArray of MTSapMachine objects. Each element of the array represents
                a SapMachine release from the SapMachine release data. An empty array is returned
                if there are no release data available and no SapMachine assets are installed. The array
                may be nil if an error occurred. Then the NSError object might provide information about
                the error that caused the operation to fail.
*/
- (void)assetCatalogWithCompletionHandler:(void (^) (NSArray<MTSapMachineAsset*> *assetCatalog, NSError *error))completionHandler;

/*!
 @method        downloadAssets:install:completionHandler:
 @abstract      Downloads and optionally installs the given assets.
 @param         assets An array of MTSapMachine objects.
 @param         completionHandler The completion handler to call when the request is complete.
 @discussion    Returns YES, if the operation was successful, otherwise returns NO.
*/
- (void)downloadAssets:(NSArray<MTSapMachineAsset*>*)assets install:(BOOL)install completionHandler:(void (^) (BOOL success))completionHandler;

@end
