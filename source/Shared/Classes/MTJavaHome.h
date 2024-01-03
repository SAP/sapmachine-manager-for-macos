/*
     MTJavaHome.h
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

#import <Foundation/Foundation.h>

/*!
 @class         MTJavaHome
 @abstract      This class provides methods to get information about the Java Virtual Machines
                currently installed on the machine.
*/

@interface MTJavaHome : NSObject

/*!
 @method        installedJVMsWithCompletionHandler:
 @abstract      Returns all installed Java Virtual Machines.
 @param         completionHandler The completion handler to call when the request is complete.
 @discussion    Returns an NSArray containing a NSDictionary for each installed jvm
                or nil if an error occurred.
*/
+ (void)installedJVMsWithCompletionHandler:(void (^) (NSArray *installedJVMs))completionHandler;

/*!
 @method        installedJVMsFilteredByBundleID:
 @abstract      Returns all installed Java Virtual Machines using the given bundle identifers.
 @param         bundleID An array of bundle identifiers.
 @param         completionHandler The completion handler to call when the request is complete.
 @discussion    Returns an NSArray containing a NSDictionary for each installed jvm
                matching one of the given bundle identifiers or nil if an error occurred.
*/
+ (void)installedJVMsFilteredByBundleID:(NSArray*)bundleID completionHandler:(void (^) (NSArray *array))completionHandler;

/*!
 @method        configFilesWithUserName:userOnly:recommendedOnly:
 @abstract      Returns all installed Java Virtual Machines using the given bundle identifers.
 @param         userName The name of the user to get the config files for.
 @param         userOnly If set to YES, only the config files that belong to the user are returned, 
                otherwise also system-wide config files are returned.
 @param         recommendedOnly If set to YES, only the files recommended to set the @c JAVA_HOME
                environment variable (for each supported shell) are returned. Otherwise the paths of all
                config files (for each supported shell) are returned.
 @discussion    Returns an NSDictionary containing the paths to the config files of the supported shells.
*/
+ (NSDictionary*)configFilesWithUserName:(NSString*)userName userOnly:(BOOL)userOnly recommendedOnly:(BOOL)recommendedOnly;

/*!
 @method        environmentVariableAtPath:
 @abstract      Returns the content of the @c JAVA_HOME environment variable for config file at the given path.
 @param         path The path to the config file (like @c /etc/zshenv or @c /Users/xyz/.zshenv).
 @discussion    Returns the file url of the jvm configured in the @c JAVA_HOME environment variable  or nil if the variable is not set
                or if an error occurred.
*/
+ (NSString*)environmentVariableAtPath:(NSString*)path;

/*!
 @method        setEnvironmentVariableAtPaths:usingJVMPath:completionHandler:
 @abstract      Sets  the @c JAVA_HOME environment variable at the given paths to the given jvm path.
 @param         paths The paths to the files the environment variable should be set..
 @param         jvmPath The path to the jvm that should be used for the environment variable.
 @param         completionHandler The completion handler to call when the request is complete.
 @discussion    Returns YES if the given files have been changed successfully, otherwise returns NO.
*/
+ (void)setEnvironmentVariableAtPaths:(NSArray*)paths usingJVMPath:(NSString*)jvmPath completionHandler:(void (^) (BOOL success))completionHandler;

/*!
 @method        unsetEnvironmentVariableAtPaths:completionHandler:
 @abstract      Returns the content of the @c JAVA_HOME environment variable for the shell at the given path and the given user.
 @param         paths The path to the shell (like @c /bin/bash or @c /bin/zsh).
 @param         completionHandler The completion handler to call when the request is complete.
 @discussion    Returns the file url of the jvm configured in the @c JAVA_HOME environment variable  or nil if the variable is not set
                or if an error occurred.
*/
+ (void)unsetEnvironmentVariableAtPaths:(NSArray*)paths completionHandler:(void (^) (NSArray *changedFiles))completionHandler;

@end
