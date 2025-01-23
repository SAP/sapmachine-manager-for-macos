/*
     Constants.h
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

#define kMTJavaHomePath                     @"/usr/libexec/java_home"
#define kMTUnarchiverPath                   @"/usr/bin/tar"
#define kMTJVMFolderPath                    @"/Library/Java/JavaVirtualMachines"
#define kMTSapMachineReleasesURL            @"https://sap.github.io/SapMachine/assets/data/sapmachine-releases-latest.json"
#define kMTGitHubURL                        @"https://github.com/SAP/sapmachine-manager-for-macos"
#define kMTSapMachineWebsiteURL             @"https://sapmachine.io/"
#define kMTErrorDomain                      @"corp.sap.SapMachineManager.ErrorDomain"
#define kMTDaemonPlistName                  @"corp.sap.SMUDaemon.plist"
#define kMTDaemonMachServiceName            @"corp.sap.SapMachineManager.xpc"
#define kMTAppBundleIdentifier              @"corp.sap.SapMachineManager"
#define kMTMaxConcurrentOperations          2
#define kMTAdminGroupID                     80

#define kMTJVMTypeJRE                       @"jre"
#define kMTJVMTypeJDK                       @"jdk"

#define kMTSapMachineJDKIdentifier          @"com.sap.openjdk.jdk"
#define kMTSapMachineJREIdentifier          @"com.sap.openjdk.jre"
#define kMTSapMachineArchIntel              @"macos-x64"
#define kMTSapMachineArchApple              @"macos-aarch64"

// NSUserDefaults
#define kMTDefaultsSettingsSelectedTabKey   @"SettingsSelectedTab"
#define kMTDefaultsInstallErrorKey          @"InstallError"
#define kMTDefaultsDontRequireAdminKey      @"DontRequireAdminUser"
#define kMTDefaultsLogDetailsEnabledKey     @"LogDetailsEnabled"
#define kMTDefaultsLogDividerPositionKey    @"LogSplitViewDividerPosition"
#define kMTDefaultsNoUpgradeAlertsKey       @"SuppressUpgradeAlerts"
#define kMTDefaultsNoUpgradeDeleteKey       @"DontDeleteAfterUpgrade"

// CFPreferences
#define kMTDaemonPreferenceDomain           CFSTR("corp.sap.SMUDaemon")
#define kMTPrefsEnableAutoUpdateKey         CFSTR("AutomaticUpdatesEnabled")
#define kMTPrefsLastUpdateSuccessKey        CFSTR("LastSuccessfulUpdate")
#define kMTPrefsLastCheckSuccessKey         CFSTR("LastSuccessfulCheck")

// Notifications
#define kMTNotificationKeyLogMessage        @"LogMessage"
#define kMTNotificationKeyInstallError      @"InstallError"

#define kMTNotificationNameLogMessage       @"corp.sap.SapMachineManager.LogMessage"
#define kMTNotificationNameShowLog          @"corp.sap.SapMachineManager.ShowLog"
#define kMTNotificationNameInstallFinished  @"corp.sap.SapMachineManager.InstallFinished"
