#pragma once

#include "Biquad.h"
#include "DelayLine.h"

class EffectVirtualizer {
    private:
    int16_t mStrength;

    bool mDeep, mWide;
    double mLevel;

    DelayLine mReverbDelayL, mReverbDelayR;
    double mDelayDataL, mDelayDataR;
    Biquad mLocalization;

    void refreshStrength();

    public:
    EffectVirtualizer();
    
    void configure(double sampleRate);
    void setStrength(int16_t strength);

    void process(double& left, double& right);
};
