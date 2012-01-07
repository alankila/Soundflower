//
//  FrequencyResponseWindowController.h
//  Soundflowerbed
//
//  Created by Antti Lankila on 6.1.2012.
//  Copyright (c) 2012 BEL Solutions Oy. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "FrequencyResponseView.h"

@interface FrequencyResponseWindowController : NSWindowController<NSWindowDelegate> {
    IBOutlet FrequencyResponseView *responseView;
    IBOutlet NSSlider *slider1;
    IBOutlet NSSlider *slider2;
    IBOutlet NSSlider *slider3;
    IBOutlet NSSlider *slider4;
    IBOutlet NSSlider *slider5;
    IBOutlet NSSlider *slider6;
}

@end
