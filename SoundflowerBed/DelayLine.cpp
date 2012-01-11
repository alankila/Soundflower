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

void DelayLine::setParameters(double samplingFrequency, double time)
{
    mLength = int32_t(time * samplingFrequency + 0.5f);
    if (mState != 0) {
        delete[] mState;
    }
    mState = new double[mLength];
    memset(mState, 0, mLength * sizeof(double));
    mIndex = 0;
}

double DelayLine::process(double x0)
{
    double y0 = mState[mIndex];
    mState[mIndex] = x0;
    mIndex = (mIndex + 1) % mLength;
    return y0;
}
