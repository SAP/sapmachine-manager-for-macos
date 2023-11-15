/*
     MTInstallController.m
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

#import "MTInstallController.h"
#import "MTSapMachineUser.h"
#import "Constants.h"

@interface MTInstallController ()
@property (nonatomic, strong, readwrite) MTDaemonConnection *daemonConnection;
@property (nonatomic, strong, readwrite) NSOperationQueue *operationQueue;
@property (atomic, copy, readwrite) NSData *authData;
@property (assign) BOOL installInProgress;
@property (assign) BOOL installSuccess;

@property (weak) IBOutlet NSProgressIndicator *progressIndicator;
@property (weak) IBOutlet NSTextField *failAdditionalTextField;
@end

@implementation MTInstallController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.installInProgress = YES;
    self.installSuccess = NO;

    _operationQueue = [[NSOperationQueue alloc] init];
    _daemonConnection = [[MTDaemonConnection alloc] init];
    
    MTSapMachineUser *user = [[MTSapMachineUser alloc] initWithUserName:NSUserName()];
                        
    NSBlockOperation *authOperation = [[NSBlockOperation alloc] init];
    [authOperation addExecutionBlock:^{
        
        self->_authData = nil;
        
        if (![user isPrivileged]) {
            
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [self->_daemonConnection connectToXPCServiceWithRemoteObjectProxyReply:^(id remoteObjectProxy, NSError *error) {
                    
                    [remoteObjectProxy authenticateWithAuthorizationReply:^(NSData *authorization) {
                        
                        self->_authData = authorization;
                        dispatch_semaphore_signal(semaphore);
                    }];
                }];
            });
            
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }
    }];
    
    NSBlockOperation *privilegedOperation = [[NSBlockOperation alloc] init];
    [privilegedOperation addExecutionBlock:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self->_daemonConnection connectToDaemonWithExportedObject:self
                                                andExecuteCommandBlock:^{
                
                [[self->_daemonConnection remoteObjectProxy] downloadAssets:[NSArray arrayWithObject:self->_selectedAsset]
                                                                    install:YES
                                                              authorization:self->_authData
                                                          completionHandler:^(BOOL success, NSError *error) {
                    self->_authData = nil;
                    
                    if (error) {
                        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to install asset: %{public}@", error);
                        
                        if ([error helpAnchor] && NSLocalizedString([error helpAnchor], nil)) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.failAdditionalTextField setStringValue:NSLocalizedString([error helpAnchor], nil)];
                            });
                        }
                    }
                    
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kMTDefaultsInstallFinished];
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        self.installSuccess = success;
                        self.installInProgress = NO;
                        
                        [self->_daemonConnection invalidate];
                        self->_daemonConnection = nil;
                    });
                }];
            }];
        });
    }];
    
    [privilegedOperation addDependency:authOperation];
    [self->_operationQueue addOperations:[NSArray arrayWithObjects:authOperation, privilegedOperation, nil]
                       waitUntilFinished:NO];
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.progressIndicator setDoubleValue:[asset updateProgress]];
    });
}

@end
