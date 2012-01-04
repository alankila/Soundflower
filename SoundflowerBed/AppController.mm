/*	
*/

#import "AppController.h"

#include "AudioThruEngine.h"

@implementation AppController

AudioThruEngine	*gThruEngine2 = NULL;
AudioThruEngine	*gThruEngine16 = NULL;
Boolean startOnAwake = false;

void	CheckErr(OSStatus err)
{
	if (err) {
		printf("error %-4.4s %i\n", (char *)&err, (int)err);
		throw 1;
	}
}

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
				else if (gThruEngine16->IsRunning() && gThruEngine16->GetInputDevice() == inDevice)	
					[NSThread detachNewThreadSelector:@selector(srChanged16ch) toTarget:app withObject:nil];
			} 
			else {
				if (inChannel == 0) {
					if (gThruEngine2->IsRunning() && gThruEngine2->GetOutputDevice() == inDevice)
						[NSThread detachNewThreadSelector:@selector(srChanged2chOutput) toTarget:app withObject:nil];
					else if (gThruEngine16->IsRunning() && gThruEngine16->GetOutputDevice() == inDevice)
						[NSThread detachNewThreadSelector:@selector(srChanged16chOutput) toTarget:app withObject:nil];
				}
			}
			break;
	
		case kAudioDevicePropertyDataSource:
			if (gThruEngine2->IsRunning() && gThruEngine2->GetOutputDevice() == inDevice)
				[NSThread detachNewThreadSelector:@selector(srChanged2chOutput) toTarget:app withObject:nil];
			else if (gThruEngine16->IsRunning() && gThruEngine16->GetOutputDevice() == inDevice)
				[NSThread detachNewThreadSelector:@selector(srChanged16chOutput) toTarget:app withObject:nil];
			break;
			
		case kAudioDevicePropertyStreams:
		case kAudioDevicePropertyStreamConfiguration:
			if (!isInput) {
				if (inChannel == 0) {
					if (gThruEngine2->GetOutputDevice() == inDevice || gThruEngine16->GetOutputDevice() == inDevice) {
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
	mSuspended16chDevice = mCur16chDevice;
	
	[self outputDeviceSelected:[mMenu itemAtIndex:1]];
	[self outputDeviceSelected:[mMenu itemAtIndex:(m16StartIndex+1)]];
	
	[pool release];
}

- (IBAction)resume
{
	if (mSuspended2chDevice) {
		[self outputDeviceSelected:mSuspended2chDevice];
		mCur2chDevice = mSuspended2chDevice;
		mSuspended2chDevice = NULL;
	}
	if (mSuspended16chDevice) {
		[self outputDeviceSelected:mSuspended16chDevice];
		mCur16chDevice = mSuspended16chDevice;
		mSuspended16chDevice = NULL;
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


- (IBAction)srChanged16ch
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	gThruEngine16->Mute();
	OSStatus err = gThruEngine16->MatchSampleRate(true);

	NSMenuItem *curdev = mCur16chDevice;
	[self outputDeviceSelected:[mMenu itemAtIndex:(m16StartIndex+1)]];
	if (err == kAudioHardwareNoError) {
		[self outputDeviceSelected:curdev];
	}
	gThruEngine16->Mute(false);
	
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

- (IBAction)srChanged16chOutput
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	gThruEngine16->Mute();
	OSStatus err = gThruEngine16->MatchSampleRate(false);
			
	NSMenuItem	*curdev = mCur16chDevice;
	[self outputDeviceSelected:[mMenu itemAtIndex:(m16StartIndex+1)]];
	if (err == kAudioHardwareNoError) {
		[self outputDeviceSelected:curdev];
	}
	gThruEngine16->Mute(false);
	
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
		
	if (mNchnls16 != gThruEngine16->GetOutputNchnls()) {
		NSMenuItem	*curdev = mCur16chDevice;
		[self outputDeviceSelected:[mMenu itemAtIndex:(m16StartIndex+1)]];
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
		
	dev = gThruEngine16->GetOutputDevice();
	for ( i= thelist.begin(); i != thelist.end(); ++i)
		if ((*i).mID == dev) 
			break;
	if (i == thelist.end()) // we didn't find it, turn selection to none
		[self outputDeviceSelected:[mMenu itemAtIndex:(m16StartIndex+1)]];
	else
		[self buildRoutingMenu:NO];

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
	mSoundflower16Device = 0;
	mNchnls2 = 0;
	mNchnls16 = 0;
	
	mSuspended2chDevice = NULL;
	mSuspended16chDevice = NULL;
	
	return self;
}

- (void)dealloc
{
	[self RemoveListeners];
	delete mOutputDeviceList;
		
	[super dealloc];
}

- (void)buildRoutingMenu:(BOOL)is2ch
{
	NSMenuItem *hostMenu = (is2ch ? m2chMenu : m16chMenu);
	UInt32 nchnls = (is2ch ? mNchnls2 = gThruEngine2->GetOutputNchnls() : mNchnls16 = gThruEngine16->GetOutputNchnls());
	AudioDeviceID outDev = (is2ch ? gThruEngine2->GetOutputDevice(): gThruEngine16->GetOutputDevice());
	SEL menuAction = (is2ch ? @selector(routingChanged2ch:): @selector(routingChanged16ch:));
	
	for (UInt32 menucount = 0; menucount < (is2ch ? 2 : 16); menucount++) {
		NSMenuItem *superMenu = [[hostMenu submenu] itemAtIndex:(menucount+3)];
		
		NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Output Device Channel"];
		NSMenuItem *item;
		
		AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
		char *name = 0;
		for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i) {
			if ((*i).mID == outDev)
				name = (*i).mName;
		}
		
		item = [menu addItemWithTitle:@"None" action:menuAction keyEquivalent:@""];
		[item setState:NSOnState];
		
		for (UInt32 c = 1; c <= nchnls; ++c) {
			item = [menu addItemWithTitle:[NSString stringWithFormat:@"%s [%d]", name, c] action:menuAction keyEquivalent:@""];
			[item setTarget:self];
			
			// set check marks according to route map	
			if (c == 1 + (is2ch ? (UInt32)gThruEngine2->GetChannelMap(menucount) : (UInt32)gThruEngine16->GetChannelMap(menucount))) {
				[[menu itemAtIndex:0] setState:NSOffState];
				[item setState:NSOnState];
			}
		}
		
		[superMenu setSubmenu:menu];
        [menu release];
	}
}

- (void)buildMenu
{
	NSMenuItem *item;

	mMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];
		
    m2chMenu = [mMenu addItemWithTitle:@"Soundflower (2ch)" action:@selector(doNothing) keyEquivalent:@""];
    [m2chMenu setImage:[NSImage imageNamed:@"sf2"]];
    [m2chMenu setTarget:self];
        
    NSMenu *submenu = [[NSMenu alloc] initWithTitle:@"2ch submenu"];
    NSMenuItem *bufItem = [submenu addItemWithTitle:@"Buffer Size" action:@selector(doNothing) keyEquivalent:@""];
    m2chBuffer = [[NSMenu alloc] initWithTitle:@"2ch Buffer"];
    for (int i = 64; i < 4096; i *= 2) {
        item = [m2chBuffer addItemWithTitle:[NSString stringWithFormat:@"%d", i] action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
        [item setTarget:self];
    }
    [bufItem setSubmenu:m2chBuffer];

    [submenu addItem:[NSMenuItem separatorItem]];
					
    [submenu addItemWithTitle:@"Routing" action:NULL keyEquivalent:@""];
    item = [submenu addItemWithTitle:@"Channel 1" action:@selector(doNothing) keyEquivalent:@""];
    [item setTarget:self];	
    item = [submenu addItemWithTitle:@"Channel 2" action:@selector(doNothing) keyEquivalent:@""];
    [item setTarget:self];	
		
    [submenu addItem:[NSMenuItem separatorItem]];
    mCur2chHeadsetFiltering = [submenu addItemWithTitle:@"Headset filtering" action:@selector(headsetSelected:) keyEquivalent:@""];
    [mCur2chHeadsetFiltering setTarget:self];
    
    [m2chMenu setSubmenu:submenu];

    item = [mMenu addItemWithTitle:@"None (OFF)" action:@selector(outputDeviceSelected:) keyEquivalent:@""];
    [item setTarget:self];
    [item setState:NSOnState];
    mCur2chDevice = item;
		
    AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
    int index = 0;
    for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i) {
        AudioDevice ad((*i).mID, false);
        if (ad.CountChannels()) {
            item = [mMenu addItemWithTitle:[NSString stringWithUTF8String:(*i).mName] action:@selector(outputDeviceSelected:) keyEquivalent:@""];
            [item setTarget:self];
            mMenuID2[index++] = (*i).mID;
        }
    }
	
	[mMenu addItem:[NSMenuItem separatorItem]];
	
    m16chMenu = [mMenu addItemWithTitle:@"Soundflower (16ch)" action:@selector(doNothing) keyEquivalent:@""];
    [m16chMenu setImage:[NSImage imageNamed:@"sf16"]];
    [m16chMenu setTarget:self];
    m16StartIndex = [mMenu indexOfItem:m16chMenu];
    submenu = [[NSMenu alloc] initWithTitle:@"16ch submenu"];
        
    bufItem = [submenu addItemWithTitle:@"Buffer Size" action:@selector(doNothing) keyEquivalent:@""];
    m16chBuffer = [[NSMenu alloc] initWithTitle:@"16ch Buffer"];
    for (int i = 64; i < 4096; i *= 2) {
        item = [m16chBuffer addItemWithTitle:[NSString stringWithFormat:@"%d", i] action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
        [item setTarget:self];
    }
    [bufItem setSubmenu:m16chBuffer];

    [submenu addItem:[NSMenuItem separatorItem]];
			
    [submenu addItemWithTitle:@"Routing" action:NULL keyEquivalent:@""];
    for (int i = 1; i <= 16; i ++) {
        item = [submenu addItemWithTitle:[NSString stringWithFormat:@"Channel %d", i] action:@selector(doNothing) keyEquivalent:@""];
        [item setTarget:self];	
    }
    [m16chMenu setSubmenu:submenu];
		
    item = [mMenu addItemWithTitle:@"None (OFF)" action:@selector(outputDeviceSelected:) keyEquivalent:@""];
    [item setTarget:self];
    [item setState:NSOnState];
    mCur16chDevice = item;
		
    thelist = mOutputDeviceList->GetList();
    index = 0;
    for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i) {
        AudioDevice ad((*i).mID, false);
        if (ad.CountChannels()) {
            item = [mMenu addItemWithTitle:[NSString stringWithUTF8String:(*i).mName] action:@selector(outputDeviceSelected:) keyEquivalent:@""];
            [item setTarget:self];	
            mMenuID16[index++] = (*i).mID;
        }
    }
		
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
		else if (0 == strcmp("Soundflower (16ch)", (*i).mName)) {
			mSoundflower16Device = (*i).mID;
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
	
	//[sbItem setTitle:@"ее"];
	[mSbItem setImage:[NSImage imageNamed:@"menuIcon"]];
	[mSbItem setHighlightMode:YES];
	
	[self buildMenu];
	
	if (mSoundflower2Device && mSoundflower16Device) {
		gThruEngine2 = new AudioThruEngine;
		gThruEngine2->SetInputDevice(mSoundflower2Device);
		
		gThruEngine16 = new AudioThruEngine;
		gThruEngine16->SetInputDevice(mSoundflower16Device);

		gThruEngine2->Start();
		gThruEngine16->Start();
		
		// build default 'off' channel routing menus
		[self buildRoutingMenu:YES];
		[self buildRoutingMenu:NO];
		
		// now read prefs
		[self readGlobalPrefs];
	}
	
	// ask to be notified on system sleep to avoid a crash
	IONotificationPortRef  notify;
    io_object_t            anIterator;

    root_port = IORegisterForSystemPower(self, &notify, MySleepCallBack, &anIterator);
    if ( !root_port ) {
		printf("IORegisterForSystemPower failed\n");
    }
	else
		CFRunLoopAddSource(CFRunLoopGetCurrent(),
                        IONotificationPortGetRunLoopSource(notify),
                        kCFRunLoopCommonModes);
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	if (gThruEngine2)
		gThruEngine2->Stop();
		
	if (gThruEngine16)
		gThruEngine16->Stop();
		
	if (mSoundflower2Device && mSoundflower16Device)
		[self writeGlobalPrefs];
}


- (IBAction)bufferSizeChanged2ch:(id)sender
{
    for (NSMenuItem *item in m2chBuffer.itemArray) {
        [item setState:NSOffState];
    }
	[sender setState:NSOnState];

    mCur2chBuffer = sender;
	UInt32 size = [[sender title] intValue];
    NSLog(@"2ch buffer: %@", [sender title]);
	gThruEngine2->SetBufferSize(size);
}

- (IBAction)bufferSizeChanged16ch:(id)sender
{
	for (NSMenuItem *item in m16chBuffer.itemArray) {
        [item setState:NSOffState];
    }
	[sender setState:NSOnState];

    mCur16chBuffer = sender;
	UInt32 size = [[sender title] intValue];
    NSLog(@"16ch buffer: %@", [sender title]);
    gThruEngine16->SetBufferSize(size);
}

- (IBAction)routingChanged2ch:(id)outDevChanItem
{
	NSMenu *outDevMenu = [outDevChanItem menu];
	NSMenu *superMenu = [outDevMenu supermenu];

	int sfChan = [superMenu indexOfItemWithSubmenu:outDevMenu] - 3;
	int outDevChan = [outDevMenu indexOfItem:outDevChanItem];	
	gThruEngine2->SetChannelMap(sfChan, outDevChan-1);
    
    for (NSMenuItem *item in outDevMenu.itemArray) {
        [item setState:NSOffState];
    }		
	[outDevChanItem setState:NSOnState];
		
	[self writeDevicePrefs:YES];
}

- (IBAction)routingChanged16ch:(id)outDevChanItem
{
	NSMenu *outDevMenu = [outDevChanItem menu];
	NSMenu *superMenu = [outDevMenu supermenu];
	int sfChan = [superMenu indexOfItemWithSubmenu:outDevMenu] - 3;
	int outDevChan = [outDevMenu indexOfItem:outDevChanItem];	
	
	gThruEngine16->SetChannelMap(sfChan, outDevChan-1);
	
    for (NSMenuItem *item in outDevMenu.itemArray) {
        [item setState:NSOffState];
    }		
	[outDevChanItem setState:NSOnState];

	// write to prefs
	[self writeDevicePrefs:NO];
}

- (IBAction)outputDeviceSelected:(id)sender
{
	int val = [mMenu indexOfItem:sender];
	if (val < m16StartIndex) {
        NSLog(@"Changing 2ch device to: %@", [sender title]);
		val -= 2;
		gThruEngine2->SetOutputDevice((val < 0 ? kAudioDeviceUnknown : mMenuID2[val]));
		
		[mCur2chDevice setState:NSOffState];
		[sender setState:NSOnState];
		mCur2chDevice = sender;
		
		[self readDevicePrefs:YES];
		[self buildRoutingMenu:YES];
	}
	else {
        NSLog(@"Changing 16ch device to: %@", [sender title]);
        val -= m16StartIndex;
        
		val -= 2;
		gThruEngine16->SetOutputDevice( (val < 0 ? kAudioDeviceUnknown : mMenuID16[val]) );

		[mCur16chDevice setState:NSOffState];
		[sender setState:NSOnState];
		mCur16chDevice = sender;
		
		[self readDevicePrefs:NO];
		[self buildRoutingMenu:NO];
	}
}

- (IBAction)headsetSelected:(id)sender
{
    [sender setState:![sender state]];
    gThruEngine2->SetVirtualizer([sender state], 500);
}

- (IBAction)equalizerChanged:(id)sender
{
    float presets[][6] = {
        { 0, 0, 0, 0, 0 }
    };
    int preset = 0;
    int loudnessCorrection = 100;
    gThruEngine2->SetEqualizer(preset != 0 && loudnessCorrection != 100, presets[preset], loudnessCorrection);
}

- (void)doNothing
{
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
    item = [mMenu itemWithTitle:v];
    if (item) {
        [self outputDeviceSelected:item];
	}

	v = [defaults valueForKey:@"16ch"];
    if (! v) {
        v = @"None (OFF)";
    }
    /* lamentable hack, this finds the 2ch items at top, the 16ch shit is right below... */
    item = [mMenu itemWithTitle:v];
    item = [mMenu itemAtIndex:[mMenu indexOfItem:item] + m16StartIndex];
    if (item) {
        [self outputDeviceSelected:item];
	}

	v = [defaults valueForKey:@"2chBuf"];
    if (! v) {
        v = @"512";
    }
    [self bufferSizeChanged2ch:[m2chBuffer itemWithTitle:v]];
	
	v = [defaults valueForKey:@"16chBuf"];
    if (! v) {
        v = @"512";
    }
    [self bufferSizeChanged16ch:[m16chBuffer itemWithTitle:v]];
    
    v = [defaults valueForKey:@"headsetFiltering"];
    if (! v) {
        v = @"0";
    }
    /* State will be flipped by headsetSelected, so it appears inverted here. */
    mCur2chHeadsetFiltering.state = [v intValue] ? NSOffState : NSOnState;
    [self headsetSelected:mCur2chHeadsetFiltering];
    
}
		
- (void)writeGlobalPrefs
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setValue:mCur2chDevice.title forKey:@"2ch"];
    [defaults setValue:mCur16chDevice.title forKey:@"16ch"];
    [defaults setValue:mCur2chBuffer.title forKey:@"2chBuf"];
    [defaults setValue:mCur16chBuffer.title forKey:@"16chBuf"];
    [defaults setValue:[NSString stringWithFormat:@"%ld", mCur2chHeadsetFiltering.state] forKey:@"headsetFiltering"];
    [defaults synchronize];
}

- (NSString *)formDevicePrefName:(BOOL)is2ch
{
	if (is2ch) {
        return [mCur2chDevice.title stringByAppendingString:@".2chrouting"];
	} else {
        return [mCur16chDevice.title stringByAppendingString:@".16chrouting"];
	}
}

- (void)readDevicePrefs:(BOOL)is2ch
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSArray *value = [defaults valueForKey:[self formDevicePrefName:is2ch]];
    
	AudioThruEngine	*thruEng = (is2ch ? gThruEngine2 : gThruEngine16);
	NSUInteger numChans = (is2ch ? 2 : 16);
    if (value) {
        for (NSUInteger i = 0; i < numChans; i++) {
            NSInteger val = [[value objectAtIndex:i] intValue];
            thruEng->SetChannelMap(i, val - 1);
        }
	} else {
		for (NSUInteger i = 0; i < numChans; i++) {
			thruEng->SetChannelMap(i, i);
        }
	}
}

- (void)writeDevicePrefs:(BOOL)is2ch
{
    NSMutableArray *channelMap = [[NSMutableArray alloc] init];
	
	AudioThruEngine	*thruEng = (is2ch ? gThruEngine2 : gThruEngine16);
	NSUInteger numChans = (is2ch ? 2 : 16);
	for (NSUInteger i = 0; i < numChans; i++) {	
		UInt32 val = thruEng->GetChannelMap(i) + 1;
        [channelMap addObject:[NSString stringWithFormat:@"%d", val]];
	}
    
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setValue:channelMap forKey:[self formDevicePrefName:is2ch]];
    [defaults synchronize];
    
    [channelMap release];
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
