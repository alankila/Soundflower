#pragma once

#include "Biquad.h"

class EffectEqualizer {
    private:
    float mSamplingRate;
    float mBand[6];
    Biquad mFilterL[5], mFilterR[5];

    /* Automatic equalizer */
    float mLoudnessAdjustment;

    float mLoudness;
    int32_t mNextUpdate;
    int32_t mNextUpdateInterval;
    int64_t mPowerSquared;

    /* Smooth enable/disable */
    int32_t mFade;

    float getAdjustedBand(int32_t idx);
    void refreshBands();

    public:
    EffectEqualizer();
    
    void configure(double sampleRate);
    void setBand(int32_t band, float dB);
    void setLoudnessCorrection(int16_t level);
    void process(float& left, float& right);
};
