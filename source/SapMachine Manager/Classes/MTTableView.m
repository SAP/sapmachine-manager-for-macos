/*
     MTTableView.m
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

#import "MTTableView.h"
#import "MTSapMachineUser.h"
#import "MTSapMachineAsset.h"
#import "Constants.h"

@implementation MTTableView

- (NSMenu *)menuForEvent:(NSEvent *)event
{
    [super menuForEvent:event];
    
    NSMenu *theMenu = nil;
    NSInteger clickedRow = [self clickedRow];

    if (clickedRow >= 0) {
                
        // add an item for deleting one or more assets
        NSMenuItem *removeItem = [[self menu] itemWithTag:2000];
        
        if ([[self selectedRowIndexes] containsIndex:clickedRow] && [[self selectedRowIndexes] count] > 1) {
            [removeItem setTitle:[NSString localizedStringWithFormat:NSLocalizedString(@"deleteSelectedMenuEntry", nil), [[self selectedRowIndexes] count]]];
        } else {
            [removeItem setTitle:NSLocalizedString(@"deleteOneMenuEntry", nil)];
        }
        
        NSMenuItem *javaHomeItem = [[self menu] itemWithTag:1100];
        [javaHomeItem setAction:nil];
        
        if ([[self selectedRowIndexes] count] == 0 || 
            ([[self selectedRowIndexes] count] == 1 && [[self selectedRowIndexes] containsIndex:clickedRow]) ||
            ([[self selectedRowIndexes] count] >= 1 && ![[self selectedRowIndexes] containsIndex:clickedRow])) {
            
            NSTableCellView *cellView = [self viewAtColumn:0 row:clickedRow makeIfNecessary:NO];
            
            if (cellView) {
                
                MTSapMachineAsset *asset = (MTSapMachineAsset*)[cellView objectValue];
                
                if (asset && [[[asset javaHomeConfigFilePaths] allKeys] count] == 0) {
                    [javaHomeItem setAction:NSSelectorFromString(@"setJavaHome:")];
                }
            }
        }

        theMenu = [self menu];
    }
    
    return theMenu;
}

@end
