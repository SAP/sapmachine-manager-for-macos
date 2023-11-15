/*
     MTPackageArchSelectController.m
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

#import "MTPackageArchSelectController.h"
#import "MTPackageBuildController.h"
#import "Constants.h"

@interface MTPackageArchSelectController ()
@property (assign) NSInteger selectedArchitecture;

@property (weak) IBOutlet NSButton *archAppleButton;
@property (weak) IBOutlet NSButton *archIntelButton;
@property (weak) IBOutlet NSButton *archBothButton;
@end

@implementation MTPackageArchSelectController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([[_selectedAsset downloadURLs] objectForKey:kMTSapMachineArchApple] && [[_selectedAsset downloadURLs] objectForKey:kMTSapMachineArchIntel]) {
        
        [_archBothButton setState:NSControlStateValueOn];
        self.selectedArchitecture = 3;
        
    } else if ([[_selectedAsset downloadURLs] objectForKey:kMTSapMachineArchApple]) {
        
        [_archAppleButton setState:NSControlStateValueOn];
        self.selectedArchitecture = 1;
        
    } else if ([[_selectedAsset downloadURLs] objectForKey:kMTSapMachineArchIntel]) {
        
        [_archIntelButton setState:NSControlStateValueOn];
        self.selectedArchitecture = 2;
        
    } else {
        
        self.selectedArchitecture = 0;
    }
}

- (IBAction)selectArchitecture:(id)sender
{
    self.selectedArchitecture = [sender tag];
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"corp.sap.SapMachineManager.pkgBuilder.build"]) {

        MTPackageBuildController *destController = [segue destinationController];
        [destController setSelectedAsset:_selectedAsset];
        [destController setSelectedArchitecture:_selectedArchitecture];
    }
}

@end
