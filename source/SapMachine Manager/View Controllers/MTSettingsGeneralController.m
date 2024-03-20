/*
     MTSettingsGeneralController.m
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

#import "MTSettingsGeneralController.h"
#import "MTDaemonConnection.h"

@interface MTSettingsGeneralController ()
@property (nonatomic, strong, readwrite) MTDaemonConnection *daemonConnection;

@property (weak) IBOutlet NSButton *autoUpdateCheckbox;
@end

@implementation MTSettingsGeneralController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [_autoUpdateCheckbox setState:NSControlStateValueOff];
    [_autoUpdateCheckbox setEnabled:NO];
    
    _daemonConnection = [[MTDaemonConnection alloc] init];
    
    [_daemonConnection connectToDaemonWithExportedObject:nil
                                  andExecuteCommandBlock:^{

        [[[self->_daemonConnection connection] remoteObjectProxyWithErrorHandler:^(NSError *error) {
            
            os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_FAULT, "SAPCorp: Failed to connect to daemon: %{public}@", error);
            
        }] automaticUpdatesEnabledWithReply:^(BOOL enabled, BOOL forced) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self->_autoUpdateCheckbox setState:(enabled) ? NSControlStateValueOn : NSControlStateValueOff];
                [self->_autoUpdateCheckbox setEnabled:!forced];
            });
            
        }];
    }];
}

- (IBAction)setAutoUpdate:(id)sender
{
    [_daemonConnection connectToDaemonWithExportedObject:nil
                                  andExecuteCommandBlock:^{

        NSControlStateValue checkboxState = [self->_autoUpdateCheckbox state];

        [[self->_daemonConnection remoteObjectProxy] setAutomaticUpdatesEnabled:(checkboxState == NSControlStateValueOn) ? YES : NO completionHandler:^(BOOL success) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                // revert the checkbox if the operation failed
                if (!success) {
                    [self->_autoUpdateCheckbox setState:(checkboxState == NSControlStateValueOn) ? NSControlStateValueOff : NSControlStateValueOn];
                }
            });
            
        }];
    }];
}

@end
