/*	
*/

#import "AppController.h"

#include "AudioThruEngine.h"

@implementation AppController

AudioThruEngine	*gThruEngine2 = NULL;
Boolean startOnAwake = false;

OSStatus	HardwareListenerProc (	AudioHardwarePropertyID	inPropertyID,
                                    void*					inClientData)
{
	AppController *app = (AppController *)inClientData;
    switch(inPropertyID)
    { 
        case kAudioHardwarePropertyDevices:
       		// An audio device has been added or removed to the system, so lets just start over
			[NSThread detachNewThreadSelector:@selector(refreshDevices) toTarget:app withObject:nil];	
            break;			
    }
    
    return (noErr);
}

OSStatus	DeviceListenerProc (	AudioDeviceID           inDevice,
                                    UInt32                  inChannel,
                                    Boolean                 isInput,
                                    AudioDevicePropertyID   inPropertyID,
                                    void*                   inClientData)
{
	AppController *app = (AppController *)inClientData;
	
    switch(inPropertyID)
    {		
        case kAudioDevicePropertyNominalSampleRate:
			if (isInput) {
				if (gThruEngine2->IsRunning() && gThruEngine2->GetInputDevice() == inDevice)	
					[NSThread detachNewThreadSelector:@selector(srChanged2ch) toTarget:app withObject:nil];
			} 
			else {
				if (inChannel == 0) {
					if (gThruEngine2->IsRunning() && gThruEngine2->GetOutputDevice() == inDevice)
						[NSThread detachNewThreadSelector:@selector(srChanged2chOutput) toTarget:app withObject:nil];
				}
			}
			break;
	
		case kAudioDevicePropertyDataSource:
			if (gThruEngine2->IsRunning() && gThruEngine2->GetOutputDevice() == inDevice)
				[NSThread detachNewThreadSelector:@selector(srChanged2chOutput) toTarget:app withObject:nil];
			break;
			
		case kAudioDevicePropertyStreams:
		case kAudioDevicePropertyStreamConfiguration:
			if (!isInput) {
				if (inChannel == 0) {
					if (gThruEngine2->GetOutputDevice() == inDevice) {
						[NSThread detachNewThreadSelector:@selector(checkNchnls) toTarget:app withObject:nil];
					}
					else
						[NSThread detachNewThreadSelector:@selector(refreshDevices) toTarget:app withObject:nil];	
				}
			}
			break;
		
		default:
			break;
	}
	
	return noErr;
}

#include <mach/mach_port.h>
#include <mach/mach_interface.h>
#include <mach/mach_init.h>

#include <IOKit/pwr_mgt/IOPMLib.h>
#include <IOKit/IOMessage.h>

io_connect_t  root_port;

void
MySleepCallBack(void * x, io_service_t y, natural_t messageType, void * messageArgument)
{  
	AppController *app = (AppController *)x;

    switch ( messageType ) {
        case kIOMessageSystemWillSleep:
			[NSThread detachNewThreadSelector:@selector(suspend) toTarget:app withObject:nil];
            IOAllowPowerChange(root_port, (long)messageArgument);
            break;
			
		case kIOMessageSystemWillNotSleep:
			break;
			
        case kIOMessageCanSystemSleep:
            IOAllowPowerChange(root_port, (long)messageArgument);
            break;

        case kIOMessageSystemHasPoweredOn:
			[NSTimer scheduledTimerWithTimeInterval:0.0 target:app selector:@selector(resume) userInfo:nil repeats:NO];
			break;
			
		default:
			break;
    }
}

- (IBAction)suspend
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	mSuspended2chDevice = mCur2chDevice;
	
	[self outputDeviceSelected:[mMenu itemAtIndex:1]];
	
	[pool release];
}

- (IBAction)resume
{
	if (mSuspended2chDevice) {
		[self outputDeviceSelected:mSuspended2chDevice];
		mCur2chDevice = mSuspended2chDevice;
		mSuspended2chDevice = NULL;
	}
}

- (IBAction)srChanged2ch
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	gThruEngine2->Mute();
	OSStatus err = gThruEngine2->MatchSampleRate(true);
			
	NSMenuItem *curdev = mCur2chDevice;
	[self outputDeviceSelected:[mMenu itemAtIndex:1]];
	if (err == kAudioHardwareNoError) {
		[self outputDeviceSelected:curdev];
	}
	
	gThruEngine2->Mute(false);
	
	[pool release];
}


