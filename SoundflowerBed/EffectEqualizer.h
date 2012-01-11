#pragma once

#include "Biquad.h"

class EffectEqualizer {
    private:
    double mSamplingRate;
    double mBand[6];
    Biquad mFilterL[5], mFilterR[5];

    /* Automatic equalizer */
    double mLoudnessAdjustment;

    double mLoudness;
    int32_t mNextUpdate;
    int32_t mNextUpdateInterval;
    double mPowerSquared;

    double getAdjustedBand(int32_t idx);
    void refreshBands();

    public:
    EffectEqualizer();
    
    void configure(double sampleRate);
    void setBand(int32_t band, double dB);
    void setLoudnessCorrection(int16_t level);
    void process(double& left, double& right);
};
