#pragma once

#include "Biquad.h"
#include "DelayLine.h"

class EffectVirtualizer {
    private:
    int16_t mStrength;

    bool mDeep, mWide;
    float mLevel;

    DelayLine mReverbDelayL, mReverbDelayR;
    float mDelayDataL, mDelayDataR;
    Biquad mLocalization;

    void refreshStrength();

    public:
    EffectVirtualizer();
    
    void configure(double sampleRate);
    void setStrength(int16_t strength);

    void process(float& left, float& right);
};
