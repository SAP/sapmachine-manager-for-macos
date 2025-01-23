/*
     MTSystemInfo.m
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

#import "MTSystemInfo.h"
#import <sys/proc_info.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <libproc.h>
#import <Collaboration/Collaboration.h>
#import "Constants.h"

@implementation MTSystemInfo : NSObject

typedef struct kinfo_proc kinfo_proc;

+ (NSArray*)processList
{
    NSMutableArray *processList = [[NSMutableArray alloc] init];
    
    int numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    pid_t pids[numberOfProcesses];
    bzero(pids, sizeof(pids));
    proc_listpids(PROC_ALL_PIDS, 0, pids, (int)sizeof(pids));
    
    for (int i = 0; i < numberOfProcesses; ++i) {
        
        if (pids[i] == 0) { continue; }
        char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
        bzero(pathBuffer, PROC_PIDPATHINFO_MAXSIZE);
        proc_pidpath(pids[i], pathBuffer, sizeof(pathBuffer));
        
        if (strlen(pathBuffer) > 0) {
            NSString *processPath = [NSString stringWithUTF8String:pathBuffer];
            [processList addObject:processPath];
        }
    }
    
    return ([processList count] > 0) ? processList : nil;
}

+ (NSString*)hardwareArchitecture
{
    NSString *returnValue = nil;
    struct utsname sysinfo;

    if (uname(&sysinfo) == EXIT_SUCCESS) {
        
        NSString *archString = [NSString stringWithUTF8String:sysinfo.machine];

        // check if we run in Rosetta
        if ([archString isEqualToString:@"x86_64"]) {
            
            int ret = 0;
            size_t size = sizeof(ret);
            
            if (sysctlbyname("sysctl.proc_translated", &ret, &size, NULL, 0) == 0) {
                if (ret == 1) { archString = @"arm64"; }
            }
        }
        
        returnValue = archString;
    }
    
    return returnValue;
}

+ (NSDate*)processStartTime
{
    NSDate *startTime = nil;
    
    size_t len = 4;
    int mib[len];
    struct kinfo_proc kp;
    
    if (sysctlnametomib("kern.proc.pid", mib, &len) == 0) {
        
        mib[3] = getpid();
        len = sizeof(kp);
        
        if (sysctl(mib, 4, &kp, &len, NULL, 0) == 0) {
            
            struct timeval processStartTime = kp.kp_proc.p_un.__p_starttime;
            startTime = [NSDate dateWithTimeIntervalSince1970:processStartTime.tv_sec + processStartTime.tv_usec / 1e6];
        }
    }
    
    return startTime;
}

+ (BOOL)isAdminUser:(NSString*)userName error:(NSError**)error
{
    BOOL isMember = NO;
    NSString *errorMsg;
    
    // get the identity for the user
    CBIdentity *userIdentity = [CBIdentity identityWithName:userName
                                                  authority:[CBIdentityAuthority defaultIdentityAuthority]];
    
    if (userIdentity) {
        
        // get the identity of the admin group
        CBGroupIdentity *groupIdentity = [CBGroupIdentity groupIdentityWithPosixGID:kMTAdminGroupID
                                                                          authority:[CBIdentityAuthority localIdentityAuthority]];
        
        if (groupIdentity) {
            
            // check if the user is currently a member of the admin group
            isMember = [userIdentity isMemberOfGroup:groupIdentity];
            
        } else {
            
            errorMsg = @"Unable to get group identity";
        }
        
    } else {
        
        errorMsg = @"Unable to get user identity";
    }
    
    if (errorMsg != nil && error != nil) {
        NSDictionary *errorDetail = [NSDictionary dictionaryWithObject:errorMsg forKey:NSLocalizedDescriptionKey];
        *error = [NSError errorWithDomain:kMTErrorDomain code:0 userInfo:errorDetail];
    }
    
    return isMember;
}

@end
