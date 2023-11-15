/*
     MTPackageReleaseSelectController.m
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
    
    _releasesArray = [[NSMutableArray alloc] init];
    [self.releasesArrayController addObjects:_assetCatalog];
    
    // make sure the popup button contains the correct information
    // we use a predicate to initially select all JREs. if the jvm
    // should be installed, we select only JREs that are suitable
    // for the current platform and are not already installed.
    // if now jre or jdk is available, we disable the corresponding
    // checkboxes.
    
    // we start with a predicate that no assets can match
    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"jvmType < 0"];
    
    if (_isInstall) {
        
        NSPredicate *jrePredicate = [NSPredicate predicateWithFormat:@"jvmType == %ld AND installURL == nil AND downloadURLForCurrentArchitecture != nil", MTSapMachineJVMTypeJRE];
        self.enableJREButton = ([[_assetCatalog filteredArrayUsingPredicate:jrePredicate] count] > 0) ? YES : NO;
        
        NSPredicate *jdkPredicate = [NSPredicate predicateWithFormat:@"jvmType == %ld AND installURL == nil AND downloadURLForCurrentArchitecture != nil", MTSapMachineJVMTypeJDK];
        self.enableJDKButton = ([[_assetCatalog filteredArrayUsingPredicate:jdkPredicate] count] > 0) ? YES : NO;
        
        if (_enableJREButton) {
            
            filterPredicate = jrePredicate;
            [_typeJREButton setState:NSControlStateValueOn];
            
        } else if (_enableJDKButton) {
            
            filterPredicate = jdkPredicate;
            [_typeJDKButton setState:NSControlStateValueOn];
        }
                
    } else {
        
        NSPredicate *jrePredicate = [NSPredicate predicateWithFormat:@"jvmType == %ld", MTSapMachineJVMTypeJRE];
        self.enableJREButton = ([[_assetCatalog filteredArrayUsingPredicate:jrePredicate] count] > 0) ? YES : NO;
        
        NSPredicate *jdkPredicate = [NSPredicate predicateWithFormat:@"jvmType == %ld", MTSapMachineJVMTypeJDK];
        self.enableJDKButton = ([[_assetCatalog filteredArrayUsingPredicate:jdkPredicate] count] > 0) ? YES : NO;
        
        if (_enableJREButton) {
            
            filterPredicate = jrePredicate;
            [_typeJREButton setState:NSControlStateValueOn];
            
        } else if (_enableJDKButton) {
            
            filterPredicate = jdkPredicate;
            [_typeJDKButton setState:NSControlStateValueOn];
        }
    }
    
    [self.releasesArrayController setFilterPredicate:filterPredicate];
    
    // initially select the newest release
    NSInteger indexOfLatestRelease = 0;
    filterPredicate = [NSPredicate predicateWithFormat:@"isEA == %@", [NSNumber numberWithBool:NO]];
    NSArray *filteredArray = [[self.releasesArrayController arrangedObjects] filteredArrayUsingPredicate:filterPredicate];
    
    if ([filteredArray count] > 0) {
        indexOfLatestRelease = [[self.releasesArrayController arrangedObjects] indexOfObjectIdenticalTo:[filteredArray lastObject]];
    }
    [self.releasesArrayController setSelectionIndex:indexOfLatestRelease];
}

- (IBAction)selectJVMType:(id)sender
{
    NSString *selectionName = [_releaseVersionButton titleOfSelectedItem];
    
    // filter the array controller
    NSMutableArray *predicatesArray = [[NSMutableArray alloc] init];
    [predicatesArray addObject:[NSPredicate predicateWithFormat:@"jvmType == %ld", [sender tag]]];
    if (_isInstall) { [predicatesArray addObject:[NSPredicate predicateWithFormat:@"installURL == nil AND downloadURLForCurrentArchitecture != nil"]]; }
    [self.releasesArrayController setFilterPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:predicatesArray]];
    
    // try to select the same release again
    NSInteger itemIndex = [_releaseVersionButton indexOfItemWithTitle:selectionName];
    if (itemIndex == -1) { itemIndex = 0; }
    [self.releaseVersionButton selectItemAtIndex:itemIndex];
    [self.releasesArrayController setSelectionIndex:[_releaseVersionButton indexOfSelectedItem]];
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
    NSInteger selectionIndex = [_releasesArrayController selectionIndex];
    
    if (selectionIndex >= 0 && selectionIndex < [[_releasesArrayController arrangedObjects] count]) {
        
        MTSapMachineAsset *selectedAsset = (MTSapMachineAsset*)[[_releasesArrayController arrangedObjects] objectAtIndex:selectionIndex];
        
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
