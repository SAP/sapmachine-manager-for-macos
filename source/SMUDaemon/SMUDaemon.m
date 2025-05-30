/*
     SMUDaemon.m
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

#import "SMUDaemon.h"
#import "MTSapMachine.h"
#import "MTSapMachineUser.h"
#import "MTJavaHome.h"
#import "MTCodeSigning.h"
#import <os/log.h>

@interface SMUDaemon ()
@property (nonatomic, strong, readwrite) NSMutableSet *activeConnections;
@property (nonatomic, strong, readwrite) NSArray<MTSapMachineAsset*>* assetCatalog;
@property (atomic, strong, readwrite) NSXPCListener *listener;
@property (assign) BOOL operationInProgress;
@end

@implementation SMUDaemon

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        
        _activeConnections = [[NSMutableSet alloc] init];
        
        _listener = [[NSXPCListener alloc] initWithMachServiceName:kMTDaemonMachServiceName];
        [_listener setDelegate:self];
        [_listener resume];
    }
    
    return self;
}

- (void)invalidateXPC
{
    [_listener invalidate];
    _listener = nil;
    
    [_activeConnections removeAllObjects];
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    BOOL acceptConnection = NO;
    
    if (listener == _listener && newConnection != nil) {
        
        NSError *error = nil;
        NSString *signingAuth = [MTCodeSigning getSigningAuthorityWithError:&error];
        NSString *requiredVersion = [[NSBundle bundleForClass:[self class]] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        
        if (signingAuth) {
            
            NSString *reqString = [MTCodeSigning codeSigningRequirementsWithCommonName:signingAuth
                                                                      bundleIdentifier:@"corp.sap.SapMachine*"
                                                                         versionString:requiredVersion
            ];

            [newConnection setCodeSigningRequirement:reqString];
            
            NSXPCInterface *exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(SMUDaemonProtocol)];
            
            [exportedInterface setClasses:[NSSet setWithObjects:[MTSapMachineAsset class], [NSArray class], nil]
                              forSelector:@selector(downloadAssets:install:authorization:completionHandler:)
                            argumentIndex:0
                                  ofReply:NO
            ];
            [exportedInterface setClasses:[NSSet setWithObjects:[MTSapMachineAsset class], [NSArray class], nil]
                              forSelector:@selector(deleteAssets:authorization:completionHandler:)
                            argumentIndex:0
                                  ofReply:NO
            ];
            [exportedInterface setClasses:[NSSet setWithObjects:[MTSapMachineAsset class], [NSArray class], nil]
                              forSelector:@selector(updateAssets:completionHandler:)
                            argumentIndex:0
                                  ofReply:NO
            ];
            
            [newConnection setExportedInterface:exportedInterface];
            [newConnection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(MTSapMachineAssetUpdateDelegate)]];
            [newConnection setExportedObject:self];
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
            [newConnection setInvalidationHandler:^{
                          
                [newConnection setInvalidationHandler:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.activeConnections removeObject:newConnection];
                    os_log(OS_LOG_DEFAULT, "SAPCorp: %{public}@ invalidated", newConnection);
                });
            }];
#pragma clang diagnostic pop
            
            // Resuming the connection allows the system to deliver more incoming messages.
            [newConnection resume];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                os_log(OS_LOG_DEFAULT, "SAPCorp: %{public}@ established", newConnection);
                [self.activeConnections addObject:newConnection];
            });
            
            
            acceptConnection = YES;
        }
    }

    return acceptConnection;
}

- (NSDate*)lastSuccessfulCheck
{
    NSDate *lastDate = [NSDate distantPast];
    
    CFPropertyListRef property = CFPreferencesCopyValue(kMTPrefsLastCheckSuccessKey, kMTDaemonPreferenceDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
    
    if (property) {
        lastDate = (__bridge NSDate *)(property);
        CFRelease(property);
    }
    
    return lastDate;
}

- (NSInteger)numberOfActiveXPCConnections
{
    return [_activeConnections count];
}

- (BOOL)allowedUserWithAuthorization:(NSData*)authData
{
    MTSapMachineUser *user = [[MTSapMachineUser alloc] initWithUserID:[[NSXPCConnection currentConnection] effectiveUserIdentifier]];
    BOOL isAllowed = [user isPrivileged];
    
    // if the current user is not an admin user, we
    // check if admin credentials have been provided
    if (!isAllowed && authData && [authData length] == sizeof(AuthorizationExternalForm)) {
        
        AuthorizationRef authRef;
        OSStatus status = AuthorizationCreateFromExternalForm([authData bytes], &authRef);
        
        if (status == errAuthorizationSuccess) {
            
            AuthorizationItem authItem = {kAuthorizationRuleAuthenticateAsAdmin, 0, NULL, 0};
            AuthorizationRights authRights = {1, &authItem};
            
            status = AuthorizationCopyRights(
                                             authRef,
                                             &authRights,
                                             NULL,
                                             kAuthorizationFlagExtendRights,
                                             NULL
                                             );
            
            if (status == errAuthorizationSuccess) { isAllowed = YES; }
        }

        if (authRef != NULL) { AuthorizationFree(authRef, kAuthorizationFlagDestroyRights); }
    }
    
    return isAllowed;
}

#pragma mark exported methods

- (void)connectWithEndpointReply:(void (^)(NSXPCListenerEndpoint *endpoint))reply
{
    reply([_listener endpoint]);
}

- (void)availableAssetsWithReply:(void (^)(NSArray<MTSapMachineAsset*> *availableAssets))reply
{
    // set our delegate
    NSXPCConnection *currentConnection = [NSXPCConnection currentConnection];
    if (currentConnection) { [self setUpdateDelegate:[currentConnection remoteObjectProxy]]; }
    
    if (!_operationInProgress) {
        
        _operationInProgress = YES;
        
        MTSapMachine *sapMachine = [[MTSapMachine alloc] initWithURL:[NSURL URLWithString:kMTSapMachineReleasesURL]];
        
        MTSapMachineUser *user = [[MTSapMachineUser alloc] initWithUserID:[[NSXPCConnection currentConnection] effectiveUserIdentifier]];
        [sapMachine setEffectiveUserName:[user userName]];
        
        [sapMachine assetCatalogWithCompletionHandler:^(NSArray<MTSapMachineAsset *> *assetCatalog, NSError *error) {
            
            self->_operationInProgress = NO;
            
            if (error) {
                
                reply(nil);
                
            } else {
                
                self->_assetCatalog = assetCatalog;
                reply(assetCatalog);
                
                CFPreferencesSetValue(kMTPrefsLastCheckSuccessKey, (__bridge CFPropertyListRef)([NSDate date]), kMTDaemonPreferenceDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
            }
        }];
        
    } else {
        
        reply(_assetCatalog);
    }
}

- (void)updateAssets:(NSArray<MTSapMachineAsset*>*)assets completionHandler:(void (^)(BOOL success))completionHandler
{
    // set our delegate
    NSXPCConnection *currentConnection = [NSXPCConnection currentConnection];
    if (currentConnection) { [self setUpdateDelegate:[currentConnection remoteObjectProxy]]; }
    
    if (!_operationInProgress) {
        
        _operationInProgress = YES;
        
        MTSapMachine *sapMachine = [[MTSapMachine alloc] initWithURL:[NSURL URLWithString:kMTSapMachineReleasesURL]];
        
        MTSapMachineUser *user = [[MTSapMachineUser alloc] initWithUserID:[[NSXPCConnection currentConnection] effectiveUserIdentifier]];
        [sapMachine setEffectiveUserName:[user userName]];
        [sapMachine setUpdateDelegate:self];
        
        [sapMachine assetCatalogWithCompletionHandler:^(NSArray<MTSapMachineAsset *> *assetCatalog, NSError *error) {
            
            self->_assetCatalog = assetCatalog;
            
            NSPredicate *predicate = nil;
            
            if ([assets count] > 0) {
                
                NSMutableArray *subPredicates = [NSMutableArray array];
                
                for (MTSapMachineAsset *asset in assets) {
                    
                    if ([asset installURL]) {
                        
                        NSPredicate *subPredicate = [NSPredicate predicateWithFormat:@"installURL.absoluteString == %@", [[asset installURL] absoluteString]];
                        [subPredicates addObject:subPredicate];
                    }
                }
                
                predicate = [NSCompoundPredicate orPredicateWithSubpredicates:subPredicates];
                
            } else {
                
                predicate = [NSPredicate predicateWithFormat:@"installURL != nil"];
            }
            
            [sapMachine downloadAssets:[assetCatalog filteredArrayUsingPredicate:predicate]
                               install:YES
                     completionHandler:^(BOOL success) {
                
                self->_operationInProgress = NO;
                
                CFPreferencesSetValue(kMTPrefsLastUpdateSuccessKey, (__bridge CFPropertyListRef)([NSDate date]), kMTDaemonPreferenceDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
                
                completionHandler(success);
            }];
        }];
        
    } else {
        
        completionHandler(NO);
    }
}

- (void)updateAllAssetsWithCompletionHandler:(void (^)(BOOL success))completionHandler
{
    [self updateAssets:nil completionHandler:^(BOOL success) {
        completionHandler(success);
    }];
}

- (void)downloadAssets:(NSArray<MTSapMachineAsset*>*)assets install:(BOOL)install authorization:(NSData *)authData completionHandler:(void (^)(BOOL success, NSError *error))completionHandler
{
    NSError *error = nil;
    
    if (install && ![self allowedUserWithAuthorization:authData]) {
        
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"The current user is not authorized to install SapMachine", NSLocalizedDescriptionKey,
                                         @"errorUserNotAuthorizedInstall", NSHelpAnchorErrorKey,
                                         nil
        ];
        error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
        
        completionHandler(NO, error);
        
    } else {
        
        if (_operationInProgress) {
            
            NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                             @"Another operation is already in progress", NSLocalizedDescriptionKey,
                                             @"errorOperationInProgress", NSHelpAnchorErrorKey,
                                             nil
            ];
            error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
            
            completionHandler(NO, error);
            
        } else {
            
            // set our delegate
            NSXPCConnection *currentConnection = [NSXPCConnection currentConnection];
            if (currentConnection) { [self setUpdateDelegate:[currentConnection remoteObjectProxy]]; }
            
            if ([assets count] > 0) {
                
                _operationInProgress = YES;
                
                MTSapMachine *sapMachine = [[MTSapMachine alloc] initWithURL:[NSURL URLWithString:kMTSapMachineReleasesURL]];
                
                MTSapMachineUser *user = [[MTSapMachineUser alloc] initWithUserID:[[NSXPCConnection currentConnection] effectiveUserIdentifier]];
                [sapMachine setEffectiveUserName:[user userName]];
                [sapMachine setUpdateDelegate:self];
                
                [sapMachine assetCatalogWithCompletionHandler:^(NSArray<MTSapMachineAsset *> *assetCatalog, NSError *error) {
                    
                    if (!error) {
                        
                        self->_assetCatalog = assetCatalog;
                        
                        // check if the given assets are in the asset catalog
                        NSMutableArray *checkedAssets = [[NSMutableArray alloc] init];
                        
                        for (MTSapMachineAsset *asset in assets) {
                            
                            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"downloadURLs == %@", [asset downloadURLs]];
                            NSArray *filteredArray = [self->_assetCatalog filteredArrayUsingPredicate:predicate];
                            
                            if ([filteredArray count] > 0) { [checkedAssets addObject:asset]; }
                        }
                        
                        [sapMachine downloadAssets:checkedAssets
                                           install:install
                                 completionHandler:^(BOOL success) {
                            
                            self->_operationInProgress = NO;
                            
                            completionHandler(success, error);
                        }];
                        
                    } else {
                        
                        completionHandler(NO, error);
                    }
                }];
                
            } else {
                
                NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                                 @"No assets provided", NSLocalizedDescriptionKey,
                                                 @"errorNoAssets", NSHelpAnchorErrorKey,
                                                 nil
                ];
                error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
                
                completionHandler(NO, error);
            }
        }
    }
}

- (void)deleteAssets:(NSArray<MTSapMachineAsset*>*)assets authorization:(NSData *)authData completionHandler:(void (^)(NSArray<MTSapMachineAsset*> *deletedAssets, NSError *error))completionHandler
{
    NSError *error = nil;
    NSMutableArray *deletedAssets = [[NSMutableArray alloc] init];
    
    if ([self allowedUserWithAuthorization:authData]) {
        
        NSMutableArray *filesToChange = [[NSMutableArray alloc] init];
        
        for (MTSapMachineAsset *asset in assets) {
                        
            if (asset && [asset installURL]) {
                
                // check if the given asset is in the asset catalog
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"installURL == %@", [asset installURL]];
                NSArray *filteredArray = [self->_assetCatalog filteredArrayUsingPredicate:predicate];
                
                if ([filteredArray count] > 0) {
                    
                    [[NSFileManager defaultManager] removeItemAtURL:[asset installURL]
                                                              error:&error
                    ];
                }
                
                if (!error) {
                    
                    if ([[[asset javaHomeConfigFilePaths] allKeys] count] > 0) {
                        
                        for (NSArray *fileArray in [[asset javaHomeConfigFilePaths] allValues]) { [filesToChange addObjectsFromArray:fileArray]; }
                    }
                    
                    [deletedAssets addObject:asset];
                    
                } else {
                    
                    break;
                }
                
            } else {
                
                NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                                 @"No install url provided", NSLocalizedDescriptionKey,
                                                 @"errorNoInstallURL", NSHelpAnchorErrorKey,
                                                 nil
                ];
                error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
                break;
            }
        }
        
        // if a deleted asset was used as the default environment,
        // we also unset JAVA_HOME
        if ([filesToChange count] > 0) {

            [MTJavaHome unsetEnvironmentVariableAtPaths:filesToChange completionHandler:^(NSArray *changedFiles) {
                completionHandler(deletedAssets, error);
            }];
            
        } else {
            
            completionHandler(deletedAssets, error);
        }
        
    } else {
        
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"The current user is not authorized to delete SapMachine releases", NSLocalizedDescriptionKey,
                                         @"errorUserNotAuthorizedDelete", NSHelpAnchorErrorKey,
                                         nil
        ];
        error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
                
        completionHandler(deletedAssets, error);
    }
}

- (void)setAutomaticUpdatesEnabled:(BOOL)enabled completionHandler:(void (^)(BOOL success))completionHandler
{
    // set the value
    CFPreferencesSetValue(kMTPrefsEnableAutoUpdateKey, (__bridge CFPropertyListRef)([NSNumber numberWithBool:enabled]), kMTDaemonPreferenceDomain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost);
        
    // read the value and compare it
    // with the value we set
    [self automaticUpdatesEnabledWithReply:^(BOOL isEnabled, BOOL isForced) {
        
        completionHandler((enabled == isEnabled) ? YES : NO);
    }];
}

- (void)automaticUpdatesEnabledWithReply:(void (^)(BOOL enabled, BOOL forced))reply
{
    BOOL isEnabled = NO;
    BOOL isForced = CFPreferencesAppValueIsForced(kMTPrefsEnableAutoUpdateKey, kMTDaemonPreferenceDomain);
    
    CFPropertyListRef property = CFPreferencesCopyAppValue(kMTPrefsEnableAutoUpdateKey, kMTDaemonPreferenceDomain);
    
    if (property) {
        isEnabled = CFBooleanGetValue(property);
        CFRelease(property);
    }
    
    reply(isEnabled, isForced);
}

- (void)logEntriesSinceDate:(NSDate*)date completionHandler:(void (^)(NSArray<OSLogEntry*> *entries))completionHandler
{
    OSLogStore *logStore = [OSLogStore storeWithScope:OSLogStoreSystem error:nil];
    
    OSLogPosition *position = (date) ? [logStore positionWithDate:date] : nil;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(process == %@ OR process == %@ OR process == %@) AND eventType == %@ AND messageType != %@", @"SapMachine Manager", @"SapMachineXPC", @"SMUDaemon", @"logEvent", @"debug"];
    
    OSLogEnumerator *logEnumerator = [logStore entriesEnumeratorWithOptions:0
                                                                   position:position
                                                                  predicate:predicate
                                                                      error:nil];
    completionHandler([logEnumerator allObjects]);
}

- (void)setJavaHomeEnvironmentVariableUsingAsset:(MTSapMachineAsset*)asset userOnly:(BOOL)userOnly authorization:(NSData *)authData completionHandler:(void (^)(BOOL success, NSError *error))completionHandler
{
    NSError *error = nil;
    
    if (userOnly || (!userOnly && [self allowedUserWithAuthorization:authData])) {

        if (asset && [asset javaHomeURL]) {
            
            // check if the given asset is in the asset catalog
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"javaHomeURL == %@", [asset javaHomeURL]];
            NSArray *filteredArray = [self->_assetCatalog filteredArrayUsingPredicate:predicate];
            
            if ([filteredArray count] > 0) {
                
                MTSapMachineUser *user = [[MTSapMachineUser alloc] initWithUserID:[[NSXPCConnection currentConnection] effectiveUserIdentifier]];
                NSDictionary *configFiles = [MTJavaHome configFilesWithUserName:[user userName] userOnly:userOnly recommendedOnly:YES];
                NSMutableArray *filesToChange = [[NSMutableArray alloc] init];
                for (NSArray *fileArray in [configFiles allValues]) { [filesToChange addObjectsFromArray:fileArray]; }

                [MTJavaHome setEnvironmentVariableAtPaths:filesToChange
                                             usingJVMPath:[[asset javaHomeURL] path]
                                        completionHandler:^(BOOL success) {

                    completionHandler(success, error);
                }];
                
            } else {
                
                completionHandler(NO, error);
            }
            
        } else {
            
            NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                             @"No home url provided", NSLocalizedDescriptionKey,
                                             nil
            ];
            error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
            
            completionHandler(NO, error);
        }
    
    } else {
        
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"The current user is not authorized to change the default Java environment", NSLocalizedDescriptionKey,
                                         nil
        ];
        error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
                
        completionHandler(NO, error);
    }
}

- (void)unsetJavaHomeEnvironmentVariableForUserOnly:(BOOL)userOnly authorization:(NSData *)authData completionHandler:(void (^)(NSArray *changedFiles, NSError *error))completionHandler
{
    if (userOnly || (!userOnly && [self allowedUserWithAuthorization:authData])) {
    
        MTSapMachineUser *user = [[MTSapMachineUser alloc] initWithUserID:[[NSXPCConnection currentConnection] effectiveUserIdentifier]];
        NSDictionary *configFiles = [MTJavaHome configFilesWithUserName:[user userName] userOnly:userOnly recommendedOnly:NO];
        NSMutableArray *filesToChange = [[NSMutableArray alloc] init];
        for (NSArray *fileArray in [configFiles allValues]) { [filesToChange addObjectsFromArray:fileArray]; }

        [MTJavaHome unsetEnvironmentVariableAtPaths:filesToChange completionHandler:^(NSArray *changedFiles) {
            completionHandler(changedFiles, nil);
        }];
        
    } else {
        
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"The current user is not authorized to change the default Java environment", NSLocalizedDescriptionKey,
                                         nil
        ];
        NSError *error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
                
        completionHandler(nil, error);
    }
}

#pragma mark MTSapMachineAssetUpdateDelegate methods

- (void)updateStartedForAsset:(MTSapMachineAsset*)asset
{
    os_log(OS_LOG_DEFAULT, "SAPCorp: Download of asset %{public}@ (%{public}@) started", [asset name], [[asset currentVersion] versionString]);
    
    if (_updateDelegate && [_updateDelegate respondsToSelector:@selector(updateStartedForAsset:)]) {
        [_updateDelegate updateStartedForAsset:asset];
    }
}

- (void)updateFinishedForAsset:(MTSapMachineAsset*)asset
{
    os_log(OS_LOG_DEFAULT, "SAPCorp: Download of asset %{public}@ (%{public}@) finished successfully", [asset name], [[asset currentVersion] versionString]);
    
    if (_updateDelegate && [_updateDelegate respondsToSelector:@selector(updateFinishedForAsset:)]) {
        [_updateDelegate updateFinishedForAsset:asset];
    }
}

- (void)updateFailedForAsset:(MTSapMachineAsset*)asset withError:(NSError*)error
{
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_ERROR, "SAPCorp: Download of asset %{public}@ (%{public}@) failed: %{public}@", [asset name], [[asset currentVersion] versionString], error);
    
    if (_updateDelegate && [_updateDelegate respondsToSelector:@selector(updateFailedForAsset:withError:)]) {
        [_updateDelegate updateFailedForAsset:asset withError:error];
    }
}

- (void)downloadProgressUpdatedForAsset:(MTSapMachineAsset*)asset
{
    if (_updateDelegate && [_updateDelegate respondsToSelector:@selector(downloadProgressUpdatedForAsset:)]) {
        [_updateDelegate downloadProgressUpdatedForAsset:asset];
    }
}

@end
