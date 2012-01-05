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

#define LOG_TAG "Effect-Equalizer"

#include "EffectEqualizer.h"

#include <math.h>

EffectEqualizer::EffectEqualizer()
    : mLoudnessAdjustment(10000.f), mLoudness(50.f), mNextUpdate(0), mNextUpdateInterval(1000), mPowerSquared(0)
{
    for (int32_t i = 0; i < 6; i ++) {
        mBand[i] = 0;
    }
}

void EffectEqualizer::configure(double sampleRate) {
    mSamplingRate = sampleRate;
    /* 100 updates per second. */
    mNextUpdateInterval = int32_t(mSamplingRate / 100.);
}

void EffectEqualizer::setBand(int32_t band, float dB) {
    mBand[band] = dB;
}

void EffectEqualizer::setLoudnessCorrection(int16_t dB) {
    mLoudnessAdjustment = dB;
}

/* Source material: ISO 226:2003 curves.
 *
 * On differencing 100 dB curves against 80 dB, 60 dB, 40 dB and 20 dB, a pattern
 * can be established where each loss of 20 dB of power in signal suggests gradually
 * decreasing ear sensitivity, until the bottom is reached at 20 dB SPL where no more
 * boosting is required. Measurements end at 100 dB, which is assumed to be the reference
 * sound pressure level.
 *
 * The boost can be calculated as linear scaling of the following adjustment:
 *     20 Hz +41 dB
 *   62.5 Hz +28 dB
 *    250 Hz +10 dB
 *   1000 Hz   0 dB
 *   4000 Hz  -3 dB
 *  16000 Hz  +8 dB
 *
 * The boost will be applied maximally for signals of 20 dB and less,
 * and linearly decreased for signals 20 dB ... 100 dB, and no adjustment is
 * made for 100 dB or higher. User must configure a reference level that maps the
 * digital sound level against the audio.
 */
float EffectEqualizer::getAdjustedBand(int32_t band) {
    /* 1st derived by linear extrapolation from (62.5, 28) to (20, 41) */
    const float adj[6] = { 42.3, 28.0, 10.0, 0.0, -3.0, 8.0 };

    /* The 15.625 band is not exposed externally, so first point is duplicated. */
    float f = mBand[band];

    /* Add loudness adjustment */
    float loudnessLevel = mLoudness + mLoudnessAdjustment;
    if (loudnessLevel > 100.f) {
        loudnessLevel = 100.f;
    }
    if (loudnessLevel < 20.f) {
        loudnessLevel = 20.f;
    }
    /* Maximum loudness = no adj (reference behavior at 100 dB) */
    loudnessLevel = (loudnessLevel - 20) / (100 - 20);
    f += adj[band] * (1. - loudnessLevel);

    return f;
}

void EffectEqualizer::refreshBands()
{
    for (int32_t band = 0; band < 5; band ++) {
        /* 15.625, 62.5, 250, 1000, 4000, 16000 */
        float centerFrequency = 15.625f * powf(4, band);
        float dB = getAdjustedBand(band + 1) - getAdjustedBand(band);

        float overallGain = band == 0 ? getAdjustedBand(0) : 0.0f;

        mFilterL[band].setHighShelf(mNextUpdateInterval, centerFrequency * 2.0f, mSamplingRate, dB, 1.0f, overallGain);
        mFilterR[band].setHighShelf(mNextUpdateInterval, centerFrequency * 2.0f, mSamplingRate, dB, 1.0f, overallGain);
    }
}

void EffectEqualizer::process(float& tmpL, float& tmpR)
{
    if (mNextUpdate == 0) {
        float signalPowerDb = logf(mPowerSquared / mNextUpdateInterval + 1e-10f) / logf(10.0f) * 10.0f;
        signalPowerDb += 96.0f - 6.0f;

        /* Immediate rise-time, and linear 10 dB/s decay */
        if (mLoudness > signalPowerDb + 0.1) {
            mLoudness -= 0.1;
        } else {
            mLoudness = signalPowerDb;
        }

        /* Update EQ. */
        refreshBands();

        mNextUpdate = mNextUpdateInterval;
        mPowerSquared = 0;
    }
    mNextUpdate --;

    /* Calculate signal loudness estimate.
     * XXX: should we be independent per channel? */
    float weight = tmpL + tmpR;
    mPowerSquared += weight * weight;

    /* evaluate the other filters. */
    for (int32_t j = 0; j < 5; j ++) {
        tmpL = mFilterL[j].process(tmpL);
        tmpR = mFilterR[j].process(tmpR);
    }
}
