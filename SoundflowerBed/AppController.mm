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
			
	NSMenuItem		*curdev = mCur2chDevice;
	[self outputDeviceSelected:[mMenu itemAtIndex:1]];
	if (err == kAudioHardwareNoError) {
		//usleep(1000);
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
		//usleep(1000);
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
			
	// restart devices
	NSMenuItem		*curdev = mCur2chDevice;
	[self outputDeviceSelected:[mMenu itemAtIndex:1]];
	if (err == kAudioHardwareNoError) {
		//usleep(1000);
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
			
	// restart devices
	NSMenuItem	*curdev = mCur16chDevice;
	[self outputDeviceSelected:[mMenu itemAtIndex:(m16StartIndex+1)]];
	if (err == kAudioHardwareNoError) {
		//usleep(1000);
		[self outputDeviceSelected:curdev];
	}
	gThruEngine16->Mute(false);
	
	[pool release];
}


- (IBAction)checkNchnls
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if (mNchnls2 != gThruEngine2->GetOutputNchnls())
	 {
		NSMenuItem	*curdev = mCur2chDevice;
		[self outputDeviceSelected:[mMenu itemAtIndex:1]];
		//usleep(1000);
		[self outputDeviceSelected:curdev];
	}
		
	if (mNchnls16 != gThruEngine16->GetOutputNchnls()) 
	{
		NSMenuItem	*curdev = mCur16chDevice;
		[self outputDeviceSelected:[mMenu itemAtIndex:(m16StartIndex+1)]];
		//usleep(1000);
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
	}
}

