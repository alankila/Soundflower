//
//  FrequencyResponseView.h
//  Soundflowerbed
//
//  Created by Antti Lankila on 6.1.2012.
//  Copyright (c) 2012 BEL Solutions Oy. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FrequencyResponseView : NSView {
    double levels[6];
}

- (double)getLevel:(int)band;
- (void)setLevel:(double)level forBand:(int)band;
- (float)projectX:(float)x;
- (float)projectY:(float)y;

@end
