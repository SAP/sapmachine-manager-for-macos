/*
     MTPackageBuildController.m
     Copyright 2023 SAP SE
     
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

#import "MTPackageBuildController.h"
#import "Constants.h"

@interface MTPackageBuildController ()
@property (nonatomic, strong, readwrite) NSMutableDictionary *assetsToBeDownloaded;
@property (assign) BOOL packagingInProgress;
@property (assign) BOOL packagingSuccess;

@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *statusTextField;
@property (weak) IBOutlet NSImageView *finishImageView;
@property (weak) IBOutlet NSTextField *finishTextField;
@property (weak) IBOutlet NSTextField *finishAdditionalTextField;
@property (weak) IBOutlet NSTextField *failAdditionalTextField;
@end

@implementation MTPackageBuildController

- (void)viewDidLoad
{
    [super viewDidLoad];

    _assetsToBeDownloaded = [[NSMutableDictionary alloc] init];
    
    // if the user decided to only download the asset for a certain platform,
    // we make sure the asset object only contains the download data for the
    // selected platform.

    if (_selectedArchitecture == 1) {
        
        MTSapMachineAsset *asset = [self assetForPlatform:kMTSapMachineArchApple];
        if (asset) { [_assetsToBeDownloaded setObject:asset forKey:kMTSapMachineArchApple]; }
        
    } else if (_selectedArchitecture == 2) {
        
        MTSapMachineAsset *asset = [self assetForPlatform:kMTSapMachineArchIntel];
        if (asset) { [_assetsToBeDownloaded setObject:asset forKey:kMTSapMachineArchIntel]; }
    
    } else {

        MTSapMachineAsset *asset = [self assetForPlatform:kMTSapMachineArchApple];
        if (asset) { [_assetsToBeDownloaded setObject:asset forKey:kMTSapMachineArchApple]; }
        
        asset = [self assetForPlatform:kMTSapMachineArchIntel];
        if (asset) { [_assetsToBeDownloaded setObject:asset forKey:kMTSapMachineArchIntel]; }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.packagingInProgress = YES;
        self.packagingSuccess = NO;
    });
        
    MTSapMachine *sapMachine = [[MTSapMachine alloc] initWithURL:[NSURL URLWithString:kMTSapMachineReleasesURL]];
    [sapMachine setUpdateDelegate:self];
    [sapMachine downloadAssets:[_assetsToBeDownloaded allValues]
                       install:NO
             completionHandler:^(BOOL success) {
        
        if (success) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_statusTextField setStringValue:NSLocalizedString(@"packageBuildPrepare", nil)];
            });
            
            NSError *error = nil;
            
            // create build directory
            MTSapMachineAsset *asset = [[self->_assetsToBeDownloaded allValues] firstObject];
            NSString *directoryName = [NSString stringWithFormat:@"sapmachine-%ld%@.%@",
                                       [[asset currentVersion] majorVersion],
                                       ([asset isEA]) ? @"-ea" : @"",
                                       ([asset jvmType] == MTSapMachineJVMTypeJRE) ? kMTJVMTypeJRE : kMTJVMTypeJDK
            ];
            NSURL *buildDir = [self createBuildDirectoryWithName:directoryName error:&error];
            
            if (error) {
                
                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to create package build directory: %{public}@", error);
            
            } else {
                
                // move the downloaded files into the build directory
                for (MTSapMachineAsset *asset in [self->_assetsToBeDownloaded allValues]) {

                    [[NSFileManager defaultManager] moveItemAtURL:[asset installURL]
                                                            toURL:[buildDir URLByAppendingPathComponent:[[asset installURL] lastPathComponent]]
                                                            error:&error
                    ];
                    
                    if (error) { break; }
                }
                
                if (error) {
                    
                    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to move file: %{public}@", error);
                    
                } else {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.progressIndicator incrementBy:5];
                    });
                    
                    // create the postinstall script
                    NSURL *urlApple = [self->_assetsToBeDownloaded valueForKeyPath:[kMTSapMachineArchApple stringByAppendingString:@".installURL"]];
                    NSURL *urlIntel = [self->_assetsToBeDownloaded valueForKeyPath:[kMTSapMachineArchIntel stringByAppendingString:@".installURL"]];

                    // create the postinstall script
                    NSURL *scriptTemplateURL = [[NSBundle mainBundle] URLForResource:@"postinstall" withExtension:@"txt"];
                    NSString *scriptString = [NSString stringWithContentsOfURL:scriptTemplateURL encoding:NSUTF8StringEncoding error:&error];
                    
                    if (error) {
                        
                        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to open template for postinstall script: %{public}@", error);
                        
                        if ([error localizedDescription]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.failAdditionalTextField setStringValue:[error localizedDescription]];
                            });
                        }
                        
                    } else {
                        
                        NSString *appleArchive = (urlApple) ? [NSString stringWithFormat:@"${0%%/*}/%@", [urlApple lastPathComponent]] : @"";
                        scriptString = [scriptString stringByReplacingOccurrencesOfString:@"{{installerAppleSilicon}}" withString:appleArchive];
                        
                        NSString *intelArchive = (urlIntel) ? [NSString stringWithFormat:@"${0%%/*}/%@", [urlIntel lastPathComponent]] : @"";
                        scriptString = [scriptString stringByReplacingOccurrencesOfString:@"{{installerIntelProcessor}}" withString:intelArchive];
                        scriptString = [scriptString stringByReplacingOccurrencesOfString:@"{{targetFolder}}" withString:kMTJVMFolderPath];
                        
                        NSURL *postinstallFileURL = [buildDir URLByAppendingPathComponent:@"postinstall"];
                        [scriptString writeToURL:postinstallFileURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
                        
                        if (error) {
                            
                            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to create postinstall script: %{public}@", error);
                            
                            if ([error localizedDescription]) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    [self.failAdditionalTextField setStringValue:[error localizedDescription]];
                                });
                            }
                            
                            [self setPackagingProgressFinishedAndDeleteFolder:buildDir];
                            
                        } else {
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.progressIndicator incrementBy:5];
                            });
                            
                            // set the correct permissions for the script
                            NSDictionary* attrs = [NSDictionary dictionaryWithObject:[NSNumber numberWithShort:0755] forKey: NSFilePosixPermissions];
                            
                            [[NSFileManager defaultManager] setAttributes:attrs
                                                             ofItemAtPath:[postinstallFileURL path]
                                                                    error:&error
                            ];
                            
                            if (error) {
                                
                                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to set permissions for postinstall script: %{public}@", error);
                                
                                if ([error localizedDescription]) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        [self.failAdditionalTextField setStringValue:[error localizedDescription]];
                                    });
                                }
                                [self setPackagingProgressFinishedAndDeleteFolder:buildDir];
                                
                            } else {
                                
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    
                                    [self.progressIndicator incrementBy:5];
                                    
                                    MTDaemonConnection *daemonConnection = [[MTDaemonConnection alloc] init];
                                    [daemonConnection connectToXPCServiceWithRemoteObjectProxyReply:^(id remoteObjectProxy, NSError *error) {
                                        
                                        [remoteObjectProxy releaseFileFromQuarantineAtURL:buildDir
                                                                                recursive:YES
                                                                        completionHandler:^(NSError *error) {
                                            
                                            [daemonConnection invalidate];
                                            
                                            if (error) {
                                                
                                                os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to release package files from quarantine: %{public}@", error);
                                                
                                                if ([error localizedDescription]) {
                                                    dispatch_async(dispatch_get_main_queue(), ^{
                                                        [self.failAdditionalTextField setStringValue:[error localizedDescription]];
                                                    });
                                                }
                                                
                                                [self setPackagingProgressFinishedAndDeleteFolder:buildDir];
                                                
                                            } else {
                                                
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    [self.progressIndicator incrementBy:5];
                                                });
                                                
                                                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                    
                                                    [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:buildDir]
                                                                       withApplicationAtURL:[NSURL fileURLWithPath:@"/Applications/Script2Pkg.app"]
                                                                              configuration:[NSWorkspaceOpenConfiguration new]
                                                                          completionHandler:^(NSRunningApplication *app, NSError *error) {
                                                        
                                                        dispatch_async(dispatch_get_main_queue(), ^{
                                                            
                                                            [self setPackagingProgressFinishedAndDeleteFolder:nil];
                                                            [self->_finishTextField setStringValue:[NSString localizedStringWithFormat:NSLocalizedString(@"packageBuildFinish", nil), [buildDir lastPathComponent]]];
                                                            
                                                            if (error) {
                                                                
                                                                os_log(OS_LOG_DEFAULT, "SAPCorp: Failed to launch Script2Pkg: %{public}@", error);
                                                                
                                                                [self->_finishImageView setImage:[NSImage imageWithSystemSymbolName:@"checkmark.circle.trianglebadge.exclamationmark" accessibilityDescription:nil]];
                                                                [self->_finishAdditionalTextField setStringValue:NSLocalizedString(@"packageBuildNoScript2Pkg", nil)];
                                                            }
                                                            
                                                            self.packagingSuccess = YES;
                                                        });
                                                        
                                                        // show build directory in Finder
                                                        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:[NSArray arrayWithObject:buildDir]];
                                                    }];
                                                });
                                            }
                                        }];
                                    }];
                                });
                            }
                        }
                    }
                }
            }
            
        } else {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.packagingInProgress = NO;
            });
                
            // delete the downloaded files
            for (MTSapMachineAsset *asset in [self->_assetsToBeDownloaded allValues]) {
                [[NSFileManager defaultManager] removeItemAtURL:[asset installURL] error:nil];
            }
        }
    }];
}

- (MTSapMachineAsset*)assetForPlatform:(NSString*)platform
{
    MTSapMachineAsset *asset = [_selectedAsset copy];
    NSDictionary *platformDict = [[asset downloadURLs] objectForKey:platform];

    if (platformDict) {
        
        NSDictionary *newURLDict = [NSDictionary dictionaryWithObject:platformDict forKey:platform];
        [asset setDownloadURLs:newURLDict];
        
    } else {
        
        asset = nil;
    }
    
    return asset;
}

- (void)setPackagingProgressFinishedAndDeleteFolder:(NSURL*)url
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.packagingInProgress = NO;
    });
    
    if (url) { [[NSFileManager defaultManager] removeItemAtURL:url error:nil]; }
}

- (NSURL*)createBuildDirectoryWithName:(NSString*)name error:(NSError**)error
{
    NSURL *buildDirURL = nil;
    
    if ([name length] > 0) {
        
        buildDirURL = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory
                                                             inDomain:NSUserDomainMask
                                                    appropriateForURL:[NSURL fileURLWithPath:@"/"]
                                                               create:YES
                                                                error:error
        ];
        
        if (!*error) {
            
            buildDirURL = [buildDirURL URLByAppendingPathComponent:name];
            
            [[NSFileManager defaultManager] createDirectoryAtURL:buildDirURL
                                     withIntermediateDirectories:NO
                                                      attributes:nil
                                                           error:error
            ];
        }
    }
    
    return (*error) ? nil : buildDirURL;
}

#pragma mark MTSapMachineAssetUpdateDelegate

- (void)updateStartedForAsset:(MTSapMachineAsset*)asset
{
    return;
}

- (void)updateFinishedForAsset:(MTSapMachineAsset*)asset
{
    return;
}

- (void)updateFailedForAsset:(MTSapMachineAsset*)asset withError:(NSError*)error
{
    if (error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
                    
            if ([error helpAnchor] && NSLocalizedString([error helpAnchor], nil)) {
                [self.failAdditionalTextField setStringValue:NSLocalizedString([error helpAnchor], nil)];
            } else {
                [self.failAdditionalTextField setStringValue:[error localizedDescription]];
            }
        });
    }
}

- (void)downloadProgressUpdatedForAsset:(MTSapMachineAsset*)asset
{
    double percentCompleted = [[[self->_assetsToBeDownloaded allValues] valueForKeyPath:@"@avg.updateProgress"] doubleValue];
    double progress = (80.0 / 100) * percentCompleted;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressIndicator setDoubleValue:progress];
    });
}

@end
