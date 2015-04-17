#import "Retro80.h"

@implementation Computer

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	return self = nil;
}

- (id) initWithType:(NSInteger)type
{
	return [self init];
}

+ (NSString *) title
{
	return nil;
}

+ (NSArray *) extensions
{
	return nil;
}

- (void) start
{
	[self.snd.sound start];
}

- (void) stop
{
	[self.snd.sound stop];
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(reset:))
	{
		return YES;
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
		if (self.snd.sound.isInput)
		{
			menuItem.state = FALSE;
			return NO;
		}

		menuItem.state = self.inpHook.enabled;
		return self.inpHook != nil;
	}

	if (menuItem.action == @selector(qwerty:))
	{
		menuItem.state = self.kbd.qwerty;
		return self.kbd != nil;
	}

	if (menuItem.action == @selector(floppy:) && menuItem.tag)
		menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"][0]) stringByAppendingString:@":"];

	if (menuItem.action == @selector(ROMDisk:))
		menuItem.title = [menuItem.title componentsSeparatedByString:@":"][0];


	menuItem.state = FALSE;
	menuItem.submenu = nil;
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
// qwerty
// -----------------------------------------------------------------------------

- (IBAction)qwerty:(id)sender
{
	self.kbd.qwerty = !self.kbd.qwerty;
}

// -----------------------------------------------------------------------------
// reset
// -----------------------------------------------------------------------------

- (IBAction) reset:(NSMenuItem *)menuItem
{
	[self.document registerUndoWithMenuItem:menuItem];

	@synchronized(self.snd.sound)
	{
		if (!self.snd.sound.isInput)
		{
			self.cpu.RESET = TRUE;
			return;
		}
	}

	[self stop];
	[self.snd.sound close];
	self.cpu.RESET = TRUE;
	[self start];
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
// DEBUG: dealloc
// -----------------------------------------------------------------------------

#ifdef DEBUG
- (void) dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
