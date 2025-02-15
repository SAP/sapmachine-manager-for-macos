/*
     MTReleaseImageTransformer.m
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

#import "MTReleaseImageTransformer.h"
#import "MTSapMachineAsset.h"

@implementation MTReleaseImageTransformer

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    MTSapMachineAsset *asset = (MTSapMachineAsset*)value;
    NSString *imageName = nil;
    
    if ([asset downloadURLs]) {
        
        if ([[asset currentVersion] compare:[asset installedVersion]] == NSOrderedDescending) {
            
            imageName = @"exclamationmark.triangle";
            
        } else {
            
            imageName = @"checkmark.circle";
        }
        
    } else {
        
        imageName = @"questionmark.square";
    }
    
    NSImage *statusImage = [NSImage imageWithSystemSymbolName:imageName accessibilityDescription:imageName];
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration configurationWithScale:NSImageSymbolScaleLarge];
    statusImage = [statusImage imageWithSymbolConfiguration:config];
    
    return statusImage;
}

@end
