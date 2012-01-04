/*	Copyright: 	© Copyright 2004 Apple Computer, Inc. All rights reserved.

	Disclaimer:	IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc.
			("Apple") in consideration of your agreement to the following terms, and your
			use, installation, modification or redistribution of this Apple software
			constitutes acceptance of these terms.  If you do not agree with these terms,
			please do not use, install, modify or redistribute this Apple software.

			In consideration of your agreement to abide by the following terms, and subject
			to these terms, Apple grants you a personal, non-exclusive license, under Apple’s
			copyrights in this original Apple software (the "Apple Software"), to use,
			reproduce, modify and redistribute the Apple Software, with or without
			modifications, in source and/or binary forms; provided that if you redistribute
			the Apple Software in its entirety and without modifications, you must retain
			this notice and the following text and disclaimers in all such redistributions of
			the Apple Software.  Neither the name, trademarks, service marks or logos of
			Apple Computer, Inc. may be used to endorse or promote products derived from the
			Apple Software without specific prior written permission from Apple.  Except as
			expressly stated in this notice, no other rights or licenses, express or implied,
			are granted by Apple herein, including but not limited to any patent rights that
			may be infringed by your derivative works or by other works in which the Apple
			Software may be incorporated.

			The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
			WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
			WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
			PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
			COMBINATION WITH YOUR PRODUCTS.

			IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
			CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
			GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
			ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION
			OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT
			(INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN
			ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/*=============================================================================
	AudioThruEngine.cpp
	
=============================================================================*/

#include "AudioThruEngine.h"
#include "AudioRingBuffer.h"
#include <unistd.h>

#define USE_AUDIODEVICEREAD 0
#if USE_AUDIODEVICEREAD
AudioBufferList *gInputIOBuffer = NULL;
#endif

#define kSecondsInRingBuffer 2.

AudioThruEngine::AudioThruEngine() : 
	mRunning(false),
	mMuting(false),
	mThruing(true),
	mBufferSize(512),
	mExtraLatencyFrames(0),
	mInputLoad(0.),
	mOutputLoad(0.),
    mWorkBuf(NULL),
    mEqualizerEnabled(false),
    mVirtualizerEnabled(false)
{
//	mErrorMessage[0] = '\0';
	mInputBuffer = new AudioRingBuffer(4, 88200);
	
	// init routing map to default chan->chan
	for (int i = 0; i < 16; i++)
		mChannelMap[i] = i;
}

AudioThruEngine::~AudioThruEngine()
{
	SetDevices(kAudioDeviceUnknown, kAudioDeviceUnknown);
	delete mInputBuffer;
}

void	AudioThruEngine::SetDevices(AudioDeviceID input, AudioDeviceID output)
{
	Stop();
	
	if (input != kAudioDeviceUnknown)
		mInputDevice.Init(input, true);
	if (output != kAudioDeviceUnknown)
		mOutputDevice.Init(output, false);
}


void	AudioThruEngine::SetInputDevice(AudioDeviceID input)
{
	Stop();
	mInputDevice.Init(input, true);
	SetBufferSize(mBufferSize);
	mInputBuffer->Clear();
	Start();
}

void	AudioThruEngine::SetOutputDevice(AudioDeviceID output)
{
	Stop();
	mOutputDevice.Init(output, false);
	SetBufferSize(mBufferSize);
	Start();
}

void	AudioThruEngine::SetBufferSize(UInt32 size)
{
	bool wasRunning = Stop();
	mBufferSize = size;
	mInputDevice.SetBufferSize(size);
	mOutputDevice.SetBufferSize(size);
	if (wasRunning) Start();
}

void	AudioThruEngine::SetExtraLatency(SInt32 frames)
{
	mExtraLatencyFrames = frames;
	if (mRunning)
		ComputeThruOffset();
}

