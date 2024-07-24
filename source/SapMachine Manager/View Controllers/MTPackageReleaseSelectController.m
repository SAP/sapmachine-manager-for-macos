/*
     MTPackageReleaseSelectController.m
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

#import "MTPackageReleaseSelectController.h"
#import "MTPackageArchSelectController.h"
#import "MTInstallController.h"
#import "MTSapMachineAsset.h"
#import "Constants.h"

@interface MTPackageReleaseSelectController ()
@property (nonatomic, strong, readwrite) NSMutableArray *releasesArray;
@property (assign) BOOL enableJREButton;
@property (assign) BOOL enableJDKButton;

@property (weak) IBOutlet NSButton *typeJREButton;
@property (weak) IBOutlet NSButton *typeJDKButton;
@property (weak) IBOutlet NSArrayController *releasesArrayController;
@property (weak) IBOutlet NSPopUpButton *releaseVersionButton;
@property (weak) IBOutlet NSTextField *headlineText;
@end

@implementation MTPackageReleaseSelectController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (_isInstall) {
        [_headlineText setStringValue:NSLocalizedString(@"installReleaseSelect", nil)];
    } else {
        [_headlineText setStringValue:NSLocalizedString(@"packageBuildReleaseSelect", nil)];
    }
    
    // build an array with release names for our popup button
    NSMutableArray *uniqueReleases = [[NSMutableArray alloc] init];
    
    for (MTSapMachineAsset *asset in _assetCatalog) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"displayName == %@", [asset displayName]];
        
        if ([[uniqueReleases filteredArrayUsingPredicate:predicate] count] == 0) {
            [uniqueReleases addObject:asset];
        }
    }
    
    _releasesArray = [[NSMutableArray alloc] init];
    [self.releasesArrayController addObjects:uniqueReleases];
    
    // initially select the newest release
    NSInteger indexOfLatestRelease = 0;
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"isEA == %@", [NSNumber numberWithBool:NO]];
    NSArray *filteredArray = [uniqueReleases filteredArrayUsingPredicate:filterPredicate];
    
    if ([filteredArray count] > 0) {
        
        indexOfLatestRelease = [[_releasesArrayController arrangedObjects] indexOfObjectIdenticalTo:[filteredArray lastObject]];
    }
    
    [self.releaseVersionButton selectItemAtIndex:indexOfLatestRelease];
    [self setRadioButtonsForRelease:[[_releasesArrayController arrangedObjects] objectAtIndex:indexOfLatestRelease]];
}

- (IBAction)selectJVMType:(id)sender
{
    
}

- (IBAction)selectRelease:(id)sender
{
    [self setRadioButtonsForRelease:[[_releasesArrayController arrangedObjects] objectAtIndex:[_releaseVersionButton indexOfSelectedItem]]];
}

- (void)setRadioButtonsForRelease:(MTSapMachineAsset*)asset
{
    self.enableJREButton = [self enableRelease:asset ofType:MTSapMachineJVMTypeJRE shouldBeInstalled:_isInstall];
    self.enableJDKButton = [self enableRelease:asset ofType:MTSapMachineJVMTypeJDK shouldBeInstalled:_isInstall];
    
    if (_enableJREButton) {
        
        [_typeJREButton setState:NSControlStateValueOn];
        
    } else if (_enableJDKButton) {
        
        [_typeJDKButton setState:NSControlStateValueOn];
    }
}

- (BOOL)enableRelease:(MTSapMachineAsset*)asset ofType:(MTSapMachineJVMType)type shouldBeInstalled:(BOOL)install
{
    BOOL enable = NO;
    
    if (install) {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"currentVersion.majorVersion == %ld AND jvmType == %ld AND isEA == %@ AND installURL == nil AND downloadURLForCurrentArchitecture != nil", [[asset currentVersion] majorVersion], type, [NSNumber numberWithBool:[asset isEA]]];
        enable = ([[_assetCatalog filteredArrayUsingPredicate:predicate] count] > 0) ? YES : NO;
        
    } else {
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"currentVersion.majorVersion == %ld AND jvmType == %ld AND isEA == %@", [[asset currentVersion] majorVersion], type, [NSNumber numberWithBool:[asset isEA]]];
        enable = ([[_assetCatalog filteredArrayUsingPredicate:predicate] count] > 0) ? YES : NO;
    }
    
    return enable;
}

- (IBAction)goToNextStep:(id)sender
{
    if (_isInstall) {
        
        [self performSegueWithIdentifier:@"corp.sap.SapMachineManager.Install.final" sender:nil];
        
    } else {

        [self performSegueWithIdentifier:@"corp.sap.SapMachineManager.pkgBuilder.arch" sender:nil];
    }
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
    NSInteger selectionIndex = [_releaseVersionButton indexOfSelectedItem];
    
    if (selectionIndex >= 0 && selectionIndex < [[_releasesArrayController arrangedObjects] count]) {
        
        MTSapMachineAsset *selectedRelease = (MTSapMachineAsset*)[[_releasesArrayController arrangedObjects] objectAtIndex:selectionIndex];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"currentVersion.majorVersion == %ld AND jvmType == %ld AND isEA == %@", [[selectedRelease currentVersion] majorVersion], ([_typeJREButton state] == NSControlStateValueOn) ? MTSapMachineJVMTypeJRE : MTSapMachineJVMTypeJDK, [NSNumber numberWithBool:[selectedRelease isEA]]];
        MTSapMachineAsset *selectedAsset = [[_assetCatalog filteredArrayUsingPredicate:predicate] firstObject];
        
        if ([[segue identifier] isEqualToString:@"corp.sap.SapMachineManager.pkgBuilder.arch"]) {
            
            MTPackageArchSelectController *destController = [segue destinationController];
            [destController setSelectedAsset:selectedAsset];
            
        } else if ([[segue identifier] isEqualToString:@"corp.sap.SapMachineManager.Install.final"]) {
            
            MTInstallController *destController = [segue destinationController];
            [destController setSelectedAsset:selectedAsset];
        }
    }
}

@end
