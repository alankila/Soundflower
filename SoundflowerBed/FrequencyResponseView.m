//
//  FrequencyResponseView.m
//  Soundflowerbed
//
//  Created by Antti Lankila on 6.1.2012.
//  Copyright (c) 2012 BEL Solutions Oy. All rights reserved.
//

#import "FrequencyResponseView.h"

@implementation FrequencyResponseView

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor whiteColor] set];
    [NSBezierPath fillRect:dirtyRect];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

@end