// change sample rate of one device to match another - returns if successful or not
OSStatus AudioThruEngine::MatchSampleRate(bool useInputDevice)
{
	OSStatus status = kAudioHardwareNoError;
			
	mInputDevice.UpdateFormat();
	mOutputDevice.UpdateFormat();
	
	if (mInputDevice.mFormat.mSampleRate != mOutputDevice.mFormat.mSampleRate)
	{
		if (useInputDevice)
			status = mOutputDevice.SetSampleRate(mInputDevice.mFormat.mSampleRate);
		else
			status = mInputDevice.SetSampleRate(mOutputDevice.mFormat.mSampleRate);
			
		printf("reset sample rate\n");	
	}
    
    mSampleRate = mInputDevice.mFormat.mSampleRate;
    
    UpdateDSP();
	return status;
}

void    AudioThruEngine::UpdateDSP()
{
    mEffectVirtualizer.configure(mSampleRate);
    mEffectEqualizer.configure(mSampleRate);
}

void    AudioThruEngine::SetVirtualizer(bool enabled, int16_t strength) {
    mVirtualizerEnabled = enabled;
    mEffectVirtualizer.setStrength(strength);
}

void    AudioThruEngine::SetEqualizer(bool enabled, float *bands, float loudnessCorrection)
{
    mEqualizerEnabled = enabled;
    for (int i = 0; i < 6; i ++) {
        mEffectEqualizer.setBand(i, bands[i]);
    }
    mEffectEqualizer.setLoudnessCorrection(loudnessCorrection);
}

void	AudioThruEngine::Start()
{
	if (mRunning) return;
	if (!mInputDevice.Valid() || !mOutputDevice.Valid()) {
		//printf("invalid device\n");
		return;
	}

	if (mInputDevice.mFormat.mSampleRate != mOutputDevice.mFormat.mSampleRate) {
		if (MatchSampleRate(false)) {
			printf("Error - sample rate mismatch: %f / %f\n", mInputDevice.mFormat.mSampleRate, mOutputDevice.mFormat.mSampleRate);
			return;
		}
	}

	mInputBuffer->Allocate(mInputDevice.mFormat.mBytesPerFrame, UInt32(kSecondsInRingBuffer * mInputDevice.mFormat.mSampleRate));
	mSampleRate = mInputDevice.mFormat.mSampleRate;
    UpdateDSP();
	
	mWorkBuf = new Byte[mInputDevice.mBufferSizeFrames * mInputDevice.mFormat.mBytesPerFrame];
	memset(mWorkBuf, 0, mInputDevice.mBufferSizeFrames * mInputDevice.mFormat.mBytesPerFrame);
		
	mRunning = true;
	
#if USE_AUDIODEVICEREAD
	UInt32 streamListSize;
	verify_noerr (AudioDeviceGetPropertyInfo(gInputDevice, 0, true, kAudioDevicePropertyStreams, &streamListSize, NULL));
	UInt32 nInputStreams = streamListSize / sizeof(AudioStreamID);
	
	propsize = offsetof(AudioBufferList, mBuffers[nInputStreams]);
	gInputIOBuffer = (AudioBufferList *)malloc(propsize);
	verify_noerr (AudioDeviceGetProperty(gInputDevice, 0, true, kAudioDevicePropertyStreamConfiguration, &propsize, gInputIOBuffer));
	gInputIOBuffer->mBuffers[0].mData = malloc(gInputIOBuffer->mBuffers[0].mDataByteSize);
	
	verify_noerr (AudioDeviceSetProperty(gInputDevice, NULL, 0, true, kAudioDevicePropertyRegisterBufferList, propsize, gInputIOBuffer));
#endif
	
	mInputProcState = kStarting;
	mOutputProcState = kStarting;
	
	verify_noerr (AudioDeviceAddIOProc(mInputDevice.mID, InputIOProc, this));
	verify_noerr (AudioDeviceStart(mInputDevice.mID, InputIOProc));
	
	if (mInputDevice.CountChannels() == 16)
		mOutputIOProc = OutputIOProc16;
	else
		mOutputIOProc = OutputIOProc;
		

	verify_noerr (AudioDeviceAddIOProc(mOutputDevice.mID, mOutputIOProc, this));
	verify_noerr (AudioDeviceStart(mOutputDevice.mID, mOutputIOProc));

	while (mInputProcState != kRunning || mOutputProcState != kRunning)
		usleep(1000);
	
	ComputeThruOffset();
}

