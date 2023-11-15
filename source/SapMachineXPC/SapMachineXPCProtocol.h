/*
     SapMachineXPCProtocol.h
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

#import <Foundation/Foundation.h>

/*!
 @protocol      SapMachineXPCProtocol
 @abstract      Defines the protocol implemented by the xpc service and
                called by SapMachine Manager.
*/

@protocol SapMachineXPCProtocol

/*!
 @method        connectWithDaemonEndpointReply:
 @abstract      Returns an endpoint that's connected to the daemon.
 @param         reply The reply block to call when the request is complete.
*/
- (void)connectWithDaemonEndpointReply:(void(^)(NSXPCListenerEndpoint *endpoint))reply;

/*!
 @method        releaseFileFromQuarantineAtURL:recursive:completionHandler:
 @abstract      Releases the file at the given url from quarantine.
 @param         url An url that points to a file or folder.
 @param         recursive If set to NO, only the file or folder at the given url will be
                released from quarantive. If set to YES and the given url points to a folder,
                the folder and all items in the folder are recursively removed from quarantine .
 @param         completionHandler The handler to call when the request is complete.
 @discussion    Returns nil if the operation succeeded. In case of an error the error object might
                contain information about the error that caused the operation to fail.
*/
- (void)releaseFileFromQuarantineAtURL:(NSURL*)url recursive:(BOOL)recursive completionHandler:(void(^)(NSError *error))completionHandler;

/*!
 @method        authenticateWithAuthorizationReply::
 @abstract      Authenticates the user.
 @param         reply The reply block to call when the request is complete.
 @discussion    Returns the xpc service's authorization reference so the app can pass that to the
                requests it sends to the daemon.
*/
- (void)authenticateWithAuthorizationReply:(void (^)(NSData *authorization))reply;

@end
