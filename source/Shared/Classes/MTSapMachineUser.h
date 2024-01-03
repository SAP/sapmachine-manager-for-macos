/*
     MTSapMachineUser.h
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
 @class         MTSapMachineUser
 @abstract      This class provides a method to determine if a user is allowed
                to run privileged tasks within SapMachine manager.
*/

@interface MTSapMachineUser : NSObject

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithUserName: or
                initWithUserID: instead.
*/
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithUserName:
 @abstract      Initialize a MTSapMachineUser object with a given user name.
 @param         userName The name of the user.
*/
- (instancetype)initWithUserName:(NSString*)userName NS_DESIGNATED_INITIALIZER;

/*!
 @method        initWithUserID:
 @abstract      Initialize a MTSapMachineUser object with a given user id.
 @param         userID The numeric user id of the user.
*/
- (instancetype)initWithUserID:(uid_t)userID;

/*!
 @property      userName
 @abstract      A read-only property that returns the user name of the receiver.
 @discussion    The value of this property is string.
*/
@property (nonatomic, strong, readonly) NSString *userName;

/*!
 @method        isPrivileged
 @abstract      Determine if the user is allowed to run privileged tasks.
 @discussion    Returns YES if the user is either and admin user or the user is a
                standard user but provided admin credentials or if the user is a
                standard user and standard users are allowed to run privileged
                tasks (via configuration profile). Otherwise returns NO.
*/
- (BOOL)isPrivileged;

@end
