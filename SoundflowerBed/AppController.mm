/*	
*/

#import "AppController.h"
#import "AudioDevice.h"

@implementation AppController

static const float presets[][6] = {
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

OSStatus	DeviceListenerProc (	AudioObjectID           inDevice,
                                    UInt32                  inNumberAddress,
                                    const AudioObjectPropertyAddress *inAddresses,
                                    void*                   inClientData)
{
	AppController *app = (AppController *) inClientData;

	for (int i = 0; i < inNumberAddress; i ++) {
        AudioObjectPropertyElement inSelectorID = inAddresses[i].mSelector;
        BOOL isInput = inAddresses[i].mScope == kAudioDevicePropertyScopeInput;
    
        switch (inSelectorID) {
            case kAudioDevicePropertyNominalSampleRate:
                if (isInput) {
                    if (app->mThruEngine2->IsRunning() && app->mThruEngine2->GetInputDevice() == inDevice) {
                        [NSThread detachNewThreadSelector:@selector(srChanged2ch) toTarget:app withObject:nil];
                    }
                } else {
                    if (app->mThruEngine2->IsRunning() && app->mThruEngine2->GetOutputDevice() == inDevice) {
                        [NSThread detachNewThreadSelector:@selector(srChanged2chOutput) toTarget:app withObject:nil];
                    }
                }
                break;
	
            case kAudioDevicePropertyDataSource:
                if (app->mThruEngine2->IsRunning() && app->mThruEngine2->GetOutputDevice() == inDevice)
                    [NSThread detachNewThreadSelector:@selector(srChanged2chOutput) toTarget:app withObject:nil];
                break;
			
            case kAudioHardwarePropertyDevices:
            case kAudioDevicePropertyStreams:
            case kAudioDevicePropertyStreamConfiguration:
                if (!isInput) {
                    [NSThread detachNewThreadSelector:@selector(refreshDevices) toTarget:app withObject:nil];	
                }
                break;
		
            default:
                break;
        
        }
	}
	
	return noErr;
}

void
MySleepCallBack(void *x, io_service_t y, natural_t messageType, void *messageArgument)
{  
	AppController *app = (AppController *) x;

    switch (messageType) {
        case kIOMessageSystemWillSleep:
			[NSThread detachNewThreadSelector:@selector(suspend) toTarget:app withObject:nil];
            IOAllowPowerChange(app->root_port, (long)messageArgument);
            break;
			
        case kIOMessageCanSystemSleep:
            IOAllowPowerChange(app->root_port, (long)messageArgument);
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

	mThruEngine2->Mute();
	OSStatus err = mThruEngine2->MatchSampleRate(true);
			
	NSMenuItem *curdev = mCur2chDevice;
	[self outputDeviceSelected:Nil];
	if (err == kAudioHardwareNoError) {
		[self outputDeviceSelected:curdev];
	}
	
	mThruEngine2->Mute(false);
	
	[pool release];
}


- (IBAction)srChanged2chOutput
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	mThruEngine2->Mute();
	OSStatus err = mThruEngine2->MatchSampleRate(false);
			
	NSMenuItem		*curdev = mCur2chDevice;
	[self outputDeviceSelected:Nil];
	if (err == kAudioHardwareNoError) {
		[self outputDeviceSelected:curdev];
	}
	mThruEngine2->Mute(false);
	
	[pool release];
}

- (NSArray *)listAudioDevices {
    AudioObjectPropertyAddress devicesAddress = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    }; 

    UInt32 deviceArraySize = 0;
    verify_noerr(AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &devicesAddress, 0, NULL, &deviceArraySize));
    
    AudioDeviceID *devices = new AudioDeviceID[deviceArraySize / sizeof(AudioDeviceID)];
    verify_noerr(AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                            &devicesAddress, 
                                            0,
                                            NULL,
                                            &deviceArraySize, 
                                            devices));

    NSMutableArray *devs = [[[NSMutableArray alloc] init] autorelease];
    for (int i = 0; i < deviceArraySize / sizeof(AudioObjectID); i ++) {
        AudioObjectID aoID = devices[i];

        AudioObjectPropertyAddress inputAddress = {
            kAudioDevicePropertyStreamConfiguration,
            kAudioDevicePropertyScopeInput,
            kAudioObjectPropertyElementMaster
        }; 

        UInt32 dataSize;
        verify_noerr(AudioObjectGetPropertyDataSize(aoID, &inputAddress, 0, NULL, &dataSize));
        AudioDevice *dev = new AudioDevice(aoID, dataSize == 0);
        [devs addObject:[NSValue valueWithPointer:dev]];
    }
    delete[] devices;
    return devs;
}

