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
	mSuspended2chDevice = mCur2chDevice;
	[self outputDeviceSelected:Nil];
}

- (IBAction)resume
{
	if (mSuspended2chDevice) {
		[self outputDeviceSelected:mSuspended2chDevice];
		mSuspended2chDevice = Nil;
	}
}

- (IBAction)srChanged2ch
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	gThruEngine2->Mute();
	OSStatus err = gThruEngine2->MatchSampleRate(true);
			
	NSMenuItem *curdev = mCur2chDevice;
	[self outputDeviceSelected:Nil];
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
	[self outputDeviceSelected:Nil];
	if (err == kAudioHardwareNoError) {
		[self outputDeviceSelected:curdev];
	}
	gThruEngine2->Mute(false);
	
	[pool release];
}

- (IBAction)refreshDevices
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self buildDeviceList];		
	
	[mSbItem setMenu:nil];
	[mMenu dealloc];
	
	[self buildMenu];

	/* If our device is removed, we selected the first one in the list to replace it. */
	AudioDeviceID dev = gThruEngine2->GetOutputDevice();
	AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
	AudioDeviceList::DeviceList::iterator i;
	for (i = thelist.begin(); i != thelist.end(); ++i) {
		if ((*i).mID == dev) {
			break;
        }
    }
	if (i == thelist.end()) {
		[self outputDeviceSelected:[m2chOutputDevice itemAtIndex:0]];
    }
		
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
	mSuspended2chDevice = Nil;
	
	return self;
}

- (void)dealloc
{
	[self RemoveListeners];
	delete mOutputDeviceList;
    delete gThruEngine2;
	[super dealloc];
}

- (void)buildMenu
{
	NSMenuItem *item;

	mMenu = [[NSMenu alloc] init];
        
    m2chOutputDevice = [[NSMenu alloc] init];
    
    AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
    for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i) {
        AudioDevice ad((*i).mID, false);
        if (ad.CountChannels()) {
            item = [m2chOutputDevice addItemWithTitle:[NSString stringWithUTF8String:(*i).mName] action:@selector(outputDeviceSelected:) keyEquivalent:@""];
            item.target = self;
            item.tag = (*i).mID;
        }
    }
	
    item = [mMenu addItemWithTitle:@"Output device" action:Nil keyEquivalent:@""];
    item.submenu = m2chOutputDevice;
    
    NSMenuItem *bufItem = [mMenu addItemWithTitle:@"Buffer Size" action:Nil keyEquivalent:@""];
    [bufItem setEnabled:true];
    
    m2chBuffer = [[NSMenu alloc] init];
    for (int i = 64; i < 4096; i *= 2) {
        item = [m2chBuffer addItemWithTitle:[NSString stringWithFormat:@"%d", i] action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
        [item setTarget:self];
    }
    bufItem.submenu = m2chBuffer;

    /* Keep synced with presetChanged: */
    NSString *presets[] = {
        @"Flat", 
        @"Acoustic", @"Bass Booster", @"Bass Reducer", @"Classical", @"Deep", @"R&B",
        @"Rock", @"Small Speakers", @"Treble Booster", @"Treble Reducer", @"Vocal Booster"
    };
    m2chPreset = [[NSMenu alloc] init];
    for (int i = 0; i < 12; i ++) {
        item = [m2chPreset addItemWithTitle:presets[i] action:@selector(presetChanged:) keyEquivalent:@""];
        [item setTarget:self];
    }
    item = [mMenu addItemWithTitle:@"Equalizer" action:Nil keyEquivalent:@""];
    item.submenu = m2chPreset;
    
    m2chLoudness = [[NSMenu alloc] init];
    for (int i = 10; i <= 100; i += 10) {
        item = [m2chLoudness addItemWithTitle:[NSString stringWithFormat:@"%d dB", i] action:@selector(loudnessChanged:) keyEquivalent:@""];
        [item setTarget:self];
    }
    item = [mMenu addItemWithTitle:@"Loudness compensation" action:Nil keyEquivalent:@""];
    item.submenu = m2chLoudness;
    
    mCur2chVirtualizer = [mMenu addItemWithTitle:@"Headset virtualization" action:@selector(headsetSelected:) keyEquivalent:@""];
    [mCur2chVirtualizer setTarget:self];
        
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
        /* I have no use for the 16ch device, so I just hide it if someone sees it. */
		if (0 == strcmp("Soundflower (16ch)", (*i).mName)) {
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
    gThruEngine2->SetOutputDevice(mCur2chDevice != Nil ? mCur2chDevice.tag : kAudioDeviceUnknown);
}

- (IBAction)headsetSelected:(id)sender
{
    mCur2chVirtualizer.state = !mCur2chVirtualizer.state;
    gThruEngine2->SetVirtualizer(mCur2chVirtualizer.state, 500);
}

- (void)equalizerChanged
{
    float presets[][6] = {
        { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },     // Flat
        { 4.5, 4.5, 3.5, 1.75, 3.5, 2.5 },    // Acoustic
        { 6.5, 6.5, 4.0, 0.0, 0.0, 0.0 },     // Bass Booster
        { -6.5, -6.5, -4.0, 0.0, 0.0, 0.0 },  // Bass Reducer
        { 4.0, 4.0, 3.25, -0.5, 2.0, 3.5 },   // Classical
        { 4.0, 4.0, 0.5, 1.5, -4.0, -4.5 },   // Deep
        { 5.5, 5.5, 3.5, -1.75, 1.5, 2.5 },   // R&B
        { 4.5, 4.5, 2.75, -0.5, 2.75, 4.0 },  // Rock
        { 6.5, 6.5, 4.0, 0.0, -6.5, -4.0 },   // Small Speakers
        { 0.0, 0.0, 0.0, 0.0, 4.0, 6.5 },     // Treble Booster
        { 0.0, 0.0, 0.0, 0.0, -6.5, -4.0 },   // Treble Reducer
        { -2.5, -2.5, 0.0, 3.5, 1.5, -2.0 },  // Vocal Booster
    };
    
    NSInteger preset = [m2chPreset indexOfItem:mCur2chPreset];
    int loudnessCorrection = mCur2chLoudness.title.intValue;
    NSLog(@"Equalizer: preset: %@, loudness level: %@", mCur2chPreset.title, mCur2chLoudness.title);
    gThruEngine2->SetEqualizer(loudnessCorrection != 100 || preset != 0, presets[preset], loudnessCorrection);
}

- (IBAction)presetChanged:(id)sender
{
    for (NSMenuItem *item in m2chPreset.itemArray) {
        item.state = NSOffState;
    }
    mCur2chPreset = sender;
    mCur2chPreset.state = NSOnState;
    [self equalizerChanged];    
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
        v = [m2chOutputDevice itemAtIndex:0].title;
    }
    item = [m2chOutputDevice itemWithTitle:v];
    [self outputDeviceSelected:item];

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

    v = [defaults valueForKey:@"preset"];
    if (! v) {
        v = @"Flat";
    }
    [self presetChanged:[m2chPreset itemWithTitle:v]];
}
		
- (void)writeGlobalPrefs
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setValue:mCur2chDevice.title forKey:@"2ch"];
    [defaults setValue:mCur2chBuffer.title forKey:@"2chBuf"];
    [defaults setValue:[NSString stringWithFormat:@"%ld", mCur2chVirtualizer.state] forKey:@"virtualizer"];
    [defaults setValue:mCur2chLoudness.title forKey:@"loudness"];
    [defaults setValue:mCur2chPreset.title forKey:@"preset"];
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
