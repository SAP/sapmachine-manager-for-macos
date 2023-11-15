/*
     AppDelegate.m
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

#import "AppDelegate.h"
#import "Constants.h"
#import <ServiceManagement/ServiceManagement.h>

@interface AppDelegate ()
@property (nonatomic, strong, readwrite) NSWindowController *mainWindowController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    NSArray *appArguments = [[NSProcessInfo processInfo] arguments];
    
    if ([appArguments containsObject:@"--register"] || [appArguments containsObject:@"--unregister"]) {
        
        BOOL shouldBeRegistered = ([appArguments containsObject:@"--register"]) ? YES : NO;
        [self registerDaemon:shouldBeRegistered completionHandler:^(BOOL success, NSError *error) {
            
            if (success) {
                printf("Daemon has been successfully %s\n", (shouldBeRegistered) ? "registered" : "unregistered");
            } else {
                fprintf(stderr, "ERROR! Failed to %s daemon\n", (shouldBeRegistered) ? "register" : "unregister");
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSApp terminate:nil];
            });
        }];
        
    } else {
        
        // register the daemon if not already registered
        [self registerDaemon:YES completionHandler:nil];

        // make sure we start with an empty temporary folder
        [self deleteTemporaryItems];
        
        NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
        _mainWindowController = [storyboard instantiateControllerWithIdentifier:@"corp.sap.SapMachineManager.MainController"];
        [_mainWindowController showWindow:nil];
        [[_mainWindowController window] makeKeyAndOrderFront:nil];
    }
}

- (void)registerDaemon:(BOOL)registerService completionHandler:(void (^) (BOOL success, NSError *error))completionHandler
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSError *error = nil;
        BOOL success = NO;
        
        SMAppService *appService = [SMAppService daemonServiceWithPlistName:kMTDaemonPlistName];
                        
        // register the service
        if (registerService) {
            
            if ([appService status] == SMAppServiceStatusNotRegistered || [appService status] == SMAppServiceStatusNotFound) {
                success = [appService registerAndReturnError:&error];
            } else {
                success = YES;
            }
            
        } else {
            success = [appService unregisterAndReturnError:&error];
        }
        
        if (completionHandler) {completionHandler(success, error); }
    });
}

- (NSError*)deleteTemporaryItems
{
    NSError *error = nil;
    NSArray *allItems = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:NSTemporaryDirectory()]
                                                      includingPropertiesForKeys:nil
                                                                         options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                                           error:&error
    ];
    
    for (NSURL *anItem in allItems) {
        
        [[NSFileManager defaultManager] removeItemAtURL:anItem
                                                  error:&error];
    }
    
    return error;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

@end
