/*
     MTMainViewController.m
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

#import "MTMainViewController.h"
#import "Constants.h"
#import "MTSapMachineUser.h"
#import "MTPackageIntroController.h"
#import "MTInstallIntroController.h"
#import "MTInstallController.h"
#import <ServiceManagement/SMAppService.h>

@interface MTMainViewController ()
@property (nonatomic, strong, readwrite) MTDaemonConnection *daemonConnection;
@property (nonatomic, strong, readwrite) NSWindowController *logController;
@property (nonatomic, strong, readwrite) NSMutableArray *jvmReleases;
@property (nonatomic, strong, readwrite) NSArray *assetsToDeleted;
@property (nonatomic, strong, readwrite) NSUserDefaults *userDefaults;
@property (atomic, copy, readwrite) NSData *authData;
@property (assign) BOOL updateCheckInProgress;
@property (assign) BOOL installInProgress;
@property (assign) BOOL skipRecommendedInstall;
@property (assign) BOOL upgradeCheckDone;
@property (assign) NSInteger updatesAvailable;
@property (assign) NSInteger updatesFailed;

@property (weak) IBOutlet NSArrayController *releasesController;
@property (weak) IBOutlet NSTableView *tableView;
@end

@implementation MTMainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    _userDefaults = [NSUserDefaults standardUserDefaults];
            
    _daemonConnection = [[MTDaemonConnection alloc] init];
    [_daemonConnection setDelegate:self];
    
    self.updatesAvailable = 0;
    self.updatesFailed = 0;
    self.jvmReleases = [[NSMutableArray alloc] init];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self checkForLoginItem];
    });
}

- (void)checkForLoginItem
{
    SMAppService *launchdService = [SMAppService daemonServiceWithPlistName:kMTDaemonPlistName];
    
    if ([launchdService status] == SMAppServiceStatusRequiresApproval) {
                
        // the user disabled the login item
        NSAlert *theAlert = [[NSAlert alloc] init];
        [theAlert setMessageText:NSLocalizedString(@"dialogLoginItemDisabledTitle", nil)];
        [theAlert setInformativeText:NSLocalizedString(@"dialogLoginItemDisabledMessage", nil)];
        [theAlert addButtonWithTitle:NSLocalizedString(@"tryAgainButton", nil)];
        [theAlert addButtonWithTitle:NSLocalizedString(@"openSettingsButton", nil)];
        [theAlert addButtonWithTitle:NSLocalizedString(@"quitButton", nil)];
        [theAlert setAlertStyle:NSAlertStyleCritical];
        [theAlert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
               
               if (returnCode == NSAlertFirstButtonReturn) {
                   
                   // retry
                   dispatch_async(dispatch_get_main_queue(), ^{
                       [self checkForLoginItem];
                   });
                   
               } else if (returnCode == NSAlertSecondButtonReturn) {
                       
                   dispatch_async(dispatch_get_main_queue(), ^{
                       [SMAppService openSystemSettingsLoginItems];
                       [self checkForLoginItem];
                   });
                   
               } else {
                   
                   [NSApp terminate:self];
               }
       }];
        
    } else {
        
        // register for notifications to show the log window
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(showLog)
                                                     name:kMTNotificationNameShowLog
                                                   object:nil
        ];
        
        // we check for updates at launch
        [self checkForUpdates];
    }
}

#pragma mark SMUDaemon methods

- (void)checkForUpdates
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // clear the array controller
        [self.releasesController removeObjects:self->_jvmReleases];
        
        self.updatesAvailable = 0;
        self.updateCheckInProgress = YES;
    });
    
    [_daemonConnection connectToDaemonWithExportedObject:self
                                  andExecuteCommandBlock:^{
        
        [[self->_daemonConnection remoteObjectProxy] availableAssetsWithReply:^(NSArray<MTSapMachineAsset *> *availableAssets) {

            dispatch_async(dispatch_get_main_queue(), ^{

                if ([availableAssets count] > 0) {
                    
                    self.updateCheckInProgress = NO;
                    
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"installURL != nil"];
                    [self.releasesController addObjects:availableAssets];
                    [self.releasesController setFilterPredicate:predicate];
                    
                    self.updatesAvailable = [self numberOfAvailableUpdates];
                    self.installInProgress = [self updateInProgress];
                    
                    if (![self->_userDefaults boolForKey:kMTDefaultsNoUpgradeAlertsKey] && !self.installInProgress && !self.upgradeCheckDone) {
                        
                        self.upgradeCheckDone = YES;
                        
                        // get all installed lts releases
                        predicate = [NSPredicate predicateWithFormat:@"installURL != nil AND isLTS == %@ AND isEA == %@", [NSNumber numberWithBool:YES], [NSNumber numberWithBool:NO]];
                        NSArray *installedLTS = [availableAssets filteredArrayUsingPredicate:predicate];
                        
                        if ([installedLTS count] > 0) {
                            
                            // get the highest major version of the installed lts releases
                            NSInteger highestInstalledLTS = [[installedLTS valueForKeyPath:@"@max.currentVersion.majorVersion"] integerValue];
                            
                            // get the major version of the latest available lts release
                            predicate = [NSPredicate predicateWithFormat:@"isLTS == %@ AND isEA == %@", [NSNumber numberWithBool:YES], [NSNumber numberWithBool:NO]];
                            NSArray *availableLTS = [availableAssets filteredArrayUsingPredicate:predicate];
                            NSInteger highestAvailableLTS = [[availableLTS valueForKeyPath:@"@max.currentVersion.majorVersion"] integerValue];
                            
                            // is the latest major lts release is not installed
                            // we inform the user about the updated version
                            if (highestAvailableLTS > highestInstalledLTS) {
                                
                                NSAlert *theAlert = [[NSAlert alloc] init];
                                [theAlert setMessageText:[NSString localizedStringWithFormat:NSLocalizedString(@"dialogLTSUpgradeTitle", nil), highestAvailableLTS]];
                                
                                if ([installedLTS count] == 1) {
                                    [theAlert setInformativeText:NSLocalizedString(@"dialogLTSUpgradeOneMessage", nil)];
                                    [[theAlert suppressionButton] setTitle:NSLocalizedString(@"dialogLTSUpgradeDeleteOne", nil)];
                                } else {
                                    [theAlert setInformativeText:NSLocalizedString(@"dialogLTSUpgradeMultipleMessage", nil)];
                                    [[theAlert suppressionButton] setTitle:NSLocalizedString(@"dialogLTSUpgradeDeleteMultiple", nil)];
                                }
                                
                                [theAlert addButtonWithTitle:NSLocalizedString(@"upgradeButton", nil)];
                                [theAlert addButtonWithTitle:NSLocalizedString(@"cancelButton", nil)];
                                
                                [[theAlert suppressionButton] setState:([self->_userDefaults boolForKey:kMTDefaultsNoUpgradeDeleteKey]) ? NSControlStateValueOff : NSControlStateValueOn];
                                [theAlert setShowsSuppressionButton:YES];
                                
                                [theAlert setAlertStyle:NSAlertStyleInformational];
                                [theAlert beginSheetModalForWindow:[[self view] window]
                                                 completionHandler:^(NSModalResponse returnCode) {
                                    
                                    [self->_userDefaults setBool:([[theAlert suppressionButton] state] == NSControlStateValueOn) ? NO : YES
                                                          forKey:kMTDefaultsNoUpgradeDeleteKey];
                                    
                                    if (returnCode == NSAlertFirstButtonReturn) {
                                        
                                        // get the types of the installed lts releases. if they are all of
                                        // type jre, we install the jre of the new version, otherwise we
                                        // we install the jdk.
                                        MTSapMachineJVMType type = MTSapMachineJVMTypeJDK;
                                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"jvmType == %ld", MTSapMachineJVMTypeJRE];
                                        if ([[installedLTS filteredArrayUsingPredicate:predicate] count] == [installedLTS count]) {
                                            type = MTSapMachineJVMTypeJRE;
                                        }
                                        
                                        // get the asset to upgrade to
                                        predicate = [NSPredicate predicateWithFormat:@"currentVersion.majorVersion == %ld AND jvmType == %ld", highestAvailableLTS, type];
                                        NSArray *highestLTS = [availableLTS filteredArrayUsingPredicate:predicate];
                                        
                                        // if we got more than one asset back,
                                        // there is something wrong
                                        if ([highestLTS count] == 1) {
                                            
                                            if ([self->_userDefaults boolForKey:kMTDefaultsNoUpgradeDeleteKey]) {
                                                self->_assetsToDeleted = nil;
                                            } else {
                                                self->_assetsToDeleted = [NSArray arrayWithArray:installedLTS];
                                            }
                                            
                                            dispatch_async(dispatch_get_main_queue(), ^{
                                                MTSapMachineAsset *upgradeAsset = (MTSapMachineAsset*)[highestLTS firstObject];
                                                [self installSapMachine:upgradeAsset];
                                            });
                                        }
                                    }
                                }];
                            }
                        }
                    }
                }
                
                if ([[self.releasesController arrangedObjects] count] == 0) {
                    
                    NSArray *ltsJDKs = nil;
                    NSAlert *theAlert = [[NSAlert alloc] init];

                    if ([availableAssets count] > 0) {
                        
                        [theAlert setMessageText:NSLocalizedString(@"dialogNoAssetsTitle", nil)];
                        [theAlert setInformativeText:NSLocalizedString(@"dialogNoAssetsMessage", nil)];
                        [theAlert addButtonWithTitle:NSLocalizedString(@"installButton", nil)];
                        
                        // get the JDK of the latest LTS release…
                        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"jvmType == %ld AND isLTS == %@ AND isEA == %@", MTSapMachineJVMTypeJDK, [NSNumber numberWithBool:YES], [NSNumber numberWithBool:NO]];
                        ltsJDKs = [self->_jvmReleases filteredArrayUsingPredicate:predicate];
                        
                        // if we got at least one release, we display a checkbox allowing
                        // the user to install the recommended version of SapMachine
                        if ([ltsJDKs count] > 0) {
                            
                            self->_skipRecommendedInstall = NO;

                            [theAlert setShowsSuppressionButton:YES];
                            [[theAlert suppressionButton] setTitle:NSLocalizedString(@"dialogNoAssetsCheckbox", nil)];
                            [[theAlert suppressionButton] setState:NSControlStateValueOn];
                        }
                        
                    } else {
                        
                        [theAlert setMessageText:NSLocalizedString(@"dialogNoAssetsNoAvailableTitle", nil)];
                        [theAlert setInformativeText:NSLocalizedString(@"dialogNoAssetsNoAvailableMessage", nil)];
                    }
                    
                    [theAlert addButtonWithTitle:NSLocalizedString(@"quitButton", nil)];
                    [theAlert setAlertStyle:NSAlertStyleInformational];
                    [theAlert beginSheetModalForWindow:[[self view] window]
                                     completionHandler:^(NSModalResponse returnCode) {

                        if (returnCode == NSAlertFirstButtonReturn && [availableAssets count] > 0) {
                            
                            dispatch_async(dispatch_get_main_queue(), ^{

                                if ([[theAlert suppressionButton] state] == NSControlStateValueOn) {

                                    // sort the returned assets by version number and get the highest one
                                    NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"currentVersion.majorVersion"
                                                                                                                      ascending:NO
                                                                                        ]
                                    ];
                                    NSArray *sortedAssets = [ltsJDKs sortedArrayUsingDescriptors:sortDescriptors];
                                    MTSapMachineAsset *toBeInstalled = [sortedAssets firstObject];
                                    
                                    [self installSapMachine:toBeInstalled];
                                    
                                } else {
                                    
                                    self->_skipRecommendedInstall = YES;
                                    [self installSapMachine:nil];
                                }
                            });
                            
                        } else {
                            
                            [NSApp terminate:self];
                        }
                    }];
                }
            });
        }];
    }];
}

- (void)installUpdates
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.installInProgress = YES;
        self.updatesFailed = 0;
    });
    
    [_daemonConnection connectToDaemonWithExportedObject:self
                                  andExecuteCommandBlock:^{

        // wo don't use the completion handler here but the delegate methods
        // instead. this allows to quit the app during the update process.
        [[self->_daemonConnection remoteObjectProxy] updateAllAssetsWithCompletionHandler:^(BOOL success) {}];
    }];
}

- (void)deleteAssetsPermanently:(NSArray<MTSapMachineAsset*>*)assets 
           allowUserInteraction:(BOOL)interaction
              completionHandler:(void (^)(NSError *error))completionHandler
{
    [self authenticateUserWithCompletionHandler:^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self->_daemonConnection connectToDaemonWithExportedObject:nil
                                                andExecuteCommandBlock:^{
                
                [[self->_daemonConnection remoteObjectProxy] deleteAssets:assets
                                                            authorization:self->_authData
                                                        completionHandler:^(NSArray<MTSapMachineAsset *> *deletedAssets, NSError *error) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        
                        self->_authData = nil;
                        
                        if (error) {
                            
                            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to delete asset: %{public}@", error);
                            
                            if (interaction) {
                                
                                NSAlert *theAlert = [[NSAlert alloc] init];
                                
                                if ([assets count] > 1) {
                                    
                                    [theAlert setMessageText:NSLocalizedString(@"dialogDeletionMultipleFailedTitle", nil)];
                                    [theAlert setInformativeText:NSLocalizedString(@"dialogDeletionMultipleFailedMessage", nil)];
                                    
                                } else {
                                    
                                    [theAlert setMessageText:NSLocalizedString(@"dialogDeletionOneFailedTitle", nil)];
                                    [theAlert setInformativeText:NSLocalizedString(@"dialogDeletionOneFailedMessage", nil)];
                                }
                                
                                [theAlert addButtonWithTitle:NSLocalizedString(@"okButton", nil)];
                                [theAlert addButtonWithTitle:NSLocalizedString(@"showLogButton", nil)];
                                [theAlert setAlertStyle:NSAlertStyleWarning];
                                [theAlert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
                                    
                                    if (returnCode == NSAlertSecondButtonReturn) {
                                        
                                        // show log window
                                        [self showLog];
                                    }
                                }];
                            }
                            
                        } else {
                            
                            // remove the deleted assets from our array
                            // controller and set their install url to nil
                            [self willChangeValueForKey:@"jvmReleases"];
                            
                            for (MTSapMachineAsset *deletedAsset in deletedAssets) {
                                
                                MTSapMachineAsset *asset = [self matchingAssetForAsset:deletedAsset];
                                if (asset) { [asset setInstallURL:nil]; }
                            }
                            
                            [self didChangeValueForKey:@"jvmReleases"];
                            
                            if ([[self.releasesController arrangedObjects] count] == 0) {
                                
                                [self checkForUpdates];
                                
                            } else {
                                
                                self.updatesAvailable = [self numberOfAvailableUpdates];
                            }
                        }
                        
                        if (completionHandler) { completionHandler(error); }
                    });
                    
                }];
            }];
        });
    }];
}

#pragma mark MTSapMachineAssetUpdateDelegate

- (void)updateStartedForAsset:(MTSapMachineAsset*)asset
{
    MTSapMachineAsset *matchingAsset = [self matchingAssetForAsset:asset];
    
    if (matchingAsset) {

        dispatch_async(dispatch_get_main_queue(), ^{
            [self willChangeValueForKey:@"jvmReleases"];

            [matchingAsset setIsUpdating:YES];
            
            [self didChangeValueForKey:@"jvmReleases"];
        });
    }
}

- (void)updateFinishedForAsset:(MTSapMachineAsset*)asset
{
    MTSapMachineAsset *matchingAsset = [self matchingAssetForAsset:asset];
    
    if (matchingAsset) {

        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self willChangeValueForKey:@"jvmReleases"];
            [matchingAsset setIsUpdating:NO];
            [matchingAsset setInstalledVersion:[asset currentVersion]];
            [matchingAsset setInstallURL:[asset installURL]];
            [matchingAsset setJavaHomeURL:[asset javaHomeURL]];
            [self didChangeValueForKey:@"jvmReleases"];
            
            // if all downloads are finished, check for updates again.
            // otherwise just update the number of available updates
            if (![self updateInProgress]) {

                [self allUpdatesDone];
                
            } else {
                
                self.updatesAvailable = [self numberOfAvailableUpdates];
            }
        });
    }
}

- (void)updateFailedForAsset:(MTSapMachineAsset*)asset withError:(NSError*)error
{
    MTSapMachineAsset *matchingAsset = [self matchingAssetForAsset:asset];
    
    if (matchingAsset) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self willChangeValueForKey:@"jvmReleases"];
            [matchingAsset setIsUpdating:NO];
            [self didChangeValueForKey:@"jvmReleases"];
            
            self.updatesFailed++;
            
            // if all downloads are finished, check for updates again.
            // otherwise just update the number of available updates
            if (![self updateInProgress]) {

                [self allUpdatesDone];
                
            } else {
                
                self.updatesAvailable = [self numberOfAvailableUpdates];
            }
        });
    }
}

- (void)downloadProgressUpdatedForAsset:(MTSapMachineAsset*)asset
{
    MTSapMachineAsset *matchingAsset = [self matchingAssetForAsset:asset];
    
    if (matchingAsset) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self willChangeValueForKey:@"jvmReleases"];
            [matchingAsset setIsUpdating:YES];
            [matchingAsset setUpdateProgress:[asset updateProgress]];
            [self didChangeValueForKey:@"jvmReleases"];
        });
    }
}

#pragma mark MTDaemonConnectionDelegate

- (void)connection:(NSXPCConnection *)connection didFailWithError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        SMAppService *launchdService = [SMAppService daemonServiceWithPlistName:kMTDaemonPlistName];
                
        NSAlert *theAlert = [[NSAlert alloc] init];
        
        if ([launchdService status] == SMAppServiceStatusRequiresApproval) {
            
            [theAlert setMessageText:NSLocalizedString(@"dialogLoginItemDisabledTitle", nil)];
            [theAlert setInformativeText:NSLocalizedString(@"dialogXPCConnectionFailedLoginItemMessage", nil)];
            
        } else {
            
            [theAlert setMessageText:NSLocalizedString(@"dialogXPCConnectionFailedTitle", nil)];
            [theAlert setInformativeText:NSLocalizedString(@"dialogXPCConnectionFailedMessage", nil)];
        }
        
        [theAlert addButtonWithTitle:NSLocalizedString(@"quitButton", nil)];
        [theAlert setAlertStyle:NSAlertStyleCritical];
        [theAlert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
            
            [NSApp terminate:self];
        }];
    });
}

#pragma mark NSMenuItemValidation

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    BOOL enableItem = [[[self view] window] isVisible];
    
    if ([item tag] >= 1000 && (_updateCheckInProgress || _installInProgress)) {
        
        enableItem = NO;
        
    // this is for the main menu only
    } else if ([item tag] == 1500) {
        
        NSInteger itemCount = [[self.releasesController selectionIndexes] count];

        if (itemCount == 0) {
            enableItem = NO;
            
        } else if (itemCount == 1) {
            [item setTitle:NSLocalizedString(@"deleteOneMainMenuEntry", nil)];
            
        } else if (itemCount > 1) {
            [item setTitle:[NSString localizedStringWithFormat:NSLocalizedString(@"deleteMultipleMainMenuEntry", nil), itemCount]];
        }
    }

    return enableItem;
}

#pragma mark IBActions

- (IBAction)performButtonAction:(id)sender
{
    // check for updates or install available updates,
    // depending on our button's title
    if ([[sender title] isEqualToString:NSLocalizedString(@"checkButtonTitle", nil)]) {
        
        [self checkForUpdates];
        
    } else {
        
        [self installUpdates];
    }
}

- (IBAction)installSapMachine:(id)sender
{
    // check if we have any assets for installation
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"installURL == nil AND downloadURLForCurrentArchitecture != nil"];
    
    if ([[_jvmReleases filteredArrayUsingPredicate:predicate] count] > 0) {

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(installSheetDidClose)
                                                     name:NSWindowDidEndSheetNotification
                                                   object:[[self view] window]
        ];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(installHasFinished:)
                                                     name:kMTNotificationNameInstallFinished
                                                   object:nil
        ];
        
        if (sender && [[sender class] isEqualTo:[MTSapMachineAsset class]]) {
            
            [self performSegueWithIdentifier:@"corp.sap.SapMachineManager.Install.recommended" sender:sender];
            
        } else {
            
            [self performSegueWithIdentifier:@"corp.sap.SapMachineManager.Install.main" sender:_jvmReleases];
        }
        
    } else {
        
        NSAlert *theAlert = [[NSAlert alloc] init];
        [theAlert setMessageText:NSLocalizedString(@"dialogNothingToInstallTitle", nil)];
        [theAlert setInformativeText:NSLocalizedString(@"dialogNothingToInstallMessage", nil)];
        [theAlert addButtonWithTitle:NSLocalizedString(@"okButton", nil)];
        [theAlert setAlertStyle:NSAlertStyleInformational];
        [theAlert beginSheetModalForWindow:[[self view] window] completionHandler:nil];
    }
}

- (IBAction)buildInstallerPackage:(id)sender
{
    // check if we have any assets available
    if ([_jvmReleases count] > 0) {
        
        [self performSegueWithIdentifier:@"corp.sap.SapMachineManager.pkgBuilder.main" sender:_jvmReleases];
        
    } else {
            
        NSAlert *theAlert = [[NSAlert alloc] init];
        [theAlert setMessageText:NSLocalizedString(@"dialogNothingToPackageTitle", nil)];
        [theAlert setInformativeText:NSLocalizedString(@"dialogNothingToPackageMessage", nil)];
        [theAlert addButtonWithTitle:NSLocalizedString(@"okButton", nil)];
        [theAlert setAlertStyle:NSAlertStyleInformational];
        [theAlert beginSheetModalForWindow:[[self view] window] completionHandler:nil];
    }
}

- (IBAction)deleteAsset:(id)sender
{
    NSInteger clickedRow = [_tableView clickedRow];

    if ((clickedRow >= 0 && clickedRow < [[self->_releasesController arrangedObjects] count]) || [[_tableView selectedRowIndexes] count] > 0) {
        
        NSIndexSet *toBeDeleted = nil;
        
        if (clickedRow == NSUIntegerMax || [[_tableView selectedRowIndexes] containsIndex:clickedRow]) {
            toBeDeleted = [_tableView selectedRowIndexes];
        } else {
            toBeDeleted = [NSIndexSet indexSetWithIndex:clickedRow];
        }
                
        NSAlert *theAlert = [[NSAlert alloc] init];
        
        if ([toBeDeleted count] > 1) {
            [theAlert setMessageText:[NSString localizedStringWithFormat:NSLocalizedString(@"dialogDeleteMultipleTitle", nil), [toBeDeleted count]]];
        } else {
            MTSapMachineAsset *asset = [[[self->_releasesController arrangedObjects] objectsAtIndexes:toBeDeleted] firstObject];
            [theAlert setMessageText:[NSString localizedStringWithFormat:NSLocalizedString(@"dialogDeleteOneTitle", nil), [asset displayName]]];
        }
        
        [theAlert setInformativeText:NSLocalizedString(@"dialogDeleteMessage", nil)];
        NSButton *deleteButton = [theAlert addButtonWithTitle:NSLocalizedString(@"deleteButton", nil)];
        [deleteButton setHasDestructiveAction:YES];
        [theAlert addButtonWithTitle:NSLocalizedString(@"cancelButton", nil)];
        [theAlert setAlertStyle:NSAlertStyleInformational];
        [theAlert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
            
            if (returnCode == NSAlertFirstButtonReturn) {
                
                NSArray *assets = [[self->_releasesController arrangedObjects] objectsAtIndexes:toBeDeleted];
                [self deleteAssetsPermanently:assets allowUserInteraction:YES completionHandler:nil];
            }
        }];
    }
}

- (IBAction)showAssetInFinder:(id)sender
{
    NSInteger clickedRow = [_tableView clickedRow];

    if ((clickedRow >= 0 && clickedRow < [[self->_releasesController arrangedObjects] count]) || [[_tableView selectedRowIndexes] count] > 0) {
        
        NSIndexSet *toBeDisplayed = nil;
        
        if (clickedRow == NSUIntegerMax || [[_tableView selectedRowIndexes] containsIndex:clickedRow]) {
            toBeDisplayed = [_tableView selectedRowIndexes];
        } else {
            toBeDisplayed = [NSIndexSet indexSetWithIndex:clickedRow];
        }
        
        NSArray *assets = [[self->_releasesController arrangedObjects] objectsAtIndexes:toBeDisplayed];
        NSMutableArray *displayURLs = [[NSMutableArray alloc] init];
        
        for (MTSapMachineAsset *asset in assets) {
            
            if (asset && [asset installURL]) {
                [displayURLs addObject:[asset installURL]];
            }
        }
        
        // show assets in Finder
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:displayURLs];
    }
}

- (IBAction)setJavaHome:(id)sender
{
    BOOL setJavaHome = ([sender tag] == 1100) ? YES : NO;
    NSInteger clickedRow = [_tableView clickedRow];
    
    NSAlert *theAlert = [[NSAlert alloc] init];
    
    if (setJavaHome) {
        
        [theAlert setMessageText:NSLocalizedString(@"dialogSetJavaHomeTitle", nil)];
        [theAlert setInformativeText:NSLocalizedString(@"dialogSetJavaHomeMessage", nil)];
        
    } else {
        
        [theAlert setMessageText:NSLocalizedString(@"dialogUnsetJavaHomeTitle", nil)];
        [theAlert setInformativeText:NSLocalizedString(@"dialogUnsetJavaHomeMessage", nil)];
    }
    
    [theAlert addButtonWithTitle:NSLocalizedString(@"cancelButton", nil)];
    [[theAlert addButtonWithTitle:NSLocalizedString(@"currentUserOnlyButton", nil)] setKeyEquivalent:@"\r"];
    [theAlert addButtonWithTitle:NSLocalizedString(@"allUsersButton", nil)];
    [theAlert setAlertStyle:NSAlertStyleInformational];
    [theAlert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
        
        if (returnCode == NSAlertSecondButtonReturn || returnCode == NSAlertThirdButtonReturn) {

            BOOL userOnly = (returnCode == NSAlertSecondButtonReturn) ? YES : NO;
            
            [self authenticateUserWithCompletionHandler:^{
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    if (setJavaHome) {
                        
                        MTSapMachineAsset *asset = [[self->_releasesController arrangedObjects] objectAtIndex:clickedRow];
                        
                        [self->_daemonConnection connectToDaemonWithExportedObject:nil
                                                            andExecuteCommandBlock:^{
                            
                            [[self->_daemonConnection remoteObjectProxy] setJavaHomeEnvironmentVariableUsingAsset:asset
                                                                                                         userOnly:userOnly
                                                                                                    authorization:self->_authData
                                                                                                completionHandler:^(BOOL success, NSError *error) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    
                                    self->_authData = nil;
                                    
                                    if (!success) {
                                        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to set JAVA_HOME environment variable (%{public}@): %{public}@", (userOnly) ? @"user" : @"system", error);
                                    }

                                    [self checkForUpdates];
                                });
                            }];
                        }];
                        
                    } else {
                        
                        [self->_daemonConnection connectToDaemonWithExportedObject:nil
                                                            andExecuteCommandBlock:^{
                            
                            [[self->_daemonConnection remoteObjectProxy] unsetJavaHomeEnvironmentVariableForUserOnly:userOnly
                                                                                                       authorization:self->_authData
                                                                                                   completionHandler:^(NSArray *changedFiles, NSError *error) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    
                                    self->_authData = nil;
                                    
                                    if (error) {
                                        os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to unset JAVA_HOME environment variable (%{public}@): %{public}@", (userOnly) ? @"user" : @"system", error);
                                    }
                                    
                                    [self checkForUpdates];
                                });
                            }];
                        }];
                    }
                    
                });
            }];
        }
    }];
}

#pragma mark other methods

- (MTSapMachineAsset*)matchingAssetForAsset:(MTSapMachineAsset*)asset
{
    MTSapMachineAsset *matchingAsset = nil;
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"downloadURLs == %@", [asset downloadURLs]];
    NSArray *filteredArray = [[_releasesController arrangedObjects] filteredArrayUsingPredicate:predicate];
    
    if ([filteredArray count] == 1) { matchingAsset = [filteredArray firstObject]; }
    
    return matchingAsset;
}

- (BOOL)updateInProgress
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isUpdating == %@", [NSNumber numberWithBool:YES]];
    BOOL inProgress = ([[[_releasesController arrangedObjects] filteredArrayUsingPredicate:predicate] count] > 0) ? YES : NO;
    
    return inProgress;
}

- (NSInteger)numberOfAvailableUpdates
{
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary<NSString *,id> *bindings) {
        
        MTSapMachineAsset *asset = (MTSapMachineAsset*)evaluatedObject;
        BOOL updateAvailable = ([[asset currentVersion] compare:[asset installedVersion]] == NSOrderedDescending) ? YES : NO;
        
        return updateAvailable;
    }];
    
    return [[[_releasesController arrangedObjects] filteredArrayUsingPredicate:predicate] count];
}

- (void)allUpdatesDone
{
    dispatch_async(dispatch_get_main_queue(), ^{

        if (self.installInProgress && !self.updateCheckInProgress) {

            [self checkForUpdates];
            self.installInProgress = NO;
                        
            if (self.updatesFailed > 0) {
                
                NSAlert *theAlert = [[NSAlert alloc] init];
                
                if (self.updatesFailed == 1) {
                    
                    [theAlert setMessageText:NSLocalizedString(@"dialogOneUpdateFailedTitle", nil)];
                    [theAlert setInformativeText:NSLocalizedString(@"dialogOneUpdateFailedMessage", nil)];
                    
                } else {
                    
                    [theAlert setMessageText:NSLocalizedString(@"dialogMultipleUpdatesFailedTitle", nil)];
                    [theAlert setInformativeText:NSLocalizedString(@"dialogMultipleUpdatesFailedMessage", nil)];
                }
                
                [theAlert addButtonWithTitle:NSLocalizedString(@"okButton", nil)];
                [theAlert addButtonWithTitle:NSLocalizedString(@"showLogButton", nil)];
                [theAlert setAlertStyle:NSAlertStyleWarning];
                [theAlert beginSheetModalForWindow:[[self view] window] completionHandler:^(NSModalResponse returnCode) {
                    
                    if (returnCode == NSAlertSecondButtonReturn) {
                        
                        // show log window
                        [self showLog];
                    }
                }];
            }
        }
    });
}

- (void)authenticateUserWithCompletionHandler:(void (^)(void))completionHandler
{
    self->_authData = nil;
    MTSapMachineUser *user = [[MTSapMachineUser alloc] initWithUserName:NSUserName()];

    if (![user isPrivileged]) {
                
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self->_daemonConnection connectToXPCServiceWithRemoteObjectProxyReply:^(id remoteObjectProxy, NSError *error) {
                
                [remoteObjectProxy authenticateWithAuthorizationReply:^(NSData *authorization) {
                    
                    self->_authData = authorization;
                    if (completionHandler) { completionHandler(); }
                }];
            }];
        });
        
    } else if (completionHandler) {
        completionHandler();
    }
}

- (void)showLog
{
    if (!_logController) {
        
        _logController = [[self storyboard] instantiateControllerWithIdentifier:@"corp.sap.SapMachineManager.LogController"];
        [_logController loadWindow];
    }
    
    [[_logController window] makeKeyAndOrderFront:nil];
}

- (void)installSheetDidClose
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSWindowDidEndSheetNotification
                                                  object:[[self view] window]
    ];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kMTDefaultsInstallErrorKey] || [[_releasesController arrangedObjects] count] == 0) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self checkForUpdates];
        });
    }
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kMTDefaultsInstallErrorKey];
}

- (void)installHasFinished:(NSNotification*)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kMTNotificationNameInstallFinished
                                                  object:nil
    ];
                                    
    // if we successfully installed an asset as part of an upgrade,
    // we check if there are any assets to delete
    BOOL installError = [[[notification userInfo] objectForKey:kMTNotificationKeyInstallError] boolValue];

    if (installError) {

        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kMTDefaultsInstallErrorKey];
        
    } else {
        
        if (self->_assetsToDeleted) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [self deleteAssetsPermanently:self->_assetsToDeleted allowUserInteraction:NO completionHandler:^(NSError *error) {
                    
                    self->_assetsToDeleted = nil;
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self checkForUpdates];
                    });
                }];
            });
            
        } else {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self checkForUpdates];
            });
        }
    }
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"corp.sap.SapMachineManager.Install.main"]) {
        
        MTInstallIntroController *destController = [segue destinationController];
        [destController setAssetCatalog:(NSArray*)sender];
        [destController setSkipRecommended:_skipRecommendedInstall];
        _skipRecommendedInstall = NO;
        
    } else if ([[segue identifier] isEqualToString:@"corp.sap.SapMachineManager.pkgBuilder.main"]) {
        
        MTPackageIntroController *destController = [segue destinationController];
        [destController setAssetCatalog:(NSArray*)sender];
        
    } else if ([[segue identifier] isEqualToString:@"corp.sap.SapMachineManager.Install.recommended"]) {
        
        MTInstallController *destController = [segue destinationController];
        [destController setSelectedAsset:(MTSapMachineAsset*)sender];
    }
}

@end
