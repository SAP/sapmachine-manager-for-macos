/*
     MTSapMachineVersion.m
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

#import "MTSapMachineVersion.h"

@interface MTSapMachineVersion ()
@property (nonatomic, strong, readwrite) NSString *versionString;
@property (nonatomic, strong, readwrite) NSString *normalizedVersionString;
@property (assign) NSUInteger majorVersion;
@end

@implementation MTSapMachineVersion

- (instancetype)initWithCoder:(NSCoder*)aDecoder
{
    self = [super init];
    
    if (self) {

        _versionString = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"versionString"];
        _normalizedVersionString = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"normalizedVersionString"];
        _majorVersion = [aDecoder decodeIntegerForKey:@"majorVersion"];
   }
    
   return self;
}

- (void)encodeWithCoder:(NSCoder*)aCoder
{
    [aCoder encodeObject:_versionString forKey:@"versionString"];
    [aCoder encodeObject:_normalizedVersionString forKey:@"normalizedVersionString"];
    [aCoder encodeInteger:_majorVersion forKey:@"majorVersion"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTSapMachineVersion *newVersion = [[[self class] allocWithZone:zone] initWithVersionString:_versionString];
    return newVersion;
}

- (instancetype)initWithVersionString:(NSString *)versionString
{
    self = [super init];
    
    if (self) {
        
        if ([versionString length] > 0) {
            
            _versionString = [self strippedVersionStringWithString:versionString];
            
            NSArray *versionComponents = [NSArray arrayWithArray:[self versionComponentsWithString:_versionString]];
            _normalizedVersionString = [versionComponents componentsJoinedByString:@"."];
            _majorVersion = [[versionComponents firstObject] integerValue];
            
        } else {
            self = nil;
        }
    }
    
    return self;
}

- (NSString*)strippedVersionStringWithString:(NSString*)versionString
{
    NSMutableCharacterSet *allowedCharacters = [NSMutableCharacterSet decimalDigitCharacterSet];
    [allowedCharacters addCharactersInString:@"+."];
    versionString = [[versionString componentsSeparatedByCharactersInSet:[allowedCharacters invertedSet]] componentsJoinedByString:@""];
    
    return versionString;
}

- (NSArray*)versionComponentsWithString:(NSString*)versionString
{
    versionString = [self strippedVersionStringWithString:versionString];

    // get the parts of the version number
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^(\\d+)(?:\\.(\\d+))?(?:\\.(\\d+))?(?:\\.(\\d+))?(?:\\.(\\d+))?(?:\\.(\\d+))?" options:NSRegularExpressionCaseInsensitive error:nil];
    NSTextCheckingResult *result = [regex firstMatchInString:versionString options:kNilOptions range:NSMakeRange(0, [versionString length])];
    
    // checking for capturing groups
    NSMutableArray *versionArray = [[NSMutableArray alloc] init];

    for (int i = 1; i < [result numberOfRanges]; i++) {
        
        NSNumber *versionNumberPart = [NSNumber numberWithInt:0];

        if ([result rangeAtIndex:i].location != NSNotFound) {
            versionNumberPart = [NSNumber numberWithInt:[[versionString substringWithRange:[result rangeAtIndex:i]] intValue]];
        }
        
        [versionArray addObject:versionNumberPart];
    }

    // get the build number
    NSNumber *buildNumber = [NSNumber numberWithInt:0];
    NSRange range = [versionString rangeOfString:@"+"];
    
    if (range.location != NSNotFound) {
        buildNumber = [NSNumber numberWithInt:[[versionString substringFromIndex:range.location + 1] intValue]];
    }
    
    [versionArray addObject:buildNumber];
    
    return versionArray;
}

- (NSComparisonResult)compare:(MTSapMachineVersion*)version
{
    NSComparisonResult result = [[self normalizedVersionString] compare:[version normalizedVersionString] options:NSNumericSearch];

    return result;
}

@end