- (IBAction)srChanged2chOutput
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	gThruEngine2->Mute();
	OSStatus err = gThruEngine2->MatchSampleRate(false);
			
	NSMenuItem		*curdev = mCur2chDevice;
	[self outputDeviceSelected:[mMenu itemAtIndex:1]];
	if (err == kAudioHardwareNoError) {
		[self outputDeviceSelected:curdev];
	}
	gThruEngine2->Mute(false);
	
	[pool release];
}

- (IBAction)checkNchnls
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if (mNchnls2 != gThruEngine2->GetOutputNchnls()) {
		NSMenuItem	*curdev = mCur2chDevice;
		[self outputDeviceSelected:[mMenu itemAtIndex:1]];
		[self outputDeviceSelected:curdev];
	}
	
	[pool release];
}

- (IBAction)refreshDevices
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self buildDeviceList];		
	
	[mSbItem setMenu:nil];
	[mMenu dealloc];
	
	[self buildMenu];
	
	// make sure that one of our current device's was not removed!
	AudioDeviceID dev = gThruEngine2->GetOutputDevice();
	AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
	AudioDeviceList::DeviceList::iterator i;
	for (i = thelist.begin(); i != thelist.end(); ++i)
		if ((*i).mID == dev) 
			break;
	if (i == thelist.end()) // we didn't find it, turn selection to none
		[self outputDeviceSelected:[mMenu itemAtIndex:1]];
	else
		[self buildRoutingMenu:YES];
		
	[pool release];
}

- (void)InstallListeners;
{	
	// add listeners for all devices, including soundflowers
	AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
	int index = 0;
	for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i, ++index) {
		if (0 == strncmp("Soundflower", (*i).mName, strlen("Soundflower"))) {
			verify_noerr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioDevicePropertyNominalSampleRate, DeviceListenerProc, self));
			verify_noerr (AudioDeviceAddPropertyListener((*i).mID, 0, true, kAudioDevicePropertyStreamConfiguration, DeviceListenerProc, self));			
		}
		else {
			verify_noerr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioDevicePropertyNominalSampleRate, DeviceListenerProc, self));
			verify_noerr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioDevicePropertyStreamConfiguration, DeviceListenerProc, self));
			verify_noerr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioDevicePropertyStreams, DeviceListenerProc, self));
			verify_noerr (AudioDeviceAddPropertyListener((*i).mID, 0, false, kAudioDevicePropertyDataSource, DeviceListenerProc, self));

		}
	}
		
	// check for added/removed devices
   verify_noerr (AudioHardwareAddPropertyListener(kAudioHardwarePropertyDevices, HardwareListenerProc, self));   
}

- (void)RemoveListeners
{
	AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
	int index = 0;
	for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i, ++index) {
		if (0 == strncmp("Soundflower", (*i).mName, strlen("Soundflower"))) {
			verify_noerr (AudioDeviceRemovePropertyListener((*i).mID, 0, true, kAudioDevicePropertyNominalSampleRate, DeviceListenerProc));
			verify_noerr (AudioDeviceRemovePropertyListener((*i).mID, 0, true, kAudioDevicePropertyStreamConfiguration, DeviceListenerProc));
		}
		else {
			verify_noerr (AudioDeviceRemovePropertyListener((*i).mID, 0, false, kAudioDevicePropertyNominalSampleRate, DeviceListenerProc));
			verify_noerr (AudioDeviceRemovePropertyListener((*i).mID, 0, false, kAudioDevicePropertyStreamConfiguration, DeviceListenerProc));
			verify_noerr (AudioDeviceRemovePropertyListener((*i).mID, 0, false, kAudioDevicePropertyStreams, DeviceListenerProc));
			verify_noerr (AudioDeviceRemovePropertyListener((*i).mID, 0, false, kAudioDevicePropertyDataSource, DeviceListenerProc));
		}
	}

	 verify_noerr (AudioHardwareRemovePropertyListener(kAudioHardwarePropertyDevices, HardwareListenerProc));
}

