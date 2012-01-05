//
//  FrequencyResponseWindowController.m
//  Soundflowerbed
//
//  Created by Antti Lankila on 6.1.2012.
//  Copyright (c) 2012 BEL Solutions Oy. All rights reserved.
//

#import "FrequencyResponseWindowController.h"

@implementation FrequencyResponseWindowController

- (void)awakeFromNib {
    
}

- (void)doFrequencyResponseWindow {
	[self showWindow:[self window]];
	[NSApp activateIgnoringOtherApps:YES];
}

@end
