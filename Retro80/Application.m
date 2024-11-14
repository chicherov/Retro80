/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 *****/

#import "Application.h"
#import "WindowController.h"

@implementation Application

- (void)sendEvent:(NSEvent *)theEvent
{
    if(theEvent.type == NSEventTypeKeyDown && (theEvent.modifierFlags & NSEventModifierFlagCommand) == 0 && [@"\r\t\x1B" rangeOfString:theEvent.characters].location != NSNotFound)
    {
        if([theEvent.window.windowController isKindOfClass:WindowController.class])
            [theEvent.window.windowController keyDown:theEvent];
        else
            [theEvent.window sendEvent:theEvent];
    }
    else
    {
        [super sendEvent:theEvent];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(inpHook:) || menuItem.action == @selector(outHook:) || menuItem.action == @selector(qwerty:))
		menuItem.hidden = menuItem.tag != 0;
	else if (menuItem.action == @selector(ramfos:))
		menuItem.hidden = YES;
	else if (menuItem.action == @selector(extraMemory:))
		menuItem.hidden = YES;
	else if (menuItem.action == @selector(ROMDisk:))
		menuItem.hidden = YES;
	else if (menuItem.action == @selector(floppy:))
		menuItem.hidden = YES;
	else if (menuItem.action == @selector(colorModule:))
		menuItem.hidden = YES;
	else if (menuItem.action == @selector(UT88:))
		menuItem.hidden = YES;
	else if (menuItem.action == @selector(VI53:))
		menuItem.hidden = YES;
	else
		return YES;

	menuItem.alternate = NO;
	menuItem.state = NO;
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