- (id)init
{
	mOutputDeviceList = NULL;
	
	mSoundflower2Device = 0;
	mNchnls2 = 0;	
	mSuspended2chDevice = NULL;
	
	return self;
}

- (void)dealloc
{
	[self RemoveListeners];
	delete mOutputDeviceList;
		
	[super dealloc];
}

- (void)buildMenu
{
	NSMenuItem *item;

	mMenu = [[NSMenu alloc] init];
        
    m2chOutputDevice = [[NSMenu alloc] init];
    item = [m2chOutputDevice addItemWithTitle:@"None (OFF)" action:@selector(outputDeviceSelected:) keyEquivalent:@""];
    item.tag = kAudioDeviceUnknown;
    [item setTarget:self];
    mCur2chDevice = item;
    
    AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
    for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i) {
        AudioDevice ad((*i).mID, false);
        if (ad.CountChannels()) {
            item = [m2chOutputDevice addItemWithTitle:[NSString stringWithUTF8String:(*i).mName] action:@selector(outputDeviceSelected:) keyEquivalent:@""];
            item.target = self;
            item.tag = (*i).mID;
        }
    }
	
    item = [mMenu addItemWithTitle:@"Output device" action:NULL keyEquivalent:@""];
    item.submenu = m2chOutputDevice;
    
    mCur2chVirtualizer = [mMenu addItemWithTitle:@"Headset virtualization" action:@selector(headsetSelected:) keyEquivalent:@""];
    [mCur2chVirtualizer setTarget:self];

    m2chLoudness = [[NSMenu alloc] init];
    for (int i = 10; i <= 100; i += 10) {
        item = [m2chLoudness addItemWithTitle:[NSString stringWithFormat:@"%d dB", i] action:@selector(loudnessChanged:) keyEquivalent:@""];
        [item setTarget:self];
    }
    item = [mMenu addItemWithTitle:@"Loudness compensation" action:NULL keyEquivalent:@""];
    item.submenu = m2chLoudness;
    
    NSMenuItem *bufItem = [mMenu addItemWithTitle:@"Buffer Size" action:NULL keyEquivalent:@""];
    [bufItem setEnabled:true];
    
    m2chBuffer = [[NSMenu alloc] init];
    for (int i = 64; i < 4096; i *= 2) {
        item = [m2chBuffer addItemWithTitle:[NSString stringWithFormat:@"%d", i] action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
        [item setTarget:self];
    }
    bufItem.submenu = m2chBuffer;
    
    [mMenu addItem:[NSMenuItem separatorItem]];

	item = [mMenu addItemWithTitle:@"Audio Setup..." action:@selector(doAudioSetup) keyEquivalent:@""];
	[item setTarget:self];
	
	item = [mMenu addItemWithTitle:@"About Soundflowerbed..." action:@selector(doAbout) keyEquivalent:@""];
	[item setTarget:self];
    
	item = [mMenu addItemWithTitle:@"Quit Soundflowerbed" action:@selector(doQuit) keyEquivalent:@""];
	[item setTarget:self];

	[mSbItem setMenu:mMenu];
}

- (void)buildDeviceList
{
	if (mOutputDeviceList) {
		[self RemoveListeners];
		delete mOutputDeviceList;
	}
	
	mOutputDeviceList = new AudioDeviceList(false);
	[self InstallListeners];
	
	// find soundflower devices, store and remove them from our output list
	AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
	int index = 0;
	for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i, ++index) {
		if (0 == strcmp("Soundflower (2ch)", (*i).mName)) {
			mSoundflower2Device = (*i).mID;
			AudioDeviceList::DeviceList::iterator toerase = i;
			i --;
			thelist.erase(toerase);
		}
	}
}

