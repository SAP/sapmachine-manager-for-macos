/*
     SMUDaemonProtocol.h
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
#import <OSLog/OSLog.h>
#import "MTSapMachine.h"

/*!
 @protocol      SMUDaemonProtocol
 @abstract      Defines the protocol implemented by the daemon and
                called by the xpc service and SapMachine Manager.
*/

@protocol SMUDaemonProtocol

/*!
 @method        connectWithEndpointReply:
 @abstract      Returns an endpoint that's connected to the daemon.
 @param         reply The reply block to call when the request is complete.
 @discussion    This method is only called by the xpc service.
*/
- (void)connectWithEndpointReply:(void (^)(NSXPCListenerEndpoint* endpoint))reply;

/*!
 @method        availableAssetsWithReply:
 @abstract      Returns an array containing all available assets.
 @param         reply The reply block to call when the request is complete.
 @discussion    Returns a NSArray of MTSapMachine objects. Each element of the array represents
                a SapMachine release from the SapMachine release data. An empty array is returned
                if there are no release data available and no SapMachine assets are installed. The array
                may be nil if an error occurred.
*/
- (void)availableAssetsWithReply:(void (^)(NSArray<MTSapMachineAsset*> *availableAssets))reply;

/*!
 @method        updateAllAssetsWithCompletionHandler:
 @abstract      Updates all installed SapMachine releases to the latest version.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if all updates have been successfully applied, otherwise returns NO.
*/
- (void)updateAllAssetsWithCompletionHandler:(void (^)(BOOL success))completionHandler;

/*!
 @method        downloadAssets:install:authorization:completionHandler:
 @abstract      Downloads and optionally installs the given assets.
 @param         assets An array of MTSapMachineAsset objects.
 @param         install A boolean indicating wheter or not to install the assets after downloading.
 @param         authData The authorization data. May be nil.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if all assets have been downloaded (and installed) successfully,
                otherwise returns NO. If an error occurred the NSError object might provide
                information about the error that caused the operation to fail.
*/
- (void)downloadAssets:(NSArray<MTSapMachineAsset*>*)assets 
               install:(BOOL)install
         authorization:(NSData *)authData
     completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;

/*!
 @method        deleteAssets:authorization:completionHandler:
 @abstract      Deletes the given assets.
 @param         assets An array of MTSapMachineAsset objects.
 @param         authData The authorization data. May be nil.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns an array of successfully deleted MTSapMachineAsset objects. If an
                error occurred the NSError object might provide information about the error
                that caused the operation to fail.
*/
- (void)deleteAssets:(NSArray<MTSapMachineAsset*>*)assets 
       authorization:(NSData*)authData
   completionHandler:(void (^)(NSArray<MTSapMachineAsset*> *deletedAssets, NSError *error))completionHandler;

/*!
 @method        setAutomaticUpdatesEnabled:completionHandler:
 @abstract      Enables or disables automatic updates.
 @param         enabled A boolean specifying if automatic updates should be enabled or disabled.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if automatic updates have been successfully set to the given value,
                otherwise returns NO.
*/
- (void)setAutomaticUpdatesEnabled:(BOOL)enabled completionHandler:(void (^)(BOOL success))completionHandler;

/*!
 @method        automaticUpdatesEnabledWithReply:
 @abstract      Returns the current status of automatic updates.
 @param         reply The reply block to call when the request is complete.
 @discussion    Returns YES if automatic updates are enabled, otherwise returns NO.  The second argument is set to YES, if the
                setting is managed (via configuration profile), otherwise returns NO.
*/
- (void)automaticUpdatesEnabledWithReply:(void (^)(BOOL enabled, BOOL forced))reply;

/*!
 @method        logEntriesSinceDate:completionHandler:
 @abstract      Returns the log entries beginning from the given date.
 @param         date An NSDate object specifying the beginning of the log entries.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns an array containing the log entries for SapMachine Manager and
                its components from the given date until now.
*/
- (void)logEntriesSinceDate:(NSDate*)date completionHandler:(void (^)(NSArray<OSLogEntry*> *entries))completionHandler;

/*!
 @method        setJavaHomeEnvironmentVariableUsingAsset:userOnly:authorization:completionHandler:
 @abstract      Set the @c JAVA_HOME environment variable.
 @param         userOnly If set to YES, the environment variable is only set for the current user, otherwise it is set system-wide.
 @param         authData The authorization data. May be nil.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns YES if on success, otherwise returns NO. If an error occurred
                the NSError object might provide information about the error that caused
                the operation to fail.
*/
- (void)setJavaHomeEnvironmentVariableUsingAsset:(MTSapMachineAsset*)asset 
                                        userOnly:(BOOL)userOnly
                                   authorization:(NSData *)authData
                               completionHandler:(void (^)(BOOL success, NSError *error))completionHandler;

/*!
 @method        unsetJavaHomeEnvironmentVariableForUserOnly:authorization:completionHandler:
 @abstract      Unset the @c JAVA_HOME environment variable.
 @param         userOnly If set to YES, the environment variable is only unset for the current user, otherwise it is unset system-wide.
 @param         authData The authorization data. May be nil.
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns an NSArray containing the paths to the files that have been changed.
                If an error occurred the NSError object might provide information about the error
                that caused the operation to fail.
*/
- (void)unsetJavaHomeEnvironmentVariableForUserOnly:(BOOL)userOnly
                                      authorization:(NSData *)authData
                                  completionHandler:(void (^)(NSArray *changedFiles, NSError *error))completionHandler;

@end
