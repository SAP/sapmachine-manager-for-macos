/*
     MTSapMachineVersion.h
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

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/*!
 @class         MTSapMachineVersion
 @abstract      This class provides a properties and methods to deal with SapMachine version numbers.
*/

@interface MTSapMachineVersion : NSObject <NSSecureCoding, NSCopying>

/*!
 @property      versionString
 @abstract      A property that holds the version string.
 @discussion    This property holds a cleanded version of the version string the object has
                been initialized with. The cleaned version contains only of numbers, dots and "+"
                signs. The value of this property is NSString.
*/
@property (nonatomic, strong, readonly) NSString *versionString;

/*!
 @property      normalizedVersionString
 @abstract      A property that holds a normalized version of the version string.
 @discussion    The normalized version string always consist of 6 digits separated by dots.
                The value of this property is NSString.
*/
@property (nonatomic, strong, readonly) NSString *normalizedVersionString;

/*!
 @property      majorVersion
 @abstract      A property that holds the major version of the version string.
 @discussion    The value of this property is NSUInteger.
*/
@property (assign, readonly) NSUInteger majorVersion;

/*!
 @method        initWithVersionString:
 @abstract      Initialize a MTSapMachineVersion object with a given version string.
 @param         versionString The version string of a SapMachine release.
*/
- (instancetype)initWithVersionString:(NSString*)versionString;

/*!
 @method        compare:
 @abstract      Compares the MTSapMachineVersion object with the given MTSapMachineVersion object.
 @param         version The MTSapMachineVersion object with which to compare the receiver.
 @discussion    Returns an NSComparisonResult value that indicates the lexical ordering. Returns
                NSOrderedAscending if the receiver's normalizedVersionString precedes the given object's
                normalizedVersionString in lexical ordering, NSOrderedSame if the receiver's normalizedVersionString
                and given object's normalizedVersionString are equivalent in lexical value, and NSOrderedDescending
                if the receiver's normalizedVersionString follows the given object's normalizedVersionString.
*/
- (NSComparisonResult)compare:(MTSapMachineVersion*)version;

/*!
 @method        dictionaryRepresentation
 @abstract      Returns a dictionary representation of the MTSapMachineVersion object.
*/
- (NSDictionary*)dictionaryRepresentation;

@end
