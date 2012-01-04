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

#include "DelayLine.h"

#include <string.h>

DelayLine::DelayLine()
    : mState(0), mIndex(0), mLength(0)
{
}

DelayLine::~DelayLine()
{
    if (mState != 0) {
        delete[] mState;
        mState = 0;
    }
}

void DelayLine::setParameters(float samplingFrequency, float time)
{
    mLength = int32_t(time * samplingFrequency + 0.5f);
    if (mState != 0) {
        delete[] mState;
    }
    mState = new float[mLength];
    memset(mState, 0, mLength * sizeof(float));
    mIndex = 0;
}

float DelayLine::process(float x0)
{
    float y0 = mState[mIndex];
    mState[mIndex] = x0;
    mIndex = (mIndex + 1) % mLength;
    return y0;
}
