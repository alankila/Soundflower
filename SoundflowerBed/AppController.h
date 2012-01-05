/* AppController */

#import <Cocoa/Cocoa.h>
#import "HelpWindowController.h"
#include "AudioDeviceList.h"


@interface AppController : NSObject<NSApplicationDelegate>
{
	NSStatusItem	*mSbItem;
    /* Top-level menu */
	NSMenu			*mMenu;
    /* Output device menu */
    NSMenu          *m2chOutputDevice;
    /* Buffer size menu */
    NSMenu          *m2chBuffer;
    /* Equalizer preset menu */
    NSMenu          *m2chPreset;
    /* Loudness compensation menu */
    NSMenu          *m2chLoudness;
    
    /* Output device submenu selection */
    NSMenuItem		*mCur2chDevice;
    /* Buffer size submenu selection */
	NSMenuItem		*mCur2chBuffer;
    /* Preset compensation selection */
    NSMenuItem      *mCur2chPreset;
    /* Loudness compensation selection */
    NSMenuItem      *mCur2chLoudness;
    /* Virtualizer tick mark item */
    NSMenuItem      *mCur2chVirtualizer;
	/* Temporary stash for the value of the current 2ch output device while system is suspended. */
	NSMenuItem		*mSuspended2chDevice;
	
	AudioDeviceID	mSoundflower2Device;
	
	AudioDeviceList *mOutputDeviceList;	
	
	IBOutlet HelpWindowController *mAboutController;
}

- (IBAction)suspend;
- (IBAction)resume;

- (IBAction)srChanged2ch;
- (IBAction)srChanged2chOutput;

- (IBAction)refreshDevices;

- (IBAction)outputDeviceSelected:(id)sender;
- (IBAction)bufferSizeChanged2ch:(id)sender;
- (IBAction)presetChanged:(id)sender;
- (IBAction)loudnessChanged:(id)sender;

- (void)buildDeviceList;
- (void)buildMenu;

- (void)InstallListeners;
- (void)RemoveListeners;

- (void)readGlobalPrefs;
- (void)writeGlobalPrefs;

@end
