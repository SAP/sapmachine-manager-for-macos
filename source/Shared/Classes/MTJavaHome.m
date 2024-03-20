/*
     MTJavaHome.m
     Copyright 2023-2024 SAP SE
     
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
    if (completionHandler) {
        
        NSTask *checkTask = [[NSTask alloc] init];
        [checkTask setExecutableURL:[NSURL fileURLWithPath:kMTJavaHomePath]];
        [checkTask setArguments:[NSArray arrayWithObject:@"-X"]];
        NSPipe *stdoutPipe = [[NSPipe alloc] init];
        [checkTask setStandardOutput:stdoutPipe];
        [checkTask setStandardError:[NSFileHandle fileHandleWithNullDevice]];
        [checkTask setTerminationHandler:^(NSTask* task){
            
            NSArray *returnData = nil;
            NSData *consoleData = [[stdoutPipe fileHandleForReading] readDataToEndOfFile];
            
            if ([consoleData length] > 0) {
                
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

+ (NSDictionary*)configFilesWithUserName:(NSString*)userName userOnly:(BOOL)userOnly recommendedOnly:(BOOL)recommendedOnly
{
    NSMutableArray *userConfigFiles = [[NSMutableArray alloc] init];
    NSMutableArray *systemConfigFiles = [[NSMutableArray alloc] init];
    NSDictionary *javaHomeConfigFiles = [[NSDictionary alloc] init];
    
    if ([userName length] > 0) {
        
        NSDictionary *supportedShells = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SupportedShells" ofType:@"plist"]];
        NSURL *userHome = [[NSFileManager defaultManager] homeDirectoryForUser:userName];
        
        for (NSString *shellPath in [supportedShells allKeys]) {
            
            if (userHome) {
                
                NSArray *userFiles = [supportedShells valueForKeyPath:[NSString stringWithFormat:@"%@.user", shellPath]];
                
                if (recommendedOnly) {
                    
                    if ([userFiles count] > 0) { [userConfigFiles addObject:[[userHome path] stringByAppendingPathComponent:[userFiles firstObject]]]; }
                    
                } else {
                    
                    for (NSString *userFile in userFiles) {
                        [userConfigFiles addObject:[[userHome path] stringByAppendingPathComponent:userFile]];
                    }
                }
            }
            
            if (!userOnly) {
                
                NSArray *systemFiles = [supportedShells valueForKeyPath:[NSString stringWithFormat:@"%@.system", shellPath]];
                
                if ([systemFiles count] > 0) {
                    
                    if (recommendedOnly) {
                        
                        [systemConfigFiles addObject:[systemFiles firstObject]];
                        
                    } else {
                        
                        [systemConfigFiles addObjectsFromArray:systemFiles];
                    }
                }
            }
        }

        javaHomeConfigFiles = [NSDictionary dictionaryWithObjectsAndKeys:
                               userConfigFiles, @"user",
                               systemConfigFiles, @"system",
                               nil
        ];
    }
    
    return javaHomeConfigFiles;
}

+ (NSString*)environmentVariableAtPath:(NSString*)path
{
    NSError *error = nil;
    NSString *javaHomePath = nil;
    
    if (path && [[NSFileManager defaultManager] isReadableFileAtPath:path]) {
        
        NSString *originalString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
        
        if (!error) {
            
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\s*export\\s+JAVA_HOME=(.*)$"
                                                                                   options:(NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines)
                                                                                     error:nil
            ];
            
            NSTextCheckingResult *result = [regex firstMatchInString:originalString options:kNilOptions range:NSMakeRange(0, [originalString length])];
            
            if ([result rangeAtIndex:1].location != NSNotFound) {
                
                javaHomePath = [originalString substringWithRange:[result rangeAtIndex:1]];
                javaHomePath = [javaHomePath stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                if ([javaHomePath length] == 0) { javaHomePath = nil; }
            }
        }
    }
    
    return javaHomePath;
}

+ (void)setEnvironmentVariableAtPaths:(NSArray*)paths usingJVMPath:(NSString*)jvmPath completionHandler:(void (^) (BOOL success))completionHandler
{
    BOOL overallSuccess = YES;
    NSError *error = nil;
    
    if ([paths count] > 0 && [[NSFileManager defaultManager] fileExistsAtPath:jvmPath]) {
        
        NSString *exportString = [NSString stringWithFormat:@"\nexport JAVA_HOME=%@\n", jvmPath];
        
        for (NSString *path in paths) {
            
            BOOL success = NO;

            // create the file if it doesn't exist
            if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {

                NSDictionary *attributesDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSNumber numberWithShort:0444], NSFilePosixPermissions,
                                                @"root", NSFileOwnerAccountName,
                                                @"wheel", NSFileGroupOwnerAccountName,
                                                nil
                ];
                
                NSURL *usersFolderURL = [[NSFileManager defaultManager] URLForDirectory:NSUserDirectory
                                                                               inDomain:NSLocalDomainMask
                                                                      appropriateForURL:nil
                                                                                 create:NO
                                                                                  error:&error
                                         ];
                                         
                if (!error && usersFolderURL && [path hasPrefix:[usersFolderURL path]]) {
                    
                    NSDictionary *parentAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[path stringByDeletingLastPathComponent] error:&error];
                    
                    if (!error) {
                        
                        attributesDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                          [NSNumber numberWithShort:0600], NSFilePosixPermissions,
                                          [parentAttributes valueForKey:NSFileOwnerAccountName], NSFileOwnerAccountName,
                                          [parentAttributes valueForKey:NSFileGroupOwnerAccountName], NSFileGroupOwnerAccountName,
                                          nil
                        ];
                    }
                }
                
                success = [[NSFileManager defaultManager] createFileAtPath:path
                                                                  contents:[exportString dataUsingEncoding:NSUTF8StringEncoding]
                                                                attributes:attributesDict
                ];
                                
            } else {
                                
                // change an existing file
                if ([[NSFileManager defaultManager] isWritableFileAtPath:path]) {
                    
                    NSString *originalString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
                    
                    if (!error) {
                        
                        NSString *newString = nil;
                        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[\r\n]*\\s*export\\s+JAVA_HOME=.*[\r\n]*"
                                                                                               options:(NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines)
                                                                                                 error:nil
                        ];
                        
                        if ([regex numberOfMatchesInString:originalString options:kNilOptions range:NSMakeRange(0, [originalString length])] > 0) {
                            
                            newString = [regex stringByReplacingMatchesInString:originalString options:0 range:NSMakeRange(0, [originalString length]) withTemplate:exportString];
                            
                        } else {
                            
                            newString = [originalString stringByAppendingString:exportString];
                        }
                            
                        NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
                        
                        if (fileHandle) {

                            NSData *data = [newString dataUsingEncoding:NSUTF8StringEncoding];
                            [fileHandle seekToFileOffset:0];
                            [fileHandle writeData:data];
                            [fileHandle truncateFileAtOffset:[data length]];
                            [fileHandle closeFile];
                            success = YES;
                        }
                    }
                }
            }

            if (!success) { overallSuccess = NO; }
        }
        
    } else {
        
        overallSuccess = NO;
    }

    if (completionHandler) { completionHandler(overallSuccess); }
}

+ (void)unsetEnvironmentVariableAtPaths:(NSArray*)paths completionHandler:(void (^) (NSArray *changedFiles))completionHandler
{
    NSMutableArray *changedFiles = [[NSMutableArray alloc] init];
    
    for (NSString *path in paths) {

        if ([[NSFileManager defaultManager] isWritableFileAtPath:path]) {

            NSError *error = nil;
            NSString *originalString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
            
            if (!error) {

                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[\r\n]*\\s*export\\s+JAVA_HOME=.*[\r\n]*"
                                                                                       options:(NSRegularExpressionCaseInsensitive | NSRegularExpressionAnchorsMatchLines)
                                                                                         error:nil
                ];
                if ([regex numberOfMatchesInString:originalString options:kNilOptions range:NSMakeRange(0, [originalString length])] > 0) {
                    
                    NSString *newString = [regex stringByReplacingMatchesInString:originalString options:0 range:NSMakeRange(0, [originalString length]) withTemplate:@""];
                    
                    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:path];
                    
                    if (fileHandle) {
                        
                        NSData *data = [newString dataUsingEncoding:NSUTF8StringEncoding];
                        [fileHandle seekToFileOffset:0];
                        [fileHandle writeData:data];
                        [fileHandle truncateFileAtOffset:[data length]];
                        [fileHandle closeFile];
                        
                        [changedFiles addObject:path];
                    }
                }
            }
        }
    }
    
    if (completionHandler) { completionHandler(changedFiles); }
}

@end
