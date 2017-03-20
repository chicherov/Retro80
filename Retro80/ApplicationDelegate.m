/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 *****/

#import "ApplicationDelegate.h"

@implementation ApplicationDelegate

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(inpHook:) || menuItem.action == @selector(outHook:) || menuItem.action == @selector(qwerty:))
	{
		menuItem.hidden = menuItem.tag != 0;
	}
	else
	{
		menuItem.hidden = TRUE;
	}

	menuItem.alternate = FALSE;
	menuItem.state = FALSE;
	return NO;
}

- (IBAction)inpHook:(id)sender {}
- (IBAction)outHook:(id)sender {}
- (IBAction)qwerty:(id)sender {}
- (IBAction)ramfos:(id)sender {}

- (IBAction)extraMemory:(id)sender {}
- (IBAction)ROMDisk:(id)sender {}
- (IBAction)floppy:(id)sender {}

- (IBAction)colorModule:(id)sender {}
- (IBAction)UT88:(id)sender {}
- (IBAction)VI53:(id)sender {}

@end
