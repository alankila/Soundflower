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
	AudioDevice.cpp
	
=============================================================================*/

#include "AudioDevice.h"

void	AudioDevice::Init(AudioObjectID devid, bool isInput)
{
	mID = devid;
	mIsInput = isInput;
	if (mID == kAudioDeviceUnknown) return;
	
    AudioObjectPropertyAddress propertyAddress = {
        0,
        mIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };
    UInt32 propsize;
    
    propsize = sizeof(mSafetyOffset);
    propertyAddress.mSelector = kAudioDevicePropertySafetyOffset;
    verify_noerr(AudioObjectGetPropertyData(mID, &propertyAddress, 0, NULL, &propsize, &mSafetyOffset));
    
    propsize = sizeof(mBufferSizeFrames);
    propertyAddress.mSelector = kAudioDevicePropertyBufferFrameSize;
    verify_noerr(AudioObjectGetPropertyData(mID, &propertyAddress, 0, NULL, &propsize, &mBufferSizeFrames));
	
    fprintf(stderr, "Constructed buffer with %d frames and safety offset %d\n", mBufferSizeFrames, mSafetyOffset);
    
	UpdateFormat();
}

void	AudioDevice::UpdateFormat()
{
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyStreamFormat,
        mIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };
	UInt32 propsize = sizeof(mFormat);
    verify_noerr(AudioObjectGetPropertyData(mID, &propertyAddress, 0, NULL, &propsize, &mFormat));
    fprintf(stderr, "Determined sampling rate: %lf\n", mFormat.mSampleRate);
}

void	AudioDevice::SetBufferSize(UInt32 size)
{
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyBufferFrameSize,
        mIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };
	UInt32 propsize = sizeof(UInt32);
    verify_noerr(AudioObjectSetPropertyData(mID, &propertyAddress, 0, NULL, propsize, &size));

	propsize = sizeof(mBufferSizeFrames);
	verify_noerr(AudioObjectGetPropertyData(mID, &propertyAddress, 0, NULL, &propsize, &mBufferSizeFrames));
}

OSStatus	AudioDevice::SetSampleRate(Float64 sr)
{
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyStreamFormat,
        mIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };
	UInt32 propsize = sizeof(mFormat);

	mFormat.mSampleRate = sr;
    OSStatus err = AudioObjectSetPropertyData(mID, &propertyAddress, 0, NULL, propsize, &mFormat);
    UpdateFormat();
	
	return err;
}


int		AudioDevice::CountChannels()
{
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyStreamConfiguration,
        mIsInput ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };

	UInt32 propSize;

	OSStatus err = AudioObjectGetPropertyDataSize(mID, &propertyAddress, 0, NULL, &propSize);
	if (err) {
        return 0;
    }

    int result = 0;
	
    AudioBufferList *buflist = (AudioBufferList *) malloc(propSize);
	err = AudioObjectGetPropertyData(mID, &propertyAddress, 0, NULL, &propSize, buflist);
	if (! err) {
		for (UInt32 i = 0; i < buflist->mNumberBuffers; i ++) {
			result += buflist->mBuffers[i].mNumberChannels;
		}
	}
	free(buflist);
    
	return result;
}

CFStringRef	AudioDevice::GetName()
{
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDeviceNameCFString,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    CFStringRef buf;
    UInt32 maxlen = sizeof(buf);
	verify_noerr(AudioObjectGetPropertyData(mID, &propertyAddress, 0, NULL, &maxlen, &buf));
    return buf;
}
