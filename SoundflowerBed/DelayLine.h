#pragma once

#include <stdint.h>

class DelayLine {
    double* mState;
    int32_t mIndex;
    int32_t mLength;

    public:
    DelayLine();
    ~DelayLine();
    void setParameters(double rate, double time);
    double process(double x0);
};