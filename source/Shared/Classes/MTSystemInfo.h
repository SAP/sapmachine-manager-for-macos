/*
     MTSystemInfo.h
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
 @class         MTSystemInfo
 @abstract      This class provides methods to get some system information.
*/

@interface MTSystemInfo : NSObject

/*!
 @method        processList
 @abstract      Returns a list of all running processes.
 @discussion    Returns an array containing the complete paths to all running processes
                or nil, if an error occurred.
*/
+ (NSArray*)processList;

/*!
 @method        hardwareArchitecture
 @abstract      Returns the current architecture.
 @discussion    Returns @c x86_64 on Macs mit Intel processor and @c arm64 on Macs with
                Apple Silicon. If this method is used under Rosetta, it returns the actual architecture.
*/
+ (NSString*)hardwareArchitecture;

/*!
 @method        processStartTime
 @abstract      Returns the time the current process has been started.
*/
+ (NSDate*)processStartTime;

/*!
 @method        isAdminUser:error:
 @abstract      Returns if the given user is an admin user or not.
 @param         userName The name of the user.
 @param         error A reference to an NSError object to store error information.
 @discussion    Returns YES if the user is an admin user, otherwise returns NO. If an error occurred
                the NSError object might provide information about the error that caused the operation to fail.
*/
+ (BOOL)isAdminUser:(NSString*)userName error:(NSError**)error;

@end