void	AudioThruEngine::ComputeThruOffset()
{
	if (!mRunning) {
		mActualThruLatency = 0;
		mInToOutSampleOffset = 0;
		return;
	}
    
	mActualThruLatency = SInt32(mInputDevice.mSafetyOffset + /*2 * */ mInputDevice.mBufferSizeFrames +
						mOutputDevice.mSafetyOffset + mOutputDevice.mBufferSizeFrames) + mExtraLatencyFrames;
	mInToOutSampleOffset = mActualThruLatency + mIODeltaSampleCount;
}

bool	AudioThruEngine::Stop()
{
	if (!mRunning) return false;
	mRunning = false;
	
	mInputProcState = kStopRequested;
	mOutputProcState = kStopRequested;
	
	while (mInputProcState != kOff || mOutputProcState != kOff)
		usleep(5000);

	AudioDeviceRemoveIOProc(mInputDevice.mID, InputIOProc);
	AudioDeviceRemoveIOProc(mOutputDevice.mID, mOutputIOProc);
	
	if (mWorkBuf) {
		delete[] mWorkBuf;
		mWorkBuf = NULL;
	}
	
	return true;
}



// Input IO Proc
// Receiving input for 1 buffer + safety offset into the past
OSStatus AudioThruEngine::InputIOProc (	AudioDeviceID			inDevice,
										const AudioTimeStamp*	inNow,
										const AudioBufferList*	inInputData,
										const AudioTimeStamp*	inInputTime,
										AudioBufferList*		outOutputData,
										const AudioTimeStamp*	inOutputTime,
										void*					inClientData)
{
	AudioThruEngine *This = (AudioThruEngine *)inClientData;
	
	switch (This->mInputProcState) {
	case kStarting:
		This->mInputProcState = kRunning;
		break;
	case kStopRequested:
		AudioDeviceStop(inDevice, InputIOProc);
		This->mInputProcState = kOff;
		return noErr;
	default:
		break;
	}

	This->mLastInputSampleCount = inInputTime->mSampleTime;
	This->mInputBuffer->Store((const Byte *)inInputData->mBuffers[0].mData, 
								This->mInputDevice.mBufferSizeFrames,
								UInt64(inInputTime->mSampleTime));
	
//	This->ApplyLoad(This->mInputLoad);
	return noErr;
}

