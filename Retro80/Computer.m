#import "Retro80.h"

@implementation Computer

+ (NSString *) title
{
	return nil;
}

- (void) start
{
	[self.snd start];
}

- (void) stop
{
	[self.snd stop];
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(reset:))
	{
		return [self respondsToSelector:@selector(reset)];
	}

	if (menuItem.action == @selector(kbdHook:))
	{
		menuItem.state = self.kbdHook.enabled;
		return self.kbdHook != nil;
	}

	if (menuItem.action == @selector(outHook:))
	{
		menuItem.state = self.outHook.enabled;
		return self.outHook != nil;
	}

	if (menuItem.action == @selector(inpHook:))
	{
		menuItem.state = self.inpHook.enabled;
		return self.inpHook != nil;
	}

	if (menuItem.action == @selector(paste:))
	{
		return self.kbd && [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString] != nil;
	}

	menuItem.state = FALSE;
	return NO;
}

// -----------------------------------------------------------------------------

- (IBAction) colorModule:(id)sender
{
}

- (IBAction) extraMemory:(id)sender
{
}

- (IBAction) ROMDisk:(id)sender
{
}

- (IBAction) floppy:(id)sender
{
}

// -----------------------------------------------------------------------------
// reset
// -----------------------------------------------------------------------------

- (IBAction) reset:(id)sender
{
	[self.document registerUndo:NSLocalizedString(@"Reset", undo)];
	[self performSelector:@selector(reset)];
}

// -----------------------------------------------------------------------------
// хуки
// -----------------------------------------------------------------------------

- (IBAction) kbdHook:(id)sender
{
	[self.document registerUndoMenuItem:sender];
	self.kbdHook.enabled = !self.kbdHook.enabled;
}

- (IBAction) inpHook:(id)sender
{
	[self.document registerUndoMenuItem:sender];
	self.inpHook.enabled = !self.inpHook.enabled;
}

- (IBAction) outHook:(id)sender
{
	[self.document registerUndoMenuItem:sender];
	self.outHook.enabled = !self.outHook.enabled;
}

// -----------------------------------------------------------------------------
// События клавиатуры
// -----------------------------------------------------------------------------

- (void) flagsChanged:(NSEvent*)theEvent
{
	[self.kbd flagsChanged:theEvent];
}

- (void) keyDown:(NSEvent*)theEvent
{
	if ((theEvent.modifierFlags & NSCommandKeyMask) == 0)
	{
		unichar ch = [theEvent.characters characterAtIndex:0];

		if (ch == 0x09 || (ch >= 0x20 && ch < 0x7F) || (ch >= 0x410 && ch <= 0x44F))
			[self.document registerUndo:@"Typing"];
		else if (ch == 0x7F)
			[self.document registerUndo:@"Backspace"];
		else if (ch == 0x0D)
			[self.document registerUndo:@"Enter"];
		else
			[self.document registerUndo:@"Keys"];
	}

	[self.kbd keyDown:theEvent];
//	isSelected = FALSE;
}

- (void) keyUp:(NSEvent*)theEvent
{
	[self.kbd keyUp:theEvent];
}

- (IBAction) paste:(id)sender
{
	[self.document registerUndo:@"Paste"];
	[self.kbd paste:[[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString]];
}

// -----------------------------------------------------------------------------
// DEBUG: dealloc
// -----------------------------------------------------------------------------

#ifdef DEBUG
- (void) dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