- (void)buildMenu
{
	NSMenuItem *item;

	mMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];
		
	if (mSoundflower2Device) {
		m2chMenu = [mMenu addItemWithTitle:@"Soundflower (2ch)" action:@selector(doNothing) keyEquivalent:@""];
		[m2chMenu setImage:[NSImage imageNamed:@"sf2"]];
		[m2chMenu setTarget:self];
			NSMenu *submenu = [[NSMenu alloc] initWithTitle:@"2ch submenu"];
			NSMenuItem *bufItem = [submenu addItemWithTitle:@"Buffer Size" action:@selector(doNothing) keyEquivalent:@""];
				m2chBuffer = [[NSMenu alloc] initWithTitle:@"2ch Buffer"];
				item = [m2chBuffer addItemWithTitle:@"64" action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
				[item setTarget:self];	
				item = [m2chBuffer addItemWithTitle:@"128" action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
				[item setTarget:self];	
				item = [m2chBuffer addItemWithTitle:@"256" action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
				[item setTarget:self];	
				item = [m2chBuffer addItemWithTitle:@"512" action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
				[item setTarget:self];	
				[item setState:NSOnState]; // default
				mCur2chBufferSize = item;
				item = [m2chBuffer addItemWithTitle:@"1024" action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
				[item setTarget:self];
				item = [m2chBuffer addItemWithTitle:@"2048" action:@selector(bufferSizeChanged2ch:) keyEquivalent:@""];
				[item setTarget:self];
			[bufItem setSubmenu:m2chBuffer];

			[submenu addItem:[NSMenuItem separatorItem]];
					
			item = [submenu addItemWithTitle:@"Routing" action:NULL keyEquivalent:@""];
			item = [submenu addItemWithTitle:@"Channel 1" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 2" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
		
			// iSchemy's edit
			//
			[submenu addItem:[NSMenuItem separatorItem]];
		
			[[submenu addItemWithTitle:@"Clone to all channels" action:@selector(cloningChanged:) keyEquivalent:@""] setTarget:self];
			//
			// end
		
		[m2chMenu setSubmenu:submenu];
	
	
		
		item = [mMenu addItemWithTitle:@"None (OFF)" action:@selector(outputDeviceSelected:) keyEquivalent:@""];
		[item setTarget:self];
		[item setState:NSOnState];
		mCur2chDevice = item;
		
		AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
		int index = 0;
		for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i) {
			AudioDevice ad((*i).mID, false);
			if (ad.CountChannels()) 
			{
                /* FIXME: is this right encoding? Or better, isn't there NSString in there somwhere? */
				item = [mMenu addItemWithTitle:[NSString stringWithCString:(*i).mName encoding:kCFStringEncodingUTF8] action:@selector(outputDeviceSelected:) keyEquivalent:@""];
				[item setTarget:self];
				mMenuID2[index++] = (*i).mID;
			}
		}
	}
	else {
		item = [mMenu addItemWithTitle:@"Soundflower Is Not Installed!!" action:NULL keyEquivalent:@""];
		[item setTarget:self];
	}
	
	[mMenu addItem:[NSMenuItem separatorItem]];
	
	
	if (mSoundflower16Device) {
	
		m16chMenu = [mMenu addItemWithTitle:@"Soundflower (16ch)" action:@selector(doNothing) keyEquivalent:@""];
		[m16chMenu setImage:[NSImage imageNamed:@"sf16"]];
		[m16chMenu setTarget:self];
		m16StartIndex = [mMenu indexOfItem:m16chMenu];
			NSMenu *submenu = [[NSMenu alloc] initWithTitle:@"16ch submenu"];
				NSMenuItem *bufItem = [submenu addItemWithTitle:@"Buffer Size" action:@selector(doNothing) keyEquivalent:@""];
				m16chBuffer = [[NSMenu alloc] initWithTitle:@"16ch Buffer"];
				item = [m16chBuffer addItemWithTitle:@"64" action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
				[item setTarget:self];	
				item = [m16chBuffer addItemWithTitle:@"128" action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
				[item setTarget:self];	
				item = [m16chBuffer addItemWithTitle:@"256" action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
				[item setTarget:self];	
				item = [m16chBuffer addItemWithTitle:@"512" action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
				[item setTarget:self];	
				[item setState:NSOnState]; // default
				mCur16chBufferSize = item;
				item = [m16chBuffer addItemWithTitle:@"1024" action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
				[item setTarget:self];
				item = [m16chBuffer addItemWithTitle:@"2048" action:@selector(bufferSizeChanged16ch:) keyEquivalent:@""];
				[item setTarget:self];
			[bufItem setSubmenu:m16chBuffer];

			[submenu addItem:[NSMenuItem separatorItem]];
			
			item = [submenu addItemWithTitle:@"Routing" action:NULL keyEquivalent:@""];
			item = [submenu addItemWithTitle:@"Channel 1" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 2" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 3" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 4" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 5" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 6" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 7" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 8" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];
			item = [submenu addItemWithTitle:@"Channel 9" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 10" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 11" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 12" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];
			item = [submenu addItemWithTitle:@"Channel 13" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 14" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 15" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
			item = [submenu addItemWithTitle:@"Channel 16" action:@selector(doNothing) keyEquivalent:@""];
			[item setTarget:self];	
		[m16chMenu setSubmenu:submenu];
	
	
		item = [mMenu addItemWithTitle:@"None (OFF)" action:@selector(outputDeviceSelected:) keyEquivalent:@""];
		[item setTarget:self];
		[item setState:NSOnState];
		mCur16chDevice = item;
		
		AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
		int index = 0;
		for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i) {
			AudioDevice ad((*i).mID, false);
			if (ad.CountChannels()) 
			{
                /* FIXME: right encoding? */
				item = [mMenu addItemWithTitle:[NSString stringWithCString:(*i).mName encoding:kCFStringEncodingUTF8] action:@selector(outputDeviceSelected:) keyEquivalent:@""];
				[item setTarget:self];	
				mMenuID16[index++] = (*i).mID;
			}
		}
		
		[mMenu addItem:[NSMenuItem separatorItem]];
	}
	
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
		[ self RemoveListeners];
		delete mOutputDeviceList;
	}
	
	mOutputDeviceList = new AudioDeviceList(false);
	[ self InstallListeners];
	
	// find soundflower devices, store and remove them from our output list
	AudioDeviceList::DeviceList &thelist = mOutputDeviceList->GetList();
	int index = 0;
	for (AudioDeviceList::DeviceList::iterator i = thelist.begin(); i != thelist.end(); ++i, ++index) {
		if (0 == strcmp("Soundflower (2ch)", (*i).mName)) {
			mSoundflower2Device = (*i).mID;
			AudioDeviceList::DeviceList::iterator toerase = i;
			i--;
			thelist.erase(toerase);
		}
		else if (0 == strcmp("Soundflower (16ch)", (*i).mName)) {
			mSoundflower16Device = (*i).mID;
			AudioDeviceList::DeviceList::iterator toerase = i;
			i--;
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
	
	//[sbItem setTitle:@"��"];
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
	UInt32 val = [m2chBuffer indexOfItem:sender];
	UInt32 size = 64 << val;
	gThruEngine2->SetBufferSize(size);

	[mCur2chBufferSize setState:NSOffState];
	[sender setState:NSOnState];
	mCur2chBufferSize = sender;
}

- (IBAction)bufferSizeChanged16ch:(id)sender
{
	UInt32 val = [m2chBuffer indexOfItem:sender];
	UInt32 size = 64 << val;
	gThruEngine16->SetBufferSize(size);

	[mCur16chBufferSize setState:NSOffState];
	[sender setState:NSOnState];
	mCur16chBufferSize = sender;
}

// iSchemy's edit
//
// action for item was clicked
- (IBAction)cloningChanged:(id)sender 
{
	// change item's state
	[sender setState:([sender state]==NSOnState) ? NSOffState : NSOnState];
	gThruEngine2->SetCloneChannels([sender state]==NSOnState);
	[self writeDevicePrefs:YES];
}

// preferences read
- (IBAction)cloningChanged:(id)sender cloneChannels:(bool)clone
{
	gThruEngine2->SetCloneChannels(clone);
	[sender setState:(clone ? NSOnState : NSOffState)];
}
//
// end

- (IBAction)routingChanged2ch:(id)outDevChanItem
{
	NSMenu *outDevMenu = [outDevChanItem menu];
	NSMenu *superMenu = [outDevMenu supermenu];
	int sfChan = [superMenu indexOfItemWithSubmenu:outDevMenu] - 3;
	int outDevChan = [outDevMenu indexOfItem:outDevChanItem];	
	
	// set the new channel map
	gThruEngine2->SetChannelMap(sfChan, outDevChan-1);
	
	// turn off all check marks
	for (int i = 0; i < [outDevMenu numberOfItems]; i++)
		[[outDevMenu itemAtIndex:i] setState:NSOffState];
		
	// set this one
	[outDevChanItem setState:NSOnState];
		
	// write to prefs
	[self writeDevicePrefs:YES];
}

- (IBAction)routingChanged16ch:(id)outDevChanItem
{
	NSMenu *outDevMenu = [outDevChanItem menu];
	NSMenu *superMenu = [outDevMenu supermenu];
	int sfChan = [superMenu indexOfItemWithSubmenu:outDevMenu] - 3;
	int outDevChan = [outDevMenu indexOfItem:outDevChanItem];	
	
	gThruEngine16->SetChannelMap(sfChan, outDevChan-1);
	
	// turn off all check marks
	for (int i = 0; i < [outDevMenu numberOfItems]; i++)
		[[outDevMenu itemAtIndex:i] setState:NSOffState];
		
	// set this one
	[outDevChanItem setState:NSOnState];
	
	// write to prefs
	[self writeDevicePrefs:NO];
}

- (IBAction)outputDeviceSelected:(id)sender
{
	int val = [mMenu indexOfItem:sender];
	if (val < m16StartIndex) {
		val -= 2;
		
		// if 'None' was selected, our val will be == -1, which will return a NULL
		// device from the list, which is what we want anyway, and seems to work
		// here -- probably should check to see if there are any potential problems
		// and handle this more properly
		gThruEngine2->SetOutputDevice( (val < 0 ? kAudioDeviceUnknown : mMenuID2[val]) );
		//[self updateThruLatency];	
		
		[mCur2chDevice setState:NSOffState];
		[sender setState:NSOnState];
		mCur2chDevice = sender;
		
		// get the channel routing from the prefs
		[self readDevicePrefs:YES];
	
		// now set the menu
		[self buildRoutingMenu:YES];
	}
	else {
		val -= (m16StartIndex+2);
		
		// if 'None' was selected, our val will be == -1, which will return a NULL
		// device from the list, which is what we want anyway, and seems to work
		// here -- probably should check to see if there are any potential problems
		// and handle this more properly
		gThruEngine16->SetOutputDevice( (val < 0 ? kAudioDeviceUnknown : mMenuID16[val]) );
		//[self updateThruLatency];

		[mCur16chDevice setState:NSOffState];
		[sender setState:NSOnState];
		mCur16chDevice = sender;
		
		// get the channel routing from the prefs
		[self readDevicePrefs:NO];
	
		// now set the menu
		[self buildRoutingMenu:NO];
	}
}



- (void)doNothing
{

}

- (void)readGlobalPrefs
{
	CFStringRef strng  = (CFStringRef) CFPreferencesCopyAppValue(CFSTR("2ch Output Device"), kCFPreferencesCurrentApplication);
	if (strng) {
		char name[64];
		CFStringGetCString(strng, name, 64, kCFStringEncodingUTF8);
		NSMenuItem *item = [mMenu itemWithTitle:[NSString stringWithCString:name encoding:kCFStringEncodingUTF8]];
		if (item)
			[self outputDeviceSelected:item];
	}
	
	strng  = (CFStringRef) CFPreferencesCopyAppValue(CFSTR("16ch Output Device"), kCFPreferencesCurrentApplication);
	if (strng) {
		char name[64];
		CFStringGetCString(strng, name, 64, kCFStringEncodingUTF8);
		
		// itemWithTitle only returns the first instance, and we need to find the second one, so
		// make calculations based on index #
		int index = [mMenu indexOfItemWithTitle:[NSString stringWithCString:name encoding:kCFStringEncodingUTF8]];
		if (index >= 0)
			[self outputDeviceSelected:[mMenu itemAtIndex:(m16StartIndex+index)]];
	}
	
	CFNumberRef num = (CFNumberRef) CFPreferencesCopyAppValue(CFSTR("2ch Buffer Size"), kCFPreferencesCurrentApplication);
	if (num) {
		UInt32 val;
		CFNumberGetValue(num, kCFNumberLongType, &val);	
		CFRelease(num);
		
		switch (val) {
			case 64:
				[self bufferSizeChanged2ch:[m2chBuffer itemAtIndex:0]];
				break;
			case 128:
				[self bufferSizeChanged2ch:[m2chBuffer itemAtIndex:1]];
				break;
			case 256:
				[self bufferSizeChanged2ch:[m2chBuffer itemAtIndex:2]];
				break;
			case 1024:
				[self bufferSizeChanged2ch:[m2chBuffer itemAtIndex:4]];
				break;
			case 2048:
				[self bufferSizeChanged2ch:[m2chBuffer itemAtIndex:5]];
				break;
				
			case 512:
			default:
				[self bufferSizeChanged2ch:[m2chBuffer itemAtIndex:3]];
				break;
		}
	}
	
	num = (CFNumberRef) CFPreferencesCopyAppValue(CFSTR("16ch Buffer Size"), kCFPreferencesCurrentApplication);
	if (num) {
		UInt32 val;
		CFNumberGetValue(num, kCFNumberLongType, &val);	
		CFRelease(num);
		
		switch (val) {
			case 64:
				[self bufferSizeChanged16ch:[m16chBuffer itemAtIndex:0]];
				break;
			case 128:
				[self bufferSizeChanged16ch:[m16chBuffer itemAtIndex:1]];
				break;
			case 256:
				[self bufferSizeChanged16ch:[m16chBuffer itemAtIndex:2]];
				break;
			case 1024:
				[self bufferSizeChanged16ch:[m16chBuffer itemAtIndex:4]];
				break;
			case 2048:
				[self bufferSizeChanged16ch:[m16chBuffer itemAtIndex:5]];
				break;
				
			case 512:
			default:
				[self bufferSizeChanged16ch:[m16chBuffer itemAtIndex:3]];
				break;
		}
	}
}
		
- (void)writeGlobalPrefs
{
	CFStringRef cfstr = CFStringCreateWithCString(kCFAllocatorSystemDefault, [[mCur2chDevice title] cStringUsingEncoding:kCFStringEncodingUTF8], kCFStringEncodingUTF8);
	CFPreferencesSetAppValue(CFSTR("2ch Output Device"), cfstr, kCFPreferencesCurrentApplication);
	CFRelease(cfstr); 
	
	cfstr = CFStringCreateWithCString(kCFAllocatorSystemDefault, [[mCur16chDevice title] cStringUsingEncoding:kCFStringEncodingUTF8], kCFStringEncodingUTF8);
	CFPreferencesSetAppValue(CFSTR("16ch Output Device"), cfstr, kCFPreferencesCurrentApplication);
	CFRelease(cfstr);

	UInt32 val = 64 << [m2chBuffer indexOfItem:mCur2chBufferSize];
	CFNumberRef number = CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberIntType, &val);
	CFPreferencesSetAppValue(CFSTR("2ch Buffer Size"), number, kCFPreferencesCurrentApplication);
	CFRelease(number);
	
	val = 64 << [m16chBuffer indexOfItem:mCur16chBufferSize];
	number = CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberIntType, &val);
	CFPreferencesSetAppValue(CFSTR("16ch Buffer Size"), number, kCFPreferencesCurrentApplication);
	CFRelease(number);		

	CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
}

- (CFStringRef)formDevicePrefName:(BOOL)is2ch
{
	if (is2ch) {
		NSString *routingTag = @" [2ch Routing]";
		NSString *deviceName  = [mCur2chDevice title];
		return CFStringCreateWithCString(kCFAllocatorSystemDefault, [[deviceName stringByAppendingString:routingTag] cStringUsingEncoding:kCFStringEncodingUTF8], kCFStringEncodingUTF8);
	} else {
		NSString *routingTag = @" [16ch Routing]";
		NSString *deviceName  = [mCur16chDevice title];
		return CFStringCreateWithCString(kCFAllocatorSystemDefault, [[deviceName stringByAppendingString:routingTag] cStringUsingEncoding:kCFStringEncodingUTF8], kCFStringEncodingUTF8);
	}
}

- (void)readDevicePrefs:(BOOL)is2ch
{
	AudioThruEngine	*thruEng = (is2ch ? gThruEngine2 : gThruEngine16);
	int numChans = (is2ch ? 2 : 16);
	CFStringRef arrayName = [self formDevicePrefName:is2ch];
	CFArrayRef mapArray = (CFArrayRef) CFPreferencesCopyAppValue(arrayName, kCFPreferencesCurrentApplication);
	
	if (mapArray) {
		for (int i = 0; i < numChans; i++) {
			CFNumberRef num = (CFNumberRef)CFArrayGetValueAtIndex(mapArray, i);
			if (num) {
				UInt32 val;
				CFNumberGetValue(num, kCFNumberLongType, &val);	
				thruEng->SetChannelMap(i, val-1);
				//CFRelease(num);
			}
		}
		//CFRelease(mapArray);
	}
	else { // set to default
		for (int i = 0; i < numChans; i++) 
			thruEng->SetChannelMap(i, i);
	}
	
	//CFRelease(arrayName);
	
	// iSchemy's edit
	//
	// cloning is enabled only for 2ch mode
	// sorta makes sense, huh?
	if (is2ch) {
		CFBooleanRef clone = (CFBooleanRef)CFPreferencesCopyAppValue(CFSTR("Clone channels"), kCFPreferencesCurrentApplication);
		// if cloning is enabled in preferences, it will affect also the menu item's state
		NSMenuItem* item = [[m2chMenu submenu] itemWithTitle:@"Clone to all channels"];
			if (clone && item) {
				[self cloningChanged:item cloneChannels:CFBooleanGetValue(clone)];
				CFRelease(clone);
			}
			// but if it is disabled, no state changing is needed
			else {
				thruEng->SetCloneChannels(false);
			}
	}
	//
	// end
}

- (void)writeDevicePrefs:(BOOL)is2ch
{
	AudioThruEngine	*thruEng = (is2ch ? gThruEngine2 : gThruEngine16);
	int numChans = (is2ch ? 2 : 16);
	CFNumberRef map[16];
	
	CFStringRef arrayName = [self formDevicePrefName:is2ch];
	
	for (int i = 0; i < numChans; i++)
	{	
		UInt32 val = thruEng->GetChannelMap(i) + 1;
		map[i] = CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberIntType, &val);
	}

	CFArrayRef mapArray = CFArrayCreate(kCFAllocatorSystemDefault, (const void**)&map, numChans, NULL);
	CFPreferencesSetAppValue(arrayName, mapArray, kCFPreferencesCurrentApplication);
	//CFRelease(mapArray);
	
	//for (int i = 0; i < numChans; i++)
	//	CFRelease(map[i]);
	
	//CFRelease(arrayName);
	
	// iSchemy's edit
	//
	// I think that this needs no commentary
	if(is2ch){
		char cloneValue = thruEng->CloneChannels();
		CFNumberRef clone = (CFNumberRef)CFNumberCreate(kCFAllocatorSystemDefault, kCFNumberCharType, &cloneValue);
		CFPreferencesSetAppValue(CFSTR("Clone channels"),
								 clone,
								 kCFPreferencesCurrentApplication);
		CFRelease(clone);
	}
	//
	// end
	
	CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
}

-(void)doAudioSetup
{
	[[NSWorkspace sharedWorkspace] launchApplication:@"Audio MIDI Setup"];
}

-(void)doAbout
{
	// orderFrontStandardAboutPanel doesnt work for background apps
	[mAboutController doAbout];
}
- (void)doQuit
{
	[NSApp terminate:nil];
}

@end
