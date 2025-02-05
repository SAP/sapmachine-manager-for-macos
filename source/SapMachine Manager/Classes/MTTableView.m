/*
     MTTableView.m
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
    NSIndexSet *selectedRowIndexes = [self selectedRowIndexes];
    NSInteger numberOfSelectedRows = [selectedRowIndexes count];

    if (clickedRow >= 0) {
        
        // add an item for deleting one or more assets
        NSMenuItem *removeItem = [[self menu] itemWithTag:3000];
        
        if ([selectedRowIndexes containsIndex:clickedRow] && numberOfSelectedRows > 1) {
            [removeItem setTitle:[NSString localizedStringWithFormat:NSLocalizedString(@"deleteSelectedMenuEntry", nil), numberOfSelectedRows]];
        } else {
            [removeItem setTitle:NSLocalizedString(@"deleteOneMenuEntry", nil)];
        }
        
        // add an item for updating one or more assets
        NSMenuItem *updateItem = [[self menu] itemWithTag:2000];
        
        NSIndexSet *toBeUpdated = nil;
        
        if (clickedRow == NSUIntegerMax || [selectedRowIndexes containsIndex:clickedRow]) {
            toBeUpdated = selectedRowIndexes;
        } else {
            toBeUpdated = [NSIndexSet indexSetWithIndex:clickedRow];
        }
        
        __block NSInteger selectedUpdateAssets = ([selectedRowIndexes containsIndex:clickedRow] && numberOfSelectedRows > 1) ? numberOfSelectedRows : 1;

        [toBeUpdated enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            
            NSTableCellView *cellView = [self viewAtColumn:0 row:idx makeIfNecessary:NO];
            
            if (cellView) {
                
                MTSapMachineAsset *asset = (MTSapMachineAsset*)[cellView objectValue];
                if (!asset || ([[asset currentVersion] compare:[asset installedVersion]] != NSOrderedDescending) || [[asset downloadURLs] count] == 0) { selectedUpdateAssets--; }
            }
        }];

        if (selectedUpdateAssets > 0) {
            [updateItem setAction:NSSelectorFromString(@"updateAsset:")];
        } else {
            [updateItem setAction:nil];
        }
        
        if (selectedUpdateAssets > 1) {
            [updateItem setTitle:[NSString localizedStringWithFormat:NSLocalizedString(@"updateSelectedMenuEntry", nil), selectedUpdateAssets]];
        } else {
            [updateItem setTitle:NSLocalizedString(@"updateOneMenuEntry", nil)];
        }
        
        NSMenuItem *javaHomeItem = [[self menu] itemWithTag:1100];
        [javaHomeItem setAction:nil];
        
        if (numberOfSelectedRows == 0 ||
            (numberOfSelectedRows == 1 && [selectedRowIndexes containsIndex:clickedRow]) ||
            (numberOfSelectedRows >= 1 && ![selectedRowIndexes containsIndex:clickedRow])) {
            
            NSTableCellView *cellView = [self viewAtColumn:0 row:clickedRow makeIfNecessary:NO];
            
            if (cellView) {
                
                MTSapMachineAsset *asset = (MTSapMachineAsset*)[cellView objectValue];
                
                if (asset && [[[asset javaHomeConfigFilePaths] allKeys] count] == 0) {
                    [javaHomeItem setAction:NSSelectorFromString(@"setJavaHome:")];
                } else {
                    [javaHomeItem setAction:nil];
                }
            }
        }

        theMenu = [self menu];
    }
    
    return theMenu;
}

@end
