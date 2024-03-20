/*
     MTSapMachineAsset.h
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
#import "MTSapMachineVersion.h"

/*!
 @class         MTSapMachineAsset
 @abstract      This class describes a SapMachine asset.
*/

@interface MTSapMachineAsset : NSObject <NSSecureCoding, NSCopying>

/*!
 @enum          MTSapMachineJVMType
 @abstract      Specifies a jvm of type jre or jdk.
 @constant      MTSapMachineJVMTypeJRE Specifies a Java Runtime Environment (JRE)
 @constant      MTSapMachineJVMTypeJDK Specifies a Java Development Kit (JDK)
*/
typedef enum {
    MTSapMachineJVMTypeJRE = 0,
    MTSapMachineJVMTypeJDK = 1
} MTSapMachineJVMType;

/*!
 @property      name
 @abstract      A property to store the name of the asset.
 @discussion    The value of this property is NSString.
*/
@property (nonatomic, strong, readwrite) NSString *name;

/*!
 @property      jvmType
 @abstract      A property to store the jvm type of the asset.
 @discussion    The value of this property is MTSapMachineJVMType.
*/
@property (assign, readonly) MTSapMachineJVMType jvmType;

/*!
 @property      installedVersion
 @abstract      A property to store version information about the installed asset.
 @discussion    The value of this property is MTSapMachineVersion.
*/
@property (nonatomic, strong, readwrite) MTSapMachineVersion *installedVersion;

/*!
 @property      currentVersion
 @abstract      A property to store version information about the current version of the asset.
 @discussion    The value of this property is MTSapMachineVersion.
*/
@property (nonatomic, strong, readwrite) MTSapMachineVersion *currentVersion;

/*!
 @property      installURL
 @abstract      A property to store the url of the installed asset.
 @discussion    The value of this property is NSURL.
*/
@property (nonatomic, strong, readwrite) NSURL *installURL;

/*!
 @property      javaHomeURL
 @abstract      A property to store the home url of the installed asset.
 @discussion    This propery might be used to set the @c JAVA_HOME environment variable. The value of this property is NSURL.
*/
@property (nonatomic, strong, readwrite) NSURL *javaHomeURL;

/*!
 @property      downloadURLs
 @abstract      A property to store the available download urls (for the Mac platform) for the asset.
 @discussion    The value of this property is NSDictionary.
*/
@property (nonatomic, strong, readwrite) NSDictionary *downloadURLs;

/*!
 @property      isEA
 @abstract      A property to specify if the asset is an ea (pre-release) version.
 @discussion    The value of this property is boolean.
*/
@property (assign, setter=setEA:) BOOL isEA;

/*!
 @property      isLTS
 @abstract      A property to specify if the asset is a lts (long-term support) version.
 @discussion    The value of this property is boolean.
*/
@property (assign, setter=setLTS:) BOOL isLTS;

/*!
 @property      isUpdating
 @abstract      A property to specify if the asset is currently updated.
 @discussion    The value of this property is boolean.
*/
@property (assign) BOOL isUpdating;

/*!
 @property      updateProgress
 @abstract      A property to store the current update progress (in percent).
 @discussion    The value of this property is double.
*/
@property (assign) double updateProgress;

/*!
 @property      isVerified
 @abstract      A property to specify if the existence of the asset has been verified via Internet.
 @discussion    The value of this property is boolean.
*/
@property (assign) BOOL isVerified;

/*!
 @property      javaHomeConfigFilePaths
 @abstract      A property to specify the shell config files (like .zshenv or .bash_profile) that use the asset
                to set the @c JAVA_HOME environment variable.
 @discussion             The value of this property is array.
*/
@property (nonatomic, strong, readwrite) NSDictionary *javaHomeConfigFilePaths;

/*!
 @method        init
 @discussion    The init method is not available. Please use initWithType: instead.
*/
- (instancetype)init NS_UNAVAILABLE;

/*!
 @method        initWithType:
 @abstract      Initialize a MTSapMachineAsset object with a given jvm type.
 @param         type The type of the jvm (jre/jdk).
*/
- (instancetype)initWithType:(MTSapMachineJVMType)type NS_DESIGNATED_INITIALIZER;

/*!
 @method        isInUse
 @abstract      Returns whether an asset is currently in use or not.
 @discussion    Returns YES, if the asset is currently in use by a Java application,
                otherwise returns NO.
*/
- (BOOL)isInUse;

/*!
 @method        displayName
 @abstract      Returns the display name for the asset.
 @discussion    Returns an NSString object containing the name of the asset. For EA versions
                the name is followed by the localized form of the string "(Pre-Release)".
*/
- (NSString*)displayName;

/*!
 @method        downloadURLForCurrentArchitecture
 @abstract      Returns the asset's download url for the current architecture.
 @discussion    Returns a NSURL object or nil, if there's no install url for the current architecture.
*/
- (NSURL*)downloadURLForCurrentArchitecture;

/*!
 @method        dictionaryRepresentation
 @abstract      Returns a dictionary representation of the MTSapMachineAsset object.
*/
- (NSDictionary*)dictionaryRepresentation;

@end
