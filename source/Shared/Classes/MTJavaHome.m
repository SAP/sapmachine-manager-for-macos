/*
     MTJavaHome.m
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

#import "MTJavaHome.h"
#import "Constants.h"

@implementation MTJavaHome

+ (void)installedJVMsWithCompletionHandler:(void (^) (NSArray *installedJVMs))completionHandler
{
    __block NSArray *returnData = nil;
    
    if (completionHandler) {
        
        NSTask *checkTask = [[NSTask alloc] init];
        [checkTask setExecutableURL:[NSURL fileURLWithPath:kMTJavaHomePath]];
        [checkTask setArguments:[NSArray arrayWithObject:@"-X"]];
        NSPipe *stdoutPipe = [[NSPipe alloc] init];
        [checkTask setStandardOutput:stdoutPipe];
        [checkTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
        [checkTask setTerminationHandler:^(NSTask* task){
            
            NSData *consoleData = [[stdoutPipe fileHandleForReading] readDataToEndOfFile];
            
            if (consoleData) {
                returnData = [NSPropertyListSerialization
                              propertyListWithData:consoleData
                              options:NSPropertyListImmutable
                              format:nil
                              error:nil
                ];
            }

            completionHandler(returnData);
        }];
        
        [checkTask launch];
    }
}

+ (void)installedJVMsFilteredByBundleID:(NSArray*)bundleID completionHandler:(void (^) (NSArray *array))completionHandler
{
    if (completionHandler) {
        
        [self installedJVMsWithCompletionHandler:^(NSArray *array) {

            if ([array count] > 0 && [bundleID count] > 0) {
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"JVMBundleID in %@", bundleID];
                array = [array filteredArrayUsingPredicate:predicate];
            }
            
            completionHandler(array);
        }];
    }
}

@end
