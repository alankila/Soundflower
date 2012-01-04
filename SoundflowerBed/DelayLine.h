#pragma once

#include <stdint.h>

class DelayLine {
    float* mState;
    int32_t mIndex;
    int32_t mLength;

    public:
    DelayLine();
    ~DelayLine();
    void setParameters(float rate, float time);
    float process(float x0);
};