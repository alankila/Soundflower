//
//  FrequencyResponseView.h
//  Soundflowerbed
//
//  Created by Antti Lankila on 6.1.2012.
//  Copyright (c) 2012 BEL Solutions Oy. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FrequencyResponseView : NSView {
    float levels[6];
}

- (void)setLevel:(float)level forBand:(int)band;

@end
