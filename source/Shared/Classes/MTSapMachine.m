/*
     MTSapMachine.m
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

#import "MTSapMachine.h"
#import "MTJavaHome.h"
#import "MTChecksum.h"
#import "Constants.h"
#import "MTSapMachineDownload.h"
#import "MTOperationQueue.h"
#import "MTSystemInfo.h"

@interface MTSapMachine ()
@property (nonatomic, strong, readwrite) NSURL *url;
@property (nonatomic, strong, readwrite) NSMutableDictionary *activeDownloads;
@property (nonatomic, strong, readwrite) MTOperationQueue *sessionQueue;
@property (assign) BOOL downloadSuccess;
@end

@implementation MTSapMachine

- (instancetype)initWithURL:(NSURL*)url
{
    self = [super init];
    
    if (url) {
        _url = url;
        _activeDownloads = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (void)requestReleaseDataWithCompletionHandler:(void (^) (NSDictionary *releaseData, NSError *error))completionHandler
{
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:_url];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                          delegate:nil
                                                     delegateQueue:nil
    ];
    
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {

        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;

        if ([httpResponse statusCode] == 200 && data) {

            NSError *error = nil;
            NSDictionary *releaseData = [NSJSONSerialization JSONObjectWithData:data
                                                                        options:kNilOptions
                                                                          error:&error
            ];
            
            if (completionHandler) { completionHandler(releaseData, error); }

        } else {
            
            if (completionHandler) { completionHandler(nil,error); }
        }
        
        [session invalidateAndCancel];
    }];
    
    [dataTask resume];
}

- (void)assetCatalogWithCompletionHandler:(void (^) (NSArray<MTSapMachineAsset*> *assetCatalog, NSError *error))completionHandler
{
    NSMutableArray *allAssetArray = [[NSMutableArray alloc] init];
    NSString *currentArchitecture = ([[MTSystemInfo hardwareArchitecture] isEqualToString:@"x86_64"]) ? kMTSapMachineArchIntel : kMTSapMachineArchApple;
    
    // get the data of the available releases
    [self requestReleaseDataWithCompletionHandler:^(NSDictionary *releaseData, NSError *error) {
        
        // get data about the installed releases. this allows us to set
        // the asset's "installURL" property and also allows us to add
        // installed assets not contained in the release data.
        [self installedAssetsWithCompletionHandler:^(NSArray<MTSapMachineAsset *> *installedAssets) {

            NSMutableArray *installedAssetsMutable = [[NSMutableArray alloc] init];
            if ([installedAssets count] > 0) { [installedAssetsMutable addObjectsFromArray:installedAssets]; }
            
            // create MTSapMachineAsset objects from the release data returned.
            for (NSString *releaseVersion in [releaseData allKeys]) {
                
                // get all data of the particular release
                NSDictionary *assetDict = [releaseData objectForKey:releaseVersion];
                
                // get basic asset information
                NSString *assetName = [assetDict valueForKey:@"label"];
                BOOL isEA = [[assetDict valueForKey:@"ea"] boolValue];
                BOOL isLTS = [[assetDict valueForKey:@"lts"] boolValue];
                    
                // release dict contains dictionaries for each jvm type
                for (NSString *typeString in [NSArray arrayWithObjects:kMTJVMTypeJRE, kMTJVMTypeJDK, nil]) {
                    
                    NSMutableDictionary *downloadDict = [[NSMutableDictionary alloc] init];
                    
                    NSString *currentVersionString = @"";
                    MTSapMachineJVMType type = ([typeString isEqualToString:kMTJVMTypeJRE]) ? MTSapMachineJVMTypeJRE : MTSapMachineJVMTypeJDK;
                    
                    // process the "releases" array
                    for (NSDictionary *releaseDict in [assetDict objectForKey:@"releases"]) {
                        
                        for (NSString *arch in [NSArray arrayWithObjects:kMTSapMachineArchApple, kMTSapMachineArchIntel, nil]) {
                                                        
                            NSString *downloadURLString = [releaseDict valueForKeyPath:[NSString stringWithFormat:@"%@.%@.url", typeString, arch]];
                            NSString *downloadChecksumString = [releaseDict valueForKeyPath:[NSString stringWithFormat:@"%@.%@.checksum", typeString, arch]];
                            
                            if (downloadURLString && downloadChecksumString) {
                                
                                // we set the current version for the current architecture
                                if ([arch isEqualToString:currentArchitecture]) { currentVersionString = [releaseDict valueForKey:@"tag"]; }

                                NSRange range = [downloadChecksumString rangeOfString:@" "];
                                if (range.location != NSNotFound) { downloadChecksumString = [downloadChecksumString substringFromIndex:range.location + 1]; }
                                
                                NSDictionary *downloadArchDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                  [NSURL URLWithString:downloadURLString], @"url",
                                                                  downloadChecksumString, @"checksum",
                                                                  nil];
                                
                                [downloadDict setValue:downloadArchDict forKey:arch];
                            }
                        }
                    }
                        
                    if ([[downloadDict allKeys] count] > 0) {
                        
                        // create the MTSapMachineAsset object
                        MTSapMachineAsset *asset = [[MTSapMachineAsset alloc] initWithType:type];
                        
                        MTSapMachineVersion *currentVersion = [[MTSapMachineVersion alloc] initWithVersionString:currentVersionString];
                        [asset setCurrentVersion:currentVersion];
                        
                        [asset setName:assetName];
                        [asset setEA:isEA];
                        [asset setLTS:isLTS];
                        [asset setDownloadURLs:downloadDict];
                        [asset setIsVerified:YES];
                        
                        // now let's check if the version is installed and add
                        // the corresponding information to the asset object. to
                        // identify a release we use the major version, the jvm
                        // type and the "isEA" property
                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"installedVersion.majorVersion == %ld AND isEA == %@ AND jvmType == %ld",
                                                  [[asset currentVersion] majorVersion],
                                                  [NSNumber numberWithBool:[asset isEA]],
                                                  [asset jvmType]
                        ];
                        NSArray *filteredArray = [installedAssetsMutable filteredArrayUsingPredicate:predicate];
                        
                        if ([filteredArray count] > 0) {
                            
                            MTSapMachineAsset *installedAsset = [filteredArray firstObject];
                            [asset setInstallURL:[installedAsset installURL]];
                            [asset setInstalledVersion:[installedAsset installedVersion]];
                            [asset setJavaHomeURL:[installedAsset javaHomeURL]];
                            [asset setJavaHomeConfigFilePaths:[installedAsset javaHomeConfigFilePaths]];
                            
                            [installedAssetsMutable removeObjectsInArray:filteredArray];
                        }
                        
                        [allAssetArray addObject:asset];
                    }
                }
            }
                                    
            // if there are still installed assets left which did not
            // match any asset in our release data (e.g. older and
            // unsupported releases), we add them as well.
            if ([installedAssetsMutable count] > 0) {
                [allAssetArray addObjectsFromArray:installedAssetsMutable];
            }
            
            // sort the asset array
            NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"displayName"
                                                                                              ascending:YES
                                                                                               selector:@selector(localizedStandardCompare:)
                                                                ]
            ];
            NSArray *sortedAssets = [allAssetArray sortedArrayUsingDescriptors:sortDescriptors];

            if (completionHandler) { completionHandler(sortedAssets, nil); }
        }];
    }];
}

- (void)installedAssetsWithCompletionHandler:(void (^) (NSArray<MTSapMachineAsset*>* installedAssets))completionHandler
{
    if (completionHandler) {
        
        [MTJavaHome installedJVMsFilteredByBundleID:[NSArray arrayWithObjects:kMTSapMachineJDKIdentifier, kMTSapMachineJREIdentifier, nil]
                                  completionHandler:^(NSArray *installedJVMs) {
            
            NSMutableArray *allAssetArray = [[NSMutableArray alloc] init];
            
            // get a list of configuration files for our supported shells
            NSString *userName = ([self->_effectiveUserName length] > 0) ? self->_effectiveUserName : NSUserName();
            NSDictionary *javaHomeConfigFiles = [MTJavaHome configFilesWithUserName:userName userOnly:NO recommendedOnly:NO];

            // create MTSapMachineAsset objects from the data returned
            for (NSDictionary *jvmDict in installedJVMs) {
                                
                // type
                NSString *jvmBundleID = [jvmDict objectForKey:@"JVMBundleID"];
                MTSapMachineJVMType type = -1;
                
                if ([jvmBundleID rangeOfString:kMTJVMTypeJRE].location != NSNotFound) {
                    type = MTSapMachineJVMTypeJRE;
                } else if ([jvmBundleID rangeOfString:kMTJVMTypeJDK].location != NSNotFound) {
                    type = MTSapMachineJVMTypeJDK;
                }
                
                // if we don't got a jvm type, we ignore the asset
                if (type >= 0) {
                    
                    MTSapMachineAsset *asset = [[MTSapMachineAsset alloc] initWithType:type];
                    
                    // local url
                    NSString *jvmHomePath = [jvmDict objectForKey:@"JVMHomePath"];
                    
                    if (jvmHomePath) {
                        
                        NSURL *fileURL = [NSURL fileURLWithPath:jvmHomePath];
                        [asset setJavaHomeURL:fileURL];
                        
                        NSString *jvmPath = jvmHomePath;
                        NSRange range = [jvmHomePath rangeOfString:@"/Contents"];
                        if (range.location != NSNotFound) { jvmPath = [jvmHomePath substringToIndex:range.location]; }
                        
                        fileURL = [NSURL fileURLWithPath:jvmPath];
                        [asset setInstallURL:fileURL];
                    }
                    
                    // get jvm name, ea and build
                    if ([asset installURL]) {
                        
                        // name
                        NSString *jvmName = [jvmDict objectForKey:@"JVMName"];
                        [asset setName:[[jvmName componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@".-"]] firstObject]];
                        
                        // early access (beta version)
                        NSDictionary *infoDictionary = [NSDictionary dictionaryWithContentsOfURL:[[asset installURL] URLByAppendingPathComponent:@"/Contents/Info.plist"]];
                        NSString *jvmVersionString = [infoDictionary objectForKey:@"CFBundleGetInfoString"];
                        [asset setEA:([jvmVersionString rangeOfString:@"-ea"].location != NSNotFound) ? YES : NO];
                        
                        // installed version
                        MTSapMachineVersion *installedVersion = [[MTSapMachineVersion alloc] initWithVersionString:jvmVersionString];
                        [asset setInstalledVersion:installedVersion];
                        [asset setCurrentVersion:installedVersion];

                        // is this asset set as JAVA_HOME for one of the supported shells?
                        NSMutableDictionary *allUsedConfigFiles = [[NSMutableDictionary alloc] init];
                        
                        for (NSString *key in [javaHomeConfigFiles allKeys]) {
                
                            NSMutableArray *configFilesUsed = [[NSMutableArray alloc] init];
                            
                            for (NSString *configFilePath in [javaHomeConfigFiles valueForKey:key]) {
                                
                                NSString *javaHomePath = [MTJavaHome environmentVariableAtPath:configFilePath];
                                
                                if (javaHomePath && [javaHomePath hasPrefix:[[asset javaHomeURL] path]]) {
                                    [configFilesUsed addObject:configFilePath];
                                }
                            }
                            
                            if ([configFilesUsed count] > 0) {
                                [allUsedConfigFiles setValue:configFilesUsed forKey:key];
                            }
                        }

                        [asset setJavaHomeConfigFilePaths:allUsedConfigFiles];

                        [allAssetArray addObject:asset];
                    }
                    
                }
            }
            
            completionHandler(allAssetArray);
        }];
    }
}

- (void)downloadAssets:(NSArray<MTSapMachineAsset*>*)assets install:(BOOL)install completionHandler:(void (^) (BOOL success))completionHandler
{
    _downloadSuccess = YES;
    
    if (_sessionQueue == nil) {
        _sessionQueue = [[MTOperationQueue alloc] init];
        [_sessionQueue setMaxConcurrentOperationCount:kMTMaxConcurrentOperations];
    }
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                          delegate:self
                                                     delegateQueue:nil
    ];
    
    for (MTSapMachineAsset *asset in assets) {

        if (!install || ([asset downloadURLForCurrentArchitecture] && [[asset currentVersion] compare:[asset installedVersion]] == NSOrderedDescending)) {
                
            [asset setIsUpdating:install];
            [asset setUpdateProgress:0];
            
            if (_updateDelegate && [_updateDelegate respondsToSelector:@selector(updateStartedForAsset:)]) {
                [_updateDelegate updateStartedForAsset:asset];
            }
            
            [_sessionQueue addOperationWithBlock:^{
                
                MTSapMachineDownload *assetDownload = [[MTSapMachineDownload alloc] init];
                [assetDownload setAsset:asset];
                
                NSURL *url = nil;
            
                // if the asset should be installed, we download the appropriate asset
                // for the current architecture. Otherwise we download just the first
                // asset contained in downloadURLs. To download the same asset for
                // multiple architectures, please pass a separate asset containing
                // just the url for the corresponding platform to this method.
                if (install) {
                    
                    url = [asset downloadURLForCurrentArchitecture];
                    
                } else {
                    
                    NSString *key = [[[asset downloadURLs] allKeys] firstObject];
                    url = [[asset downloadURLs] valueForKeyPath:[key stringByAppendingString:@".url"]];
                }
                
                if (url) {
                    
                    NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:url];
                    [assetDownload setTask:downloadTask];
                    
                    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
                    [assetDownload setSemaphore:semaphore];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self->_activeDownloads setObject:assetDownload
                                                   forKey:[NSNumber numberWithInteger:[downloadTask taskIdentifier]]];
                    });
                    
                    [[assetDownload task] resume];
                    
                    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                }
            }];
        }
    }
    
    // call the completion handler if all downloads have been finished
    __weak typeof(self) weakSelf = self;
    [_sessionQueue addNotificationBlock:^{
            
        [session invalidateAndCancel];
        if (completionHandler) { completionHandler(weakSelf.downloadSuccess); }
    }];
}

#pragma mark NSURLSessionDelegates

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    BOOL success = NO;
    NSError *error = nil;

    MTSapMachineDownload *download = [_activeDownloads objectForKey:[NSNumber numberWithInteger:[downloadTask taskIdentifier]]];
    MTSapMachineAsset *asset = [download asset];
    
    if (location && asset) {
        
        // verify the checksum for the url
        NSString *checksumString = @"";
        
        for (NSString *key in [[asset downloadURLs] allKeys]) {
            
            NSURL *url = [[asset downloadURLs] valueForKeyPath:[key stringByAppendingString:@".url"]];
            
            if (url && [url isEqualTo:[[downloadTask originalRequest] URL]]) {
                checksumString = [[asset downloadURLs] valueForKeyPath:[key stringByAppendingString:@".checksum"]];
                break;
            }
        }

        if ([[MTChecksum sha256ChecksumWithPath:[location path]] caseInsensitiveCompare:checksumString] == NSOrderedSame) {
                        
            // do we just download the package or should
            // the package also be installed?
            if ([asset isUpdating]) {
                
                // create folder for upacking
                NSString *unpackingPath = [[location path] stringByAppendingPathExtension:@"unpacking"];
                success = [[NSFileManager defaultManager] createDirectoryAtPath:unpackingPath
                                                    withIntermediateDirectories:NO
                                                                     attributes:nil
                                                                          error:&error
                ];
                
                if (success) {

                    success = NO;
                    
                    NSTask *unpackingTask = [[NSTask alloc] init];
                    [unpackingTask setExecutableURL:[NSURL fileURLWithPath:kMTUnarchiverPath]];
                    [unpackingTask setArguments:[NSArray arrayWithObjects:
                                                 @"-xzf", [location path],
                                                 @"-C", unpackingPath,
                                                 @"--uname", @"root",
                                                 @"--gname", @"wheel",
                                                 @"--no-xattrs",
                                                 nil
                                                ]
                    ];
                    [unpackingTask setStandardOutput:[NSFileHandle fileHandleWithNullDevice]];
                    [unpackingTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
                    [unpackingTask launch];
                    [unpackingTask waitUntilExit];
                    
                    if ([unpackingTask terminationStatus] == 0) {
                        
                        if ([asset isInUse]) {
                            
                            NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                                             [NSString stringWithFormat:@"Could not update \"%@\" because it was in use", [asset name]], NSLocalizedDescriptionKey,
                                                             @"errorAssetInUse", NSHelpAnchorErrorKey,
                                                             nil
                            ];
                            error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
                            
                        } else {
                            
                            // get the name of the unpacked jvm folder
                            NSArray *folderContents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:unpackingPath]
                                                                                    includingPropertiesForKeys:[NSArray arrayWithObject:NSURLNameKey]
                                                                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                                         error:&error
                            ];

                            NSArray *filteredFolderContents = [folderContents filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"lastPathComponent BEGINSWITH %@", @"sapmachine-"]];
                            
                            if ([filteredFolderContents count] == 1) {
                                                                
                                NSString *jvmFolderName = [NSString stringWithFormat:@"sapmachine-%ld%@.%@",
                                                           [[asset currentVersion] majorVersion],
                                                           ([asset isEA]) ? @"-ea" : @"",
                                                           ([asset jvmType] == MTSapMachineJVMTypeJRE) ? kMTJVMTypeJRE : kMTJVMTypeJDK
                                ];
                                
                                NSURL *finalLocation = [NSURL fileURLWithPathComponents:[NSArray arrayWithObjects:kMTJVMFolderPath, jvmFolderName, nil]];
                                
                                if ([[NSFileManager defaultManager] fileExistsAtPath:[finalLocation path]]) {
                                    [[NSFileManager defaultManager] removeItemAtURL:finalLocation error:nil];
                                }

                                success = [[NSFileManager defaultManager] moveItemAtURL:[filteredFolderContents firstObject]
                                                                                  toURL:finalLocation
                                                                                  error:&error
                                ];
                                
                                if (success) {
                                    
                                    location = finalLocation;
                                    
                                    // delete the old asset
                                    if ([asset installURL] && [[asset installURL] isNotEqualTo:finalLocation]) {
                                        [[NSFileManager defaultManager] removeItemAtURL:[asset installURL] error:nil];
                                    }
                                    
                                    // set the new java home url
                                    NSURL *homeURL = [location URLByAppendingPathComponent:@"/Contents/Home"];
                                    [asset setJavaHomeURL:homeURL];
                                    
                                    // if the asset is used in config files to set the JAVA_HOME environment
                                    //  variable, we make sure the files are updated accordingly
                                    if ([[[asset javaHomeConfigFilePaths] allKeys] count] > 0) {
                                        
                                        NSMutableArray *filesToChange = [[NSMutableArray alloc] init];
                                        for (NSArray *fileArray in [[asset javaHomeConfigFilePaths] allValues]) { [filesToChange addObjectsFromArray:fileArray]; }
                                        
                                        [MTJavaHome setEnvironmentVariableAtPaths:filesToChange
                                                                     usingJVMPath:[homeURL path]
                                                                completionHandler:nil];
                                    }
                                }
                                
                            } else {
                                
                                // unpacked jvm folder not found
                                NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                 [NSString stringWithFormat:@"Unpacked file \"%@\" with unexpected results", [location path]], NSLocalizedDescriptionKey,
                                                                 @"errorUnpackingUnexpected", NSHelpAnchorErrorKey,
                                                                 nil
                                ];
                                error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
                            }
                        }
                        
                    // unpacking failed
                    } else {
                        
                        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                                         [NSString stringWithFormat:@"Failed to unpack file \"%@\"", [location path]], NSLocalizedDescriptionKey,
                                                         @"errorUnpackingFailed", NSHelpAnchorErrorKey,
                                                         nil
                        ];
                        error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
                    }
                }
                
                // delete the unpacking folder
                [[NSFileManager defaultManager] removeItemAtPath:unpackingPath error:nil];
                
            // we just downloaded the asset and verified its checksum
            } else {
                
                NSURL *parentFolder = [location URLByDeletingLastPathComponent];
                NSString *suggestedFilename = [[downloadTask response] suggestedFilename];
                NSURL *finalLocation = [parentFolder URLByAppendingPathComponent:suggestedFilename];
                
                [[NSFileManager defaultManager] moveItemAtURL:location
                                                        toURL:finalLocation
                                                        error:&error];
                
                if (!error) {
                    location = finalLocation;
                    success = YES;
                }
            }
            
        // checksum error
        } else {
            
            NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                             @"The checksum of the downloaded file could not be successfully verified", NSLocalizedDescriptionKey,
                                             @"errorChecksum", NSHelpAnchorErrorKey,
                                             nil
            ];
            error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
        }
        
    // location or asset is nil
    } else {
        
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"An unknown error occurred", NSLocalizedDescriptionKey,
                                         @"errorUnknown", NSHelpAnchorErrorKey,
                                         nil
        ];
        error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
    }
        
    if (asset) {
        
        if (success) {
            
            if ([asset isUpdating]) {
                
                [asset setIsUpdating:NO];
                [asset setInstalledVersion:[asset currentVersion]];
            }
                
            [asset setInstallURL:location];
            
            if (_updateDelegate && [_updateDelegate respondsToSelector:@selector(updateFinishedForAsset:)]) {
                [_updateDelegate updateFinishedForAsset:asset];
            }
            
        } else {
                  
            _downloadSuccess = NO;
            [asset setIsUpdating:NO];
            
            if (_updateDelegate && [_updateDelegate respondsToSelector:@selector(updateFailedForAsset:withError:)]) {
                [_updateDelegate updateFailedForAsset:asset withError:error];
            }
        }
    }
    
    dispatch_semaphore_t semaphore = [download semaphore];
    dispatch_semaphore_signal(semaphore);
    
    [_activeDownloads removeObjectForKey:[NSNumber numberWithInteger:[downloadTask taskIdentifier]]];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    double progress = (100 / (double)totalBytesExpectedToWrite) * (double)totalBytesWritten;

    MTSapMachineDownload *download = [_activeDownloads objectForKey:[NSNumber numberWithInteger:[downloadTask taskIdentifier]]];
    MTSapMachineAsset *asset = [download asset];

    if (asset) {
        
        [asset setUpdateProgress:progress];
        
        if (_updateDelegate && [_updateDelegate respondsToSelector:@selector(downloadProgressUpdatedForAsset:)]) {
            [_updateDelegate downloadProgressUpdatedForAsset:asset];
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        
        _downloadSuccess = NO;
        
        MTSapMachineDownload *download = [_activeDownloads objectForKey:[NSNumber numberWithInteger:[task taskIdentifier]]];
        MTSapMachineAsset *asset = [download asset];
        
        if (asset && _updateDelegate && [_updateDelegate respondsToSelector:@selector(updateFailedForAsset:withError:)]) {
            [_updateDelegate updateFailedForAsset:asset withError:error];
        }
        
        dispatch_semaphore_t semaphore = [download semaphore];
        dispatch_semaphore_signal(semaphore);
        
        [_activeDownloads removeObjectForKey:[NSNumber numberWithInteger:[task taskIdentifier]]];
    }
}

@end
