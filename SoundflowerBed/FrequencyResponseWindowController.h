//
//  FrequencyResponseWindowController.h
//  Soundflowerbed
//
//  Created by Antti Lankila on 6.1.2012.
//  Copyright (c) 2012 BEL Solutions Oy. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "FrequencyResponseDelegate.h"
#import "FrequencyResponseView.h"

@interface FrequencyResponseWindowController : NSWindowController<NSWindowDelegate> {
    IBOutlet NSWindow *window;
    
    IBOutlet FrequencyResponseView *responseView;
    IBOutlet NSSlider *slider1;
    IBOutlet NSSlider *slider2;
    IBOutlet NSSlider *slider3;
    IBOutlet NSSlider *slider4;
    IBOutlet NSSlider *slider5;
    IBOutlet NSSlider *slider6;
    
    IBOutlet NSTextField *labelp12;
    IBOutlet NSTextField *labelp6;
    IBOutlet NSTextField *label0;
    IBOutlet NSTextField *labelm6;
    IBOutlet NSTextField *labelm12;
    
    IBOutlet NSTextField *labelHz10;
    IBOutlet NSTextField *labelHz100;
    IBOutlet NSTextField *labelHz1000;
    IBOutlet NSTextField *labelHz10000;
    
    double mLevels[6];
    id<FrequencyResponseDelegate> delegate;
}

- (void)setEqualizerDelegate:(id<FrequencyResponseDelegate>)object;
- (void)setLevels:(float *)levels;

- (IBAction)sliderMoved:(id)sender;

@end
