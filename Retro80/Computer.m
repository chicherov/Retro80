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
		if (self.snd.isInput)
		{
			menuItem.state = FALSE;
			return NO;
		}

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

- (IBAction) reset:(NSMenuItem *)menuItem
{
	[self.document registerUndoWithMenuItem:menuItem];
	[self performSelector:@selector(reset)];
}

// -----------------------------------------------------------------------------
// хуки
// -----------------------------------------------------------------------------

- (IBAction) kbdHook:(NSMenuItem *)menuItem
{
	self.kbdHook.enabled = !self.kbdHook.enabled;
}

- (IBAction) inpHook:(NSMenuItem *)menuItem
{
	self.inpHook.enabled = !self.inpHook.enabled;
}

- (IBAction) outHook:(NSMenuItem *)menuItem
{
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
	if ((theEvent.modifierFlags & NSCommandKeyMask) == 0 && theEvent.characters.length != 0)
	{
		NSString *typing = NSLocalizedString(@"Набор на клавиатуре", "Typing");
		unichar ch = [theEvent.characters characterAtIndex:0];

		if (ch == 0x09 || (ch >= 0x20 && ch < 0x7F) || (ch >= 0x410 && ch <= 0x44F))
			[self.document registerUndoWitString:typing type:1];
		else if (ch == 0xF700 || ch == 0xF701 || ch == 0xF702 || ch == 0xF703)
			[self.document registerUndoWitString:typing type:2];
		else if (ch == 0x7F)
			[self.document registerUndoWitString:typing type:3];
		else if (ch == 0x0D)
			[self.document registerUndoWitString:typing type:4];
		else
			[self.document registerUndoWitString:typing type:5];
	}

	[self.kbd keyDown:theEvent];
//	isSelected = FALSE;
}

- (void) keyUp:(NSEvent*)theEvent
{
	[self.kbd keyUp:theEvent];
}

- (IBAction) paste:(NSMenuItem *)menuItem
{
	[self.document registerUndoWithMenuItem:menuItem];
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
