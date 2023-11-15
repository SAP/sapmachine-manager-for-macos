/*
     MTPackageIntroController.m
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

#import "MTPackageIntroController.h"
#import "MTPackageReleaseSelectController.h"
#import "Constants.h"

@interface MTPackageIntroController ()
@property (weak) IBOutlet NSTextField *infoTextField;

@end

@implementation MTPackageIntroController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // make the link in our text field clickable
    NSMutableAttributedString *finalString = [[NSMutableAttributedString alloc] initWithAttributedString:[_infoTextField attributedStringValue]];
        
    NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
    NSArray *allMatches = [linkDetector matchesInString:[finalString string] options:0 range:NSMakeRange(0, [[finalString string] length])];
    
    for (NSTextCheckingResult *match in [allMatches reverseObjectEnumerator]) {
        [finalString addAttribute:NSLinkAttributeName value:[match URL] range:[match range]];
    }
   
    [_infoTextField setAttributedStringValue:finalString];
}

- (void)prepareForSegue:(NSStoryboardSegue *)segue sender:(id)sender
{
    MTPackageReleaseSelectController *destController = [segue destinationController];
    [destController setIsInstall:NO];
    [destController setAssetCatalog:_assetCatalog];
}

@end
