#import "Retro80.h"

@implementation Computer

- (id) init:(NSInteger)variant
{
	if (variant == 0)
		return [self init];
	else
		return self = nil;
}

+ (NSString *) title
{
	return nil;
}

+ (NSString *) ext
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
		if (self.snd.sound.isInput)
		{
			menuItem.state = FALSE;
			return NO;
		}

		menuItem.state = self.inpHook.enabled;
		return self.inpHook != nil;
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

	@synchronized(self.snd.sound)
	{
		if (!self.snd.sound.isInput)
		{
			[self performSelector:@selector(reset)];
			return;
		}
	}

	[self stop];
	[self.snd.sound close];

	[self performSelector:@selector(reset)];

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
