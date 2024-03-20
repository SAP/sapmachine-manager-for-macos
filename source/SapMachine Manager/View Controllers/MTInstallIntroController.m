/*
     MTInstallIntroController.m
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

#import "MTInstallIntroController.h"
#import "MTInstallController.h"
#import "MTPackageReleaseSelectController.h"
#import "Constants.h"

@interface MTInstallIntroController ()
@property (nonatomic, strong, readwrite) MTSapMachineAsset *toBeInstalled;

@property (weak) IBOutlet NSView *installRecommendedView;
@property (weak) IBOutlet NSButton *installRecommended;
@end

@implementation MTInstallIntroController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kMTDefaultsInstallErrorKey];
    
    // get the JDK of the latest LTS release for the current architecture…
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"jvmType == %ld AND isLTS == %@ AND isEA == %@ AND downloadURLForCurrentArchitecture != nil", MTSapMachineJVMTypeJDK, [NSNumber numberWithBool:YES], [NSNumber numberWithBool:NO]];
    NSArray *ltsJDKs = [_assetCatalog filteredArrayUsingPredicate:predicate];
    
    // if we got a release and it is not already installed, we display a checkbox
    // allowing the user to install the recommended version of SapMachine
    if ([ltsJDKs count] > 0) {
        
        // sort the returned assets by version number and get the highest one
        NSArray *sortDescriptors = [NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"currentVersion.majorVersion"
                                                                                          ascending:NO
                                                            ]
        ];
        NSArray *sortedAssets = [ltsJDKs sortedArrayUsingDescriptors:sortDescriptors];
        MTSapMachineAsset *recommendedAsset = [sortedAssets firstObject];
        if (![recommendedAsset installURL]) { _toBeInstalled = recommendedAsset; }
    }
    
    if (_toBeInstalled) {
        
        [_installRecommended setState:(_skipRecommended) ? NSControlStateValueOff : NSControlStateValueOn];
        [_installRecommendedView setHidden:NO];
        
    } else {
        
        [_installRecommended setState:NSControlStateValueOff];
        [_installRecommendedView setHidden:YES];
    }
}

- (IBAction)goToNextStep:(id)sender
{
    if ([_installRecommended state] == NSControlStateValueOn) {
        
        [self performSegueWithIdentifier:@"corp.sap.SapMachineManager.Install.recommended" sender:_toBeInstalled];
        
    } else {

        [self performSegueWithIdentifier:@"corp.sap.SapMachineManager.Install.step1" sender:nil];
    }
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"corp.sap.SapMachineManager.Install.recommended"]) {
        
        MTInstallController *destController = [segue destinationController];
        [destController setSelectedAsset:(MTSapMachineAsset*)sender];
        
    } else {
        
        MTPackageReleaseSelectController *destController = [segue destinationController];
        [destController setIsInstall:YES];
        [destController setAssetCatalog:_assetCatalog];
    }
}

@end
