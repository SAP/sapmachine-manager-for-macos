/*
     MTSapMachineUser.m
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

#import "MTSapMachineUser.h"
#import "MTSystemInfo.h"
#import "Constants.h"
#import <pwd.h>

@interface MTSapMachineUser ()
@property (nonatomic, strong, readwrite) NSString *userName;
@end

@implementation MTSapMachineUser

- (instancetype)initWithUserName:(NSString*)userName
{
    self = [super init];
    
    if (self) {
        _userName = userName;
    }
    
    return self;
}

- (instancetype)initWithUserID:(uid_t)userID
{
    struct passwd *p = getpwuid(userID);
    NSString *userName = [NSString stringWithUTF8String:p->pw_name];
    
    if (userName) {
        
        self = [self initWithUserName:userName];
        
    } else {
        
        self = nil;
    }
    
    return self;
}

- (BOOL)isPrivileged
{
    BOOL privilegedUser = NO;
    
    NSUserDefaults *userDefaults = nil;
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    
    if (bundleIdentifier && [bundleIdentifier isEqualToString:kMTAppBundleIdentifier]) {

        userDefaults = [NSUserDefaults standardUserDefaults];
        
    } else {

        userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kMTAppBundleIdentifier];
    }
        
    if ([userDefaults objectIsForcedForKey:kMTDefaultsDontRequireAdmin] &&
        [userDefaults boolForKey:kMTDefaultsDontRequireAdmin]) {

        privilegedUser = YES;
        
    } else {

        privilegedUser = [MTSystemInfo isAdminUser:_userName error:nil];
    }

    return privilegedUser;
}

@end
