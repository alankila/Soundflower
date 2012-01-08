//
//  FrequencyResponseView.m
//  Soundflowerbed
//
//  Created by Antti Lankila on 6.1.2012.
//  Copyright (c) 2012 BEL Solutions Oy. All rights reserved.
//

#import "FrequencyResponseView.h"

#include <complex.h>

@implementation FrequencyResponseView

- (double)getLevel:(int)band {
    return levels[band];
}

- (void)setLevel:(double)level forBand:(int)band {
    levels[band] = level;
    [self setNeedsDisplay:YES];
}

- (double)computeTransfer:(complex double)z forBiquad:(double *)biquad {
    complex double z2 = z * z;
    complex double nom = biquad[0] + biquad[1] / z + biquad[2] / z2;
    complex double dem = biquad[3] + biquad[4] / z + biquad[5] / z2;
    return cabs(nom / dem);
}

- (float)projectY:(float)y {
    return (1 + y / 12.0f) * (self.frame.size.height / 2.0f);
}

- (float)projectX:(float)x {
    float p = logf(x);
    float xmin = logf(10);
    float xmax = logf(20000);
    
    return (p - xmin) / (xmax - xmin) * self.bounds.size.width;
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor whiteColor] set];
    [NSBezierPath fillRect:self.bounds];
    
    NSSize size = self.bounds.size;
    for (int i = -12; i <= 12; i += 3) {
        float y = [self projectY:i];
        NSPoint p1 = { 0, y }, p2 = { size.width, y };
        if ((i % 6) == 0) {
            [[NSColor blackColor] set];
        } else {
            [[NSColor grayColor] set];
        }
        [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
    }
    for (int i = 10; i < 20000;) {
        float x = [self projectX:i];
        NSPoint p1 = { x, 0 }, p2 = { x, size.height };

        float scale = log(i) / log(10);
        if (fabsf(scale - roundf(scale)) < 1e-10f) {
            [[NSColor blackColor] set];
        } else {
            [[NSColor grayColor] set];
        }
        
        [NSBezierPath strokeLineFromPoint:p1 toPoint:p2];
        
        if (i < 100) {
            i += 10;
        } else if (i < 1000) {
            i += 100;
        } else if (i < 10000) {
            i += 1000;
        } else if (i < 100000) {
            i += 10000;
        }
    }
    
    double bq[5][6];
    double gain = pow(10, levels[0] / 20);
    for (int i = 0; i < 5; i ++) {
        /* These are the parameters for a high shelf filter */
        double centerFrequency = 2 * 15.625 * pow(4, i);
        double samplingFrequency = 44100;
        double dbGain = levels[i + 1] - levels[i];
        double slope = 1;

        /* Stock cookbook formula for a high shelf filter */
        double w0 = 2 * M_PI * centerFrequency / samplingFrequency;
        double A = pow(10, dbGain/40);
        double alpha = sin(w0)/2 * sqrt( (A + 1/A)*(1/slope - 1) + 2);
        
        /* b0-b2 */
        bq[i][0] = A*((A+1) + (A-1)   *cos(w0) + 2*sqrt(A)*alpha);
        bq[i][1] = -2*A*((A-1) + (A+1)*cos(w0));
        bq[i][2] = A*((A+1) + (A-1)   *cos(w0) - 2*sqrt(A)*alpha);
        /* a0-a2 */
        bq[i][3] = (A+1) - (A-1)      *cos(w0) + 2*sqrt(A)*alpha;
        bq[i][4] = 2*((A-1) - (A+1)   *cos(w0));
        bq[i][5] = (A+1) - (A-1)      *cos(w0) - 2*sqrt(A)*alpha;
    }    
    
    /* Now draw frequency response */
    NSBezierPath *path = [[NSBezierPath alloc] init];
    for (double f = 10; f < 20000 * 1.1; f *= 1.1) {
        double nf = f / 44100 * 2 * M_PI;
        complex double omega = cos(nf) + sin(nf) * 1j;
        double f1 = [self computeTransfer:omega forBiquad:bq[0]];
        double f2 = [self computeTransfer:omega forBiquad:bq[1]];
        double f3 = [self computeTransfer:omega forBiquad:bq[2]];
        double f4 = [self computeTransfer:omega forBiquad:bq[3]];
        double f5 = [self computeTransfer:omega forBiquad:bq[4]];

        double level = gain * f1 * f2 * f3 * f4 * f5;
        double dB = log(level) / log(10) * 20;

        NSPoint p = { [self projectX:f], [self projectY:dB] };
        if (f == 10) {
            [path moveToPoint:p];
        } else {
            [path lineToPoint:p];
        }
    }
    [[NSColor redColor] set];
    [path stroke];
    [path release];
}

@end
