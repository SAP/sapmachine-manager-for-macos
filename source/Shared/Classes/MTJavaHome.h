/*
     MTJavaHome.h
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
 @class         MTJavaHome
 @abstract      This class provides methods to get information about the Java Virtual Machines
                currently installed on the machine.
*/

@interface MTJavaHome : NSObject

/*!
 @method        installedJVMsWithCompletionHandler:
 @abstract      Returns all installed Java Virtual Machines.
 @param         completionHandler The completion handler to call when the request is complete.
 @discussion    Returns an NSArray containing a NSDictionary for each installed jvm
                or nil if an error occurred.
*/
+ (void)installedJVMsWithCompletionHandler:(void (^) (NSArray *installedJVMs))completionHandler;

/*!
 @method        installedJVMsFilteredByBundleID:
 @abstract      Returns all installed Java Virtual Machines using the given bundle identifers.
 @param         bundleID An array of bundle identifiers.
 @param         completionHandler The completion handler to call when the request is complete.
 @discussion    Returns an NSArray containing a NSDictionary for each installed jvm
                matching one of the given bundle identifiers or nil if an error occurred.
*/
+ (void)installedJVMsFilteredByBundleID:(NSArray*)bundleID completionHandler:(void (^) (NSArray *array))completionHandler;

@end
