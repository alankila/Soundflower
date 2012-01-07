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
    [super awakeFromNib];
}

- (void)windowDidLoad {
    [self retain];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self release];
}

@end