- (void)awakeFromNib
{
	[[NSApplication sharedApplication] setDelegate:self];
	
	[self buildDeviceList];
	
	mSbItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	[mSbItem retain];
	
	[mSbItem setImage:[NSImage imageNamed:@"menuIcon"]];
	[mSbItem setHighlightMode:YES];
	[self buildMenu];
	
	if (mSoundflower2Device) {
		gThruEngine2 = new AudioThruEngine();
		gThruEngine2->SetInputDevice(mSoundflower2Device);
		gThruEngine2->Start();
	}
    [self readGlobalPrefs];
	
	// ask to be notified on system sleep to avoid a crash
	IONotificationPortRef notify;
    io_object_t anIterator;

    root_port = IORegisterForSystemPower(self, &notify, MySleepCallBack, &anIterator);
    if (! root_port) {
		printf("IORegisterForSystemPower failed\n");
    }
	else
		CFRunLoopAddSource(CFRunLoopGetCurrent(),
                        IONotificationPortGetRunLoopSource(notify),
                        kCFRunLoopCommonModes);
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if (gThruEngine2) {
		gThruEngine2->Stop();
    }

    [self writeGlobalPrefs];
}


- (IBAction)bufferSizeChanged2ch:(id)sender
{
    for (NSMenuItem *item in m2chBuffer.itemArray) {
        item.state = NSOffState;
    }
    mCur2chBuffer = sender;
    mCur2chBuffer.state = NSOnState;

	UInt32 size = [[sender title] intValue];
    NSLog(@"2ch buffer: %@", [sender title]);
	gThruEngine2->SetBufferSize(size);
}

- (IBAction)outputDeviceSelected:(id)sender
{
    for (NSMenuItem *item in m2chOutputDevice.itemArray) {
        item.state = NSOffState;
    }
    mCur2chDevice = sender;
    mCur2chDevice.state = NSOnState;
    
    NSLog(@"Changing 2ch device to: %@", mCur2chDevice.title);
    gThruEngine2->SetOutputDevice(mCur2chDevice.tag);
}

- (IBAction)headsetSelected:(id)sender
{
    mCur2chVirtualizer.state = !mCur2chVirtualizer.state;
    gThruEngine2->SetVirtualizer(mCur2chVirtualizer.state, 500);
}

- (void)equalizerChanged
{
    float presets[][6] = {
        { 0, 0, 0, 0, 0, 0 }
    };
    
    int preset = 0;
    int loudnessCorrection = mCur2chLoudness.title.intValue;
    NSLog(@"Loudness level: %d", loudnessCorrection);
    gThruEngine2->SetEqualizer(loudnessCorrection != 100, presets[preset], loudnessCorrection);
}

- (IBAction)presetChanged:(id)sender
{
    
}

- (IBAction)loudnessChanged:(id)sender
{
    for (NSMenuItem *item in m2chLoudness.itemArray) {
        item.state = NSOffState;
    }
    mCur2chLoudness = sender;
    mCur2chLoudness.state = NSOnState;
    [self equalizerChanged];
}

- (void)readGlobalPrefs
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *v;
    NSMenuItem *item;
    
    v = [defaults valueForKey:@"2ch"];
    if (! v) {
        v = @"None (OFF)";
    }
    item = [m2chOutputDevice itemWithTitle:v];
    if (item) {
        [self outputDeviceSelected:item];
	}

	v = [defaults valueForKey:@"2chBuf"];
    if (! v) {
        v = @"512";
    }
    [self bufferSizeChanged2ch:[m2chBuffer itemWithTitle:v]];
	
    v = [defaults valueForKey:@"virtualizer"];
    if (! v) {
        v = @"0";
    }
    /* State will be flipped by headsetSelected, so it appears inverted here. */
    mCur2chVirtualizer.state = v.intValue ? NSOffState : NSOnState;
    [self headsetSelected:mCur2chVirtualizer];

    v = [defaults valueForKey:@"loudness"];
    if (! v) {
        v = @"100 dB";
    }
    [self loudnessChanged:[m2chLoudness itemWithTitle:v]];
}
		
- (void)writeGlobalPrefs
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setValue:mCur2chDevice.title forKey:@"2ch"];
    [defaults setValue:mCur2chBuffer.title forKey:@"2chBuf"];
    [defaults setValue:[NSString stringWithFormat:@"%ld", mCur2chVirtualizer.state] forKey:@"virtualizer"];
    [defaults setValue:mCur2chLoudness.title forKey:@"loudness"];
    [defaults synchronize];
}

-(void)doAudioSetup
{
	[[NSWorkspace sharedWorkspace] launchApplication:@"Audio MIDI Setup"];
}

-(void)doAbout
{
	[mAboutController doAbout];
}

- (void)doQuit
{
	[NSApp terminate:nil];
}

@end
