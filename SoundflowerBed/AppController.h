/* AppController */

#import <Cocoa/Cocoa.h>
#import "HelpWindowController.h"
#include "AudioDeviceList.h"


@interface AppController : NSObject<NSApplicationDelegate>
{
	NSStatusItem	*mSbItem;
	NSMenu			*mMenu;
    /* The "2ch menu" */
	NSMenuItem		*m2chMenu;
    /* The menu that gives 2ch buffer choices */
    NSMenu          *m2chBuffer;
    /* The "16ch menu" */
	NSMenuItem		*m16chMenu;
    /* The menu that gives 2ch buffer choices */
    NSMenu          *m16chBuffer;
    
	BOOL			menuItemVisible;
	int				m16StartIndex;
	
	NSMenuItem		*mCur2chDevice;
	NSMenuItem		*mCur2chBuffer;
	NSMenuItem		*mCur16chDevice;
	NSMenuItem		*mCur16chBuffer;
	
	NSMenuItem		*mSuspended2chDevice;
	NSMenuItem		*mSuspended16chDevice;
	
	AudioDeviceID				mSoundflower2Device;
	AudioDeviceID				mSoundflower16Device;
	
	AudioDeviceList *			mOutputDeviceList;	
	
	UInt32 mNchnls2;
	UInt32 mNchnls16;
	
	UInt32 mMenuID2[64];
	UInt32 mMenuID16[64];
	
	IBOutlet HelpWindowController *mAboutController;
}

- (IBAction)suspend;
- (IBAction)resume;

- (IBAction)srChanged2ch;
- (IBAction)srChanged16ch;
- (IBAction)srChanged2chOutput;
- (IBAction)srChanged16chOutput;
- (IBAction)checkNchnls;

- (IBAction)refreshDevices;

- (IBAction)outputDeviceSelected:(id)sender;
- (IBAction)bufferSizeChanged2ch:(id)sender;
- (IBAction)bufferSizeChanged16ch:(id)sender;
- (IBAction)routingChanged2ch:(id)sender;
- (IBAction)routingChanged16ch:(id)sender;

- (void)buildRoutingMenu:(BOOL)is2ch;
- (void)buildDeviceList;
- (void)buildMenu;

- (void)InstallListeners;
- (void)RemoveListeners;

- (void)readGlobalPrefs;
- (void)writeGlobalPrefs;

- (void)readDevicePrefs:(BOOL)is2ch;
- (void)writeDevicePrefs:(BOOL)is2ch;

@end
