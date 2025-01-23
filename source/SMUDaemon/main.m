/*
     main.m
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

#import <Cocoa/Cocoa.h>
#import "SMUDaemon.h"
#import "SMUDaemonProtocol.h"
#import "Constants.h"
#import <os/log.h>

@interface Main : NSObject
@property (nonatomic, strong, readwrite) SMUDaemon *smuDaemon;
@end

@implementation Main

- (void)run
{
    os_log(OS_LOG_DEFAULT, "SAPCorp: Starting");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [self->_smuDaemon automaticUpdatesEnabledWithReply:^(BOOL enabled, BOOL forced) {
            
            if (enabled && ![self->_smuDaemon operationInProgress]) {
                
                // we don't start automatic updates if the SapMachine Manager is running
                if ([self->_smuDaemon numberOfActiveXPCConnections] > 0) {
                    
                    os_log(OS_LOG_DEFAULT, "SAPCorp: Deferring automatic update checks while SapMachine Manager is running");
                    [self->_smuDaemon setShouldTerminate:YES];
                    
                } else {
                    
                    os_log(OS_LOG_DEFAULT, "SAPCorp: Checking for SapMachine updates");
                    [self->_smuDaemon setUpdateDelegate:nil];
                    [self->_smuDaemon updateAllAssetsWithCompletionHandler:^(BOOL success) {
                        
                        os_log(OS_LOG_DEFAULT, "SAPCorp: Update check complete");
                        [self->_smuDaemon setShouldTerminate:YES];
                    }];
                }
                
            } else {
                
                [self->_smuDaemon setShouldTerminate:YES];
            }
        }];
    });
            
    while (![_smuDaemon shouldTerminate] || [_smuDaemon operationInProgress] || [_smuDaemon numberOfActiveXPCConnections] > 0) { [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:60]]; }
    
    [_smuDaemon invalidateXPC];
    os_log(OS_LOG_DEFAULT, "SAPCorp: Exiting");
}

@end

int main(int argc, const char * argv[])
{
#pragma unused(argc)
#pragma unused(argv)

    Main *m = [[Main alloc] init];
    m.smuDaemon = [[SMUDaemon alloc] init];
        
    [m run];
            
    return EXIT_SUCCESS;
}