// Output IO Proc
// Rendering output for 1 buffer + safety offset into the future
OSStatus AudioThruEngine::OutputIOProc (	AudioDeviceID			inDevice,
											const AudioTimeStamp*	inNow,
											const AudioBufferList*	inInputData,
											const AudioTimeStamp*	inInputTime,
											AudioBufferList*		outOutputData,
											const AudioTimeStamp*	inOutputTime,
											void*					inClientData)
{
	AudioThruEngine *This = (AudioThruEngine *)inClientData;
	
	switch (This->mOutputProcState) {
	case kStarting:
		if (This->mInputProcState == kRunning) {
			This->mOutputProcState = kRunning;
			This->mIODeltaSampleCount = inOutputTime->mSampleTime - This->mLastInputSampleCount;
		}
		return noErr;
	case kStopRequested:
		AudioDeviceStop(inDevice, This->mOutputIOProc);
		This->mOutputProcState = kOff;
		return noErr;
	default:
		break;
	}

	if (!This->mMuting && This->mThruing) {
		double delta = This->mInputBuffer->Fetch(This->mWorkBuf, 
						This->mInputDevice.mBufferSizeFrames,UInt64(inOutputTime->mSampleTime - This->mInToOutSampleOffset));
				
		UInt32 innchnls = This->mInputDevice.mFormat.mChannelsPerFrame;
		
		UInt32 chanstart[16];
        for (UInt32 buf = 0; buf < outOutputData->mNumberBuffers; buf ++) {
			for (int i = 0; i < 16; i++) {
				chanstart[i] = 0;
            }
			UInt32 outnchnls = outOutputData->mBuffers[buf].mNumberChannels;
            
            if (innchnls == 2 && outnchnls == 2) {
                UInt32 outChan1 = This->GetChannelMap(0) - chanstart[0];
                UInt32 outChan2 = This->GetChannelMap(1) - chanstart[1];
                if (outChan1 < outnchnls && outChan2 < outnchnls) {
                    float *in = (float *) This->mWorkBuf;
                    float *out = (float *) outOutputData->mBuffers[buf].mData + outChan1;
                    SInt32 outIdx = outChan2 - outChan1;

                    UInt32 frames = outOutputData->mBuffers[buf].mDataByteSize / (outnchnls * sizeof(float));
                    for (UInt32 frame = 0; frame < frames; frame += 1) {
                        float l = in[0];
                        float r = in[1];
                        
                        if (This->mVirtualizerEnabled) {
                            This->mEffectVirtualizer.process(l, r);
                        }
                        if (This->mEqualizerEnabled) {
                            This->mEffectEqualizer.process(l, r);
                        }
                        
                        out[0     ] += l;
                        out[outIdx] += r;
                        
                        in += innchnls;
                        out += outnchnls;
                    }
                }
                    
                chanstart[0] += outnchnls;
                chanstart[1] += outnchnls;
            } else {
                for (UInt32 chan = 0; chan < innchnls; chan ++) {
                    UInt32 outChan = This->GetChannelMap(chan) - chanstart[chan];		
                    if (outChan < outnchnls) {
                        float *in = (float *) This->mWorkBuf + (chan % innchnls); 
                        float *out = (float *) outOutputData->mBuffers[buf].mData + outChan;		
                        UInt32 frames = outOutputData->mBuffers[buf].mDataByteSize / (outnchnls * sizeof(float));

                        for (UInt32 frame = 0; frame < frames; frame += 1) {
                            *out += *in;
                            in += innchnls;
                            out += outnchnls;
                        }
                    }
                
                    chanstart[chan] += outnchnls;
                }
			}
		}
		
		This->mThruTime = delta;
		
#if USE_AUDIODEVICEREAD
		AudioTimeStamp readTime;
		
		readTime.mFlags = kAudioTimeStampSampleTimeValid;
		readTime.mSampleTime = inNow->mSampleTime - gInputSafetyOffset - gOutputSampleCount;
		
		verify_noerr(AudioDeviceRead(gInputDevice.mID, &readTime, gInputIOBuffer));
		memcpy(outOutputData->mBuffers[0].mData, gInputIOBuffer->mBuffers[0].mData, outOutputData->mBuffers[0].mDataByteSize);
#endif
	} else
		This->mThruTime = 0.;
	
	return noErr;
}

OSStatus AudioThruEngine::OutputIOProc16 (	AudioDeviceID			inDevice,
											const AudioTimeStamp*	inNow,
											const AudioBufferList*	inInputData,
											const AudioTimeStamp*	inInputTime,
											AudioBufferList*		outOutputData,
											const AudioTimeStamp*	inOutputTime,
											void*					inClientData)
{
	return AudioThruEngine::OutputIOProc (inDevice,inNow,inInputData,inInputTime,outOutputData,inOutputTime,inClientData);

}


UInt32 AudioThruEngine::GetOutputNchnls()
{
	if (mOutputDevice.mID != kAudioDeviceUnknown)	
		return mOutputDevice.CountChannels();//mFormat.mChannelsPerFrame; 
	
	return 0;
}