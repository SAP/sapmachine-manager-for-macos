/*
     AppDelegate.m
     Copyright 2023-2026 SAP SE
     
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
#import "MTUpdateChecker.h"

@interface AppDelegate ()
@property (nonatomic, strong, readwrite) NSWindowController *settingsController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // make sure we start with an empty temporary folder
    [self deleteTemporaryItems];
    
    NSStoryboard *storyboard = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    _settingsController = [storyboard instantiateControllerWithIdentifier:@"corp.sap.SapMachineManager.SettingsController"];
    [_settingsController loadWindow];    
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

#pragma mark - IBActions

- (IBAction)openWebsite:(id)sender
{
    NSString *urlString = ([sender tag] == 1000) ? kMTGitHubURL : kMTSapMachineWebsiteURL;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

- (IBAction)showSettingsWindow:(id)sender
{
    [[_settingsController window] makeKeyAndOrderFront:nil];
}

- (IBAction)showLogWindow:(id)sender
{
    [[NSNotificationCenter defaultCenter] postNotificationName:kMTNotificationNameShowLog
                                                        object:nil
                                                      userInfo:nil
    ];
}

- (IBAction)checkForUpdates:(id)sender
{
    MTUpdateChecker *updateChecker = [[MTUpdateChecker alloc] initWithBundleIdentifier:kMTUpdateCheckerBundleIdentifier];
    [updateChecker launch];
}

#pragma mark - NSMenuItemValidation

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    BOOL enableItem = YES;

    if ([item tag] == 9000) {
        
        enableItem = !([[NSUserDefaults standardUserDefaults] objectIsForcedForKey:kMTDefaultsUpdateCheckDisabledKey] &&
                       [[NSUserDefaults standardUserDefaults] boolForKey:kMTDefaultsUpdateCheckDisabledKey]);
        
        // if update checking has not been disabled, we check if the Patcher app is installed
        if (enableItem) {
            
            MTUpdateChecker *updateChecker = [[MTUpdateChecker alloc] initWithBundleIdentifier:kMTUpdateCheckerBundleIdentifier];
            enableItem = [updateChecker isAvailable];
        }
        
        [item setHidden:!enableItem];
    }

    return enableItem;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app 
{
    return YES;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

@end
