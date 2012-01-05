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
