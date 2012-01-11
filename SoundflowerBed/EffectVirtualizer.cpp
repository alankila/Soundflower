#include <math.h>

#include "EffectVirtualizer.h"

EffectVirtualizer::EffectVirtualizer()
    : mStrength(0)
{
    refreshStrength();
}

void EffectVirtualizer::configure(double samplingRate) {
    /* Haas effect delay */
    mReverbDelayL.setParameters(samplingRate, 0.025);
    mReverbDelayR.setParameters(samplingRate, 0.025);
    /* the -3 dB point is around 650 Hz, giving about 300 us to work with */
    mLocalization.setHighShelf(0, 800.0, samplingRate, -11.0, 0.72, 0);

    mDelayDataL = 0;
    mDelayDataR = 0;
}

void EffectVirtualizer::setStrength(int16_t strength) {
    mStrength = strength;
    refreshStrength();
}

void EffectVirtualizer::refreshStrength()
{
    mDeep = mStrength != 0;
    mWide = mStrength >= 500;

    /* -15 .. -5 dB */
    mLevel = pow(10.0, (mStrength / 100.0 - 15.0) / 20.0);
}

void EffectVirtualizer::process(double& dryL, double& dryR)
{
    /* calculate reverb wet into dataL, dataR */
    double dataL = dryL;
    double dataR = dryR;

    if (mDeep) {
        /* Note: a pinking filter here would be good. */
        dataL += mDelayDataR;
        dataR += mDelayDataL;
    }

    dataL = mReverbDelayL.process(dataL);
    dataR = mReverbDelayR.process(dataR);

    if (mWide) {
        dataR = -dataR;
    }

    dataL = dataL * mLevel;
    dataR = dataR * mLevel;

    mDelayDataL = dataL;
    mDelayDataR = dataR;

    /* Reverb wet done; mix with dry and do headphone virtualization */
    dataL += dryL;
    dataR += dryR;

    double center  = (dataL + dataR) * .5;
    double side = (dataL - dataR) * .5;

    side -= mLocalization.process(side);
    
    dryL = center + side;
    dryR = center - side;
}

