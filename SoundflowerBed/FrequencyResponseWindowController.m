//
//  FrequencyResponseWindowController.m
//  Soundflowerbed
//
//  Created by Antti Lankila on 6.1.2012.
//  Copyright (c) 2012 BEL Solutions Oy. All rights reserved.
//

#import "FrequencyResponseWindowController.h"

@implementation FrequencyResponseWindowController

- (void)setEqualizerDelegate:(id<FrequencyResponseDelegate>)object {
    delegate = object;
}

- (void)positionSliders {
    NSSlider *sl[6] = { slider1, slider2, slider3, slider4, slider5, slider6 };
    for (int i = 0; i < 6; i ++) {
        float freq = 15.625f * powf(4, i);
        float pos = [responseView projectX:freq];
        NSRect f = sl[i].frame;
        NSRect n = { pos - f.size.width / 2, 0, f.size.width, f.size.height };
        sl[i].frame = n;
    }
    
    NSTextField *db[5] = { labelm12, labelm6, label0, labelp6, labelp12 };
    for (int i = 0; i < 5; i ++) {
        float value = -12 + 6 * i;
        float pos = [responseView projectY:value];
        NSRect f = db[i].frame;
        NSRect n = { 0, pos - f.size.height, f.size.width, f.size.height };
        db[i].frame = n;
    }
    
    NSTextField *hz[4] = { labelHz10, labelHz100, labelHz1000, labelHz10000 };
    for (int i = 0; i < 4; i ++) {
        float freq = powf(10, i + 1);
        float pos = [responseView projectX:freq];
        NSRect f = hz[i].frame;
        NSRect n = { pos, 0, f.size.width, f.size.height };
        hz[i].frame = n;
    }
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self positionSliders];

    NSSlider *arr[6] = { slider1, slider2, slider3, slider4, slider5, slider6 };
    for (int i = 0; i < 6; i ++) {
        arr[i].minValue = -12;
        arr[i].maxValue = 12;
        arr[i].doubleValue = mLevels[i];
        [responseView setLevel:mLevels[i] forBand:i];
        [arr[i] setContinuous:YES];
    }
}

- (void)setLevels:(float *)levels {
    NSSlider *arr[6] = { slider1, slider2, slider3, slider4, slider5, slider6 };
    for (int i = 0; i < 6; i ++) {
        mLevels[i] = levels[i];
        arr[i].doubleValue = mLevels[i];
        [responseView setLevel:mLevels[i] forBand:i];
    }
}

- (void)windowDidResize:(NSNotification *)notification {
    [self positionSliders];
}

- (IBAction)sliderMoved:(id)sender {
    NSSlider *arr[6] = { slider1, slider2, slider3, slider4, slider5, slider6 };
    for (int i = 0; i < 6; i ++) {
        if (arr[i] == sender) {
            [responseView setLevel:arr[i].doubleValue forBand:i];
            [delegate frequencyResponseChanged:arr[i].floatValue forBand:i];
        }
    }
}

@end
