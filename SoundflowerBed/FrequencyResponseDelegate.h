//
//  FrequencyResponseDelegate.h
//  Soundflowerbed
//
//  Created by Antti Lankila on 8.1.2012.
//  Copyright (c) 2012 BEL Solutions Oy. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FrequencyResponseDelegate <NSObject>

- (void)frequencyResponseChanged:(float)dB forBand:(int)band;

@end
