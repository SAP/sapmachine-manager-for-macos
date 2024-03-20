/*
     MTLabelTextTransformer.m
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

#import "MTLabelTextTransformer.h"

@implementation MTLabelTextTransformer

+ (BOOL)allowsReverseTransformation
{
    return NO;
}

- (id)transformedValue:(id)value
{
    NSString *buttonText = NSLocalizedString(@"noUpdatesAvailable", nil);
    NSInteger updateCount = [value integerValue];
    
    if (updateCount == 1) {
        
        buttonText = NSLocalizedString(@"oneUpdateAvailable", nil);
        
    } else if (updateCount > 1) {
        
        buttonText = [NSString localizedStringWithFormat:NSLocalizedString(@"multipleUpdatesAvailable", nil), updateCount];
    }
    
    return buttonText;
}

@end
