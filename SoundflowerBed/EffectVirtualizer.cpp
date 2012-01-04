/*
 * Copyright (C) 2011 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#define LOG_TAG "Effect-Virtualizer"

#include <math.h>

#include "EffectVirtualizer.h"

EffectVirtualizer::EffectVirtualizer()
    : mStrength(0)
{
    refreshStrength();
}

void EffectVirtualizer::configure(double samplingRate) {
    /* Haas effect delay */
    mReverbDelayL.setParameters(samplingRate, 0.025f);
    mReverbDelayR.setParameters(samplingRate, 0.025f);
    /* the -3 dB point is around 650 Hz, giving about 300 us to work with */
    mLocalization.setHighShelf(0, 800.0f, samplingRate, -11.0f, 0.72f, 0);

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
    mLevel = powf(10.0f, (mStrength / 100.0f - 15.0f) / 20.0f);
}

void EffectVirtualizer::process(float& dryL, float& dryR)
{
    /* calculate reverb wet into dataL, dataR */
    float dataL = dryL;
    float dataR = dryR;

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

    float center  = (dataL + dataR) * .5f;
    float side = (dataL - dataR) * .5f;

    side -= mLocalization.process(side);
    
    dryL = center + side;
    dryR = center - side;
}

