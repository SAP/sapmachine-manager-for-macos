/*
     MTSapMachineAsset.m
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

#import "MTSapMachineAsset.h"
#import "Constants.h"
#import "MTSystemInfo.h"

@interface MTSapMachineAsset ()
@property (assign) MTSapMachineJVMType jvmType;
@end

@implementation MTSapMachineAsset

- (instancetype)initWithType:(MTSapMachineJVMType)type
{
    self = [super init];
    
    if (self) {
        _jvmType = type;
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder*)aDecoder
{
    self = [self initWithType:[aDecoder decodeIntForKey:@"jvmType"]];
    
    if (self) {

        _name = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"name"];
        _jvmType = [aDecoder decodeIntForKey:@"jvmType"];
        _installedVersion = [aDecoder decodeObjectOfClass:[MTSapMachineVersion class] forKey:@"installedVersion"];
        _currentVersion = [aDecoder decodeObjectOfClass:[MTSapMachineVersion class] forKey:@"currentVersion"];
        _installURL = [aDecoder decodeObjectOfClass:[NSURL class] forKey:@"installURL"];
        _downloadURLs = [aDecoder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], [NSURL class], nil] forKey:@"downloadURLs"];
        _isEA = [aDecoder decodeBoolForKey:@"isEA"];
        _isLTS = [aDecoder decodeBoolForKey:@"isLTS"];
        _isUpdating = [aDecoder decodeBoolForKey:@"isUpdating"];
        _updateProgress = [aDecoder decodeDoubleForKey:@"updateProgress"];
   }
    
   return self;
}

- (void)encodeWithCoder:(NSCoder*)aCoder
{
    [aCoder encodeObject:_name forKey:@"name"];
    [aCoder encodeInt:_jvmType forKey:@"jvmType"];
    [aCoder encodeObject:_installedVersion forKey:@"installedVersion"];
    [aCoder encodeObject:_currentVersion forKey:@"currentVersion"];
    [aCoder encodeObject:_installURL forKey:@"installURL"];
    [aCoder encodeObject:_downloadURLs forKey:@"downloadURLs"];
    [aCoder encodeBool:_isEA forKey:@"isEA"];
    [aCoder encodeBool:_isLTS forKey:@"isLTS"];
    [aCoder encodeBool:_isUpdating forKey:@"isUpdating"];
    [aCoder encodeDouble:_updateProgress forKey:@"updateProgress"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    MTSapMachineAsset *newAsset = [[[self class] allocWithZone:zone] initWithType:_jvmType];
    
    if (newAsset) {
        
        [newAsset setName:[_name copyWithZone:zone]];
        [newAsset setInstalledVersion:[_installedVersion copyWithZone:zone]];
        [newAsset setCurrentVersion:[_currentVersion copyWithZone:zone]];
        [newAsset setInstallURL:[_installURL copyWithZone:zone]];
        [newAsset setDownloadURLs:[_downloadURLs copyWithZone:zone]];
        [newAsset setEA:_isEA];
        [newAsset setLTS:_isLTS];
        [newAsset setIsUpdating:_isUpdating];
        [newAsset setUpdateProgress:_updateProgress];
    }
    
    return newAsset;
}

- (BOOL)isInUse;
{
    BOOL inUse = NO;
    
    if ([self installURL]) {
        
        NSArray *processList = [MTSystemInfo processList];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"self CONTAINS %@", [[self installURL] path]];
        if ([[processList filteredArrayUsingPredicate:predicate] count] > 0) { inUse = YES; }
    }
    
    return inUse;
}

- (NSString*)displayName
{
    NSString *releaseName = [NSString stringWithFormat:@"%@%@",
                             _name,
                             (_isEA) ? [NSString stringWithFormat:@" (%@)", NSLocalizedString(@"preRelease", nil)] : @""];
    
    return releaseName;
}

- (NSURL*)downloadURLForCurrentArchitecture
{
    // get the correct architecture
    NSString *arch = ([[MTSystemInfo hardwareArchitecture] isEqualToString:@"x86_64"]) ? kMTSapMachineArchIntel : kMTSapMachineArchApple;
    
    NSURL *url = [_downloadURLs valueForKeyPath:[NSString stringWithFormat:@"%@.url", arch]];
    
    return url;
}

@end