- (IBAction)refreshDevices
{
	[self buildDeviceList];		
	
	[mSbItem setMenu:nil];
	[mMenu dealloc];
	
	[self buildMenu];
    
    BOOL found = NO;
	AudioObjectID outputDev = mThruEngine2->GetOutputDevice();
    for (NSValue *wrap in mOutputDeviceList) {
        AudioDevice *dev = (AudioDevice *) wrap.pointerValue;
        if (dev->mID == outputDev) {
            found = YES;
            break;
        }
    }
    if (! found) {
        [self outputDeviceSelected:[m2chOutputDevice itemAtIndex:0]];
    }
}

- (void)InstallListeners;
{	
    for (NSValue *wrap in mOutputDeviceList) {
        AudioDevice *dev = (AudioDevice *) wrap.pointerValue;
        NSString *name = (NSString *) dev->GetName();
        NSLog(@"Adding general wildcard listener to: %@", name);
        AudioObjectPropertyAddress property = {
            kAudioObjectPropertySelectorWildcard,
            kAudioObjectPropertyScopeWildcard,
            kAudioObjectPropertyElementWildcard
        };
        verify_noerr(AudioObjectAddPropertyListener(dev->mID, &property, DeviceListenerProc, self));
	}
}

- (void)RemoveListeners
{
    for (NSValue *wrap in mOutputDeviceList) {
        AudioDevice *dev = (AudioDevice *) wrap.pointerValue;
        NSString *name = (NSString *) dev->GetName();
        NSLog(@"Removing general wildcard listener from: %@", name);
        AudioObjectPropertyAddress property = {
            kAudioObjectPropertySelectorWildcard,
            kAudioObjectPropertyScopeWildcard,
            kAudioObjectPropertyElementWildcard
        };
        verify_noerr(AudioObjectRemovePropertyListener(dev->mID, &property, DeviceListenerProc, self));
	}
}

- (id)init
{
	mSoundflower2Device = 0;
	mSuspended2chDevice = Nil;
    mFrequencyResponseController = [[FrequencyResponseWindowController alloc] initWithWindowNibName:@"FrequencyResponseWindowController"];
    [mFrequencyResponseController setEqualizerDelegate:self];
	return self;
}

- (void)dealloc
{
	if (mOutputDeviceList) {
		[self RemoveListeners];
        for (NSValue *value in mOutputDeviceList) {
            AudioDevice *dev = (AudioDevice *) value.pointerValue;
            delete dev;
        }
        [mOutputDeviceList release];
        mOutputDeviceList = Nil;
	}
    delete mThruEngine2;
    mThruEngine2 = NULL;
    [mFrequencyResponseController release];
	[super dealloc];
}

