/*
     MTReleaseStatusTransformer.h
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

#import "MTReleaseStatusTransformer.h"
#import "MTSapMachineAsset.h"

@implementation MTReleaseStatusTransformer

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    MTSapMachineAsset *asset = (MTSapMachineAsset*)value;
    MTSapMachineVersion *installedVersion = [asset installedVersion];
    MTSapMachineVersion *currentVersion = [asset currentVersion];
    
    NSString *statusString = nil;
    
    if ([currentVersion compare:installedVersion] == NSOrderedDescending) {
        
        statusString = [NSString localizedStringWithFormat:NSLocalizedString(@"statusUpdateAvailable", nil), [installedVersion versionString], [currentVersion versionString]];
        
    } else {
        
        statusString = [NSString localizedStringWithFormat:NSLocalizedString(@"statusUpToDate", nil), [installedVersion versionString]];
    }
    
    return statusString;
}

@end