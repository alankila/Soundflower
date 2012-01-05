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
    /* Loudness compensation menu */
    NSMenu          *m2chLoudness;
    
	BOOL			menuItemVisible;
	
    /* Output device submenu selection */
    NSMenuItem		*mCur2chDevice;
    /* Buffer size submenu selection */
	NSMenuItem		*mCur2chBuffer;
    /* Virtualizer tick mark item */
    NSMenuItem      *mCur2chVirtualizer;
    /* Loudness compensation selection */
    NSMenuItem      *mCur2chLoudness;
	
	NSMenuItem		*mSuspended2chDevice;
	
	AudioDeviceID	mSoundflower2Device;
	
	AudioDeviceList *mOutputDeviceList;	
	
	UInt32 mNchnls2;
	
	IBOutlet HelpWindowController *mAboutController;
}

- (IBAction)suspend;
- (IBAction)resume;

- (IBAction)srChanged2ch;
- (IBAction)srChanged2chOutput;
- (IBAction)checkNchnls;

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