- (void)buildMenu
{
	NSMenuItem *item;

	mMenu = [[NSMenu alloc] init];
        
    m2chOutputDevice = [[NSMenu alloc] init];

    for (NSValue *value in mOutputDeviceList) {
        AudioDevice *dev = (AudioDevice *) value.pointerValue;
        NSString *name = (NSString *) dev->GetName();
		if ([name isEqualTo:@"Soundflower (2ch)"] || [name isEqualTo:@"Soundflower (16ch)"]) {
            continue;
        }
        if (dev->CountChannels()) {
            NSString *name = (NSString *) dev->GetName();
            item = [m2chOutputDevice addItemWithTitle:name action:@selector(outputDeviceSelected:) keyEquivalent:@""];
            item.target = self;
            item.tag = dev->mID;
        }
    }
	
    item = [mMenu addItemWithTitle:@"Output Device" action:Nil keyEquivalent:@""];
    item.submenu = m2chOutputDevice;
    
    NSMenuItem *bufItem = [mMenu addItemWithTitle:@"Buffer Size" action:Nil keyEquivalent:@""];
    [bufItem setEnabled:true];
    
    m2chBuffer = [[NSMenu alloc] init];
    for (int i = 64; i < 4096; i *= 2) {
        item = [m2chBuffer addItemWithTitle:[NSString stringWithFormat:@"%d frames", i] action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
        item.tag = i;
        item.target = self;
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
        item.tag = i;
        item.target = self;
    }
    [m2chPreset addItem:[NSMenuItem separatorItem]];
    item = [m2chPreset addItemWithTitle:@"Custom..." action:@selector(showFrequencyResponseWindow:) keyEquivalent:@""];
    item.tag = -1;
    item.target = self;
    
    item = [mMenu addItemWithTitle:@"Equalizer" action:Nil keyEquivalent:@""];
    item.submenu = m2chPreset;
    
    m2chLoudness = [[NSMenu alloc] init];
    for (int i = 10; i <= 100; i += 10) {
        item = [m2chLoudness addItemWithTitle:[NSString stringWithFormat:@"%d dB", i] action:@selector(loudnessChanged:) keyEquivalent:@""];
        item.tag = i;
        item.target = self;
    }
    item = [mMenu addItemWithTitle:@"Loudness Compensation" action:Nil keyEquivalent:@""];
    item.submenu = m2chLoudness;
    
    mCur2chVirtualizer = [mMenu addItemWithTitle:@"Headset Virtualization" action:@selector(headsetSelected:) keyEquivalent:@""];
    [mCur2chVirtualizer setTarget:self];
        
    [mMenu addItem:[NSMenuItem separatorItem]];

	item = [mMenu addItemWithTitle:@"Audio Setup..." action:@selector(doAudioSetup) keyEquivalent:@""];
	[item setTarget:self];
	
	item = [mMenu addItemWithTitle:@"About DSP X..." action:@selector(doAbout) keyEquivalent:@""];
	[item setTarget:self];
    
	item = [mMenu addItemWithTitle:@"Quit" action:@selector(doQuit) keyEquivalent:@""];
	[item setTarget:self];

	[mSbItem setMenu:mMenu];
}

- (void)buildDeviceList
{
	if (mOutputDeviceList) {
		[self RemoveListeners];
        for (NSValue *value in mOutputDeviceList) {
            AudioDevice *dev = (AudioDevice *) value.pointerValue;
            delete dev;
        }
        [mOutputDeviceList release];
        mOutputDeviceList = Nil;
	}
	
	mOutputDeviceList = [self listAudioDevices];
	[self InstallListeners];
    
    mSoundflower2Device = 0;
    for (NSValue *wrap in mOutputDeviceList) {
        AudioDevice *dev = (AudioDevice *) wrap.pointerValue;
        NSString *name = (NSString *) dev->GetName();
        
        if ([name isEqualTo:@"Soundflower (2ch)"]) {
            mSoundflower2Device = dev->mID;
            break;
        }        
    }
    
    if (! mSoundflower2Device) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Soundflower audio device can not be found. Is the kernel driver running? (Tried to find device with name 'Soundflower (2ch)'";
        [alert runModal];
        [alert release];
    }
}

- (void)awakeFromNib
{
	[[NSApplication sharedApplication] setDelegate:self];
	
	[self buildDeviceList];
	
	mSbItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
	[mSbItem retain];
	
	mSbItem.image = [NSImage imageNamed:@"dspx-menu.png"];
    mSbItem.alternateImage = [NSImage imageNamed:@"dspx-menu-active.png"];
    mSbItem.highlightMode = YES;
	[self buildMenu];
	
	if (mSoundflower2Device) {
		mThruEngine2 = new AudioThruEngine();
		mThruEngine2->SetInputDevice(mSoundflower2Device);
		mThruEngine2->Start();
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
	if (mThruEngine2) {
		mThruEngine2->Stop();
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

    NSLog(@"2ch buffer: %@", mCur2chBuffer.title);
    mThruEngine2->SetBufferSize(mCur2chBuffer.tag);
}

- (IBAction)outputDeviceSelected:(id)sender
{
    for (NSMenuItem *item in m2chOutputDevice.itemArray) {
        item.state = NSOffState;
    }
    mCur2chDevice = sender;
    mCur2chDevice.state = NSOnState;
    
    NSLog(@"Changing 2ch device to: %@", mCur2chDevice.title);
    mThruEngine2->SetOutputDevice(mCur2chDevice != Nil ? mCur2chDevice.tag : kAudioDeviceUnknown);
}

- (IBAction)headsetSelected:(id)sender
{
    mCur2chVirtualizer.state = !mCur2chVirtualizer.state;
    mThruEngine2->SetVirtualizer(mCur2chVirtualizer.state, 500);
}

- (void)updateEqualizer {
    int loudnessCorrection = mCur2chLoudness.tag;
    bool eq = false;
    for (int i = 0; i < 6; i ++) {
        if (fabsf(mEqualizerLevels[i]) > 1e-2f) {
            eq = true;
        }
    }
    mThruEngine2->SetEqualizer(loudnessCorrection != 100 || eq, mEqualizerLevels, loudnessCorrection);
}

- (IBAction)presetChanged:(id)sender
{
    for (NSMenuItem *item in m2chPreset.itemArray) {
        item.state = NSOffState;
    }
    mCur2chPreset = sender;
    mCur2chPreset.state = NSOnState;

    NSInteger preset = [m2chPreset indexOfItem:mCur2chPreset];
    if (preset < 0 && preset >= 12) {
        return;
    }
    
    for (int i = 0; i < 6; i ++) {
        mEqualizerLevels[i] = presets[preset][i];
    }
    [mFrequencyResponseController setLevels:mEqualizerLevels];
    [self updateEqualizer];
}

- (IBAction)loudnessChanged:(id)sender
{
    for (NSMenuItem *item in m2chLoudness.itemArray) {
        item.state = NSOffState;
    }
    mCur2chLoudness = sender;
    mCur2chLoudness.state = NSOnState;
    [self updateEqualizer];
}

- (IBAction)showFrequencyResponseWindow:(id)sender {
	[mFrequencyResponseController showWindow:sender];
}

- (void)frequencyResponseChanged:(float)dB forBand:(int)band {
    mEqualizerLevels[band] = dB;
    [self updateEqualizer];
}

- (void)readGlobalPrefs
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *s;
    NSNumber *n;
    NSMenuItem *item;
    
    s = [defaults objectForKey:@"2ch"];
    if (! s) {
        s = [m2chOutputDevice itemAtIndex:0].title;
    }
    item = [m2chOutputDevice itemWithTitle:s];
    [self outputDeviceSelected:item];

	n = [defaults objectForKey:@"2chBuf"];
    if (! n) {
        n = [NSNumber numberWithInt:512];
    }
    [self bufferSizeChanged2ch:[m2chBuffer itemWithTag:n.intValue]];
	
    n = [defaults objectForKey:@"virtualizer"];
    if (! n) {
        n = [NSNumber numberWithInt:1];
    }
    /* State will be flipped by headsetSelected, so it appears inverted here. */
    mCur2chVirtualizer.state = n.intValue ? NSOffState : NSOnState;
    [self headsetSelected:mCur2chVirtualizer];

    n = [defaults objectForKey:@"loudness"];
    if (! n) {
        n = [NSNumber numberWithInt:100];
    }
    [self loudnessChanged:[m2chLoudness itemWithTag:n.intValue]];

    NSArray *a = [defaults objectForKey:@"equalizer"];
    if (a) {
        for (int i = 0; i < 6; i ++) {
            NSNumber *n = [a objectAtIndex:i];
            mEqualizerLevels[i] = n.floatValue;
        }
    } else {
        for (int i = 0; i < 6; i ++) {
            mEqualizerLevels[i] = 0;
        }
    }
    
    /* Now scan for matching preset. */
    for (int i = 0; i < 12; i ++) {
        bool match = true;
        for (int j = 0; j < 6; j ++) {
            if (mEqualizerLevels[j] != presets[i][j]) {
                match = false;
                break;
            }
        }
        if (match) {
            [self presetChanged:[m2chPreset itemAtIndex:i]];
            break;
        }
    }
}
		
- (void)writeGlobalPrefs
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:mCur2chDevice.title forKey:@"2ch"];
    [defaults setObject:[NSNumber numberWithInt:mCur2chBuffer.tag] forKey:@"2chBuf"];
    [defaults setObject:[NSNumber numberWithInt:mCur2chVirtualizer.state] forKey:@"virtualizer"];
    [defaults setObject:[NSNumber numberWithInt:mCur2chLoudness.tag] forKey:@"loudness"];
    NSMutableArray *levels = [[NSMutableArray alloc] init];
    for (int i = 0; i < 6; i ++) {
        [levels addObject:[NSNumber numberWithFloat:mEqualizerLevels[i]]];
    }
    [defaults setObject:levels forKey:@"equalizer"];
    [levels release];
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
