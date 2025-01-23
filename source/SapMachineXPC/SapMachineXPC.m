/*
     SapMachineXPC.m
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

#import "SapMachineXPC.h"
#import "SMUDaemonProtocol.h"
#import "Constants.h"
#import <os/log.h>

@interface SapMachineXPC ()
@property (assign) AuthorizationRef authRef;
@property (atomic, strong, readwrite) NSXPCConnection *daemonConnection;
@end

@implementation SapMachineXPC

- (void)connectToDaemon
{
    if (!_daemonConnection) {
        
        _daemonConnection = [[NSXPCConnection alloc] initWithMachServiceName:kMTDaemonMachServiceName
                                                                     options:NSXPCConnectionPrivileged];
        [_daemonConnection setRemoteObjectInterface:[NSXPCInterface interfaceWithProtocol:@protocol(SMUDaemonProtocol)]];
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
        [_daemonConnection setInvalidationHandler:^{
          
            [self->_daemonConnection setInvalidationHandler:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                os_log(OS_LOG_DEFAULT, "SAPCorp: Daemon connection invalidated");
                self->_daemonConnection = nil;
            });
        }];
        
        [_daemonConnection setInterruptionHandler:^{
         
            [self->_daemonConnection setInterruptionHandler:nil];
            dispatch_async(dispatch_get_main_queue(), ^{
                os_log(OS_LOG_DEFAULT, "SAPCorp: Daemon connection interrupted");
                self->_daemonConnection = nil;
            });
        }];
#pragma clang diagnostic pop

        [_daemonConnection resume];
    }
}

- (void)connectWithDaemonEndpointReply:(void(^)(NSXPCListenerEndpoint *endpoint))reply
{
    [self connectToDaemon];
    [[_daemonConnection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        
        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to daemon: %{public}@", error);
        reply(nil);
        
    }] connectWithEndpointReply:^(NSXPCListenerEndpoint *endpoint) {
        
        reply(endpoint);
    }];
}

- (void)releaseFileFromQuarantineAtURL:(NSURL*)url recursive:(BOOL)recursive completionHandler:(void(^)(NSError *error))completionHandler
{
    NSError *error = nil;
    
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&isDirectory];
    
    if (exists) {
        if (recursive && isDirectory) {
            
            NSArray *allFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url
                                                              includingPropertiesForKeys:[NSArray arrayWithObject:NSURLNameKey]
                                                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                   error:&error
            ];
            
            if (!error) {
                
                for (NSURL *file in allFiles) {
                    [file setResourceValue:[NSNull null] forKey:NSURLQuarantinePropertiesKey error:&error];
                    if (error) { break; }
                }
            }
            
        } else {
            
            [url setResourceValue:[NSNull null] forKey:NSURLQuarantinePropertiesKey error:&error];
        }
    } else {
        
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @"The file or folder does not exist", NSLocalizedDescriptionKey,
                                         nil
        ];
        error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
    }
    
    if (completionHandler) { completionHandler(error); }
}

- (void)authenticateWithAuthorizationReply:(void (^)(NSData *authorization))reply
{
    _authRef = NULL;
    NSData *authData = nil;
    
    AuthorizationItem authItem = {kAuthorizationRuleAuthenticateAsAdmin, 0, NULL, 0};
    AuthorizationRights authRights = {1, &authItem};
    AuthorizationFlags authFlags = (kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed);

    NSString *dialogText = NSLocalizedString(@"authDialogMessage", nil);
    AuthorizationItem dialogItem = {kAuthorizationEnvironmentPrompt, strlen([dialogText UTF8String]), (char *)[dialogText UTF8String], 0};
    AuthorizationEnvironment authEnvironment = {1, &dialogItem };

    OSStatus status = AuthorizationCreate(&authRights, &authEnvironment, authFlags, &_authRef);
    
    if (status == errAuthorizationSuccess) {

        os_log(OS_LOG_DEFAULT, "SAPCorp: Authorization successful");
        
        AuthorizationExternalForm extForm;
        status = AuthorizationMakeExternalForm(_authRef, &extForm);
        
        if (status == errAuthorizationSuccess) {
            authData = [[NSData alloc] initWithBytes:&extForm length:sizeof(extForm)];
        }
        
    } else {
        
        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        os_log(OS_LOG_DEFAULT, "SAPCorp: Authorization failed: %{public}@", error);
    }

    reply(authData);
}

- (void)dealloc
{
    if (_authRef != NULL) {
        AuthorizationFree(_authRef, kAuthorizationFlagDestroyRights);
    }
}

@end
