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
		return YES;

	if (menuItem.action == @selector(debug:))
		return [self.cpu conformsToProtocol:@protocol(Debug)];

	if (menuItem.action == @selector(outHook:))
	{
		if (self.snd.sound.isOutput)
		{
			menuItem.state = FALSE;
			return NO;
		}

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

	if (menuItem.action == @selector(monitorROM:))
		menuItem.hidden = TRUE;

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

- (IBAction) monitorROM:(id)sender
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
	@synchronized(self.snd.sound)
	{
		[self.document registerUndoWithMenuItem:menuItem];
		[self.cpu reset];
	}
}

// -----------------------------------------------------------------------------
// Вызов отладчика
// -----------------------------------------------------------------------------

- (IBAction) debug:(id)sender
{
	@synchronized(self.snd.sound)
	{
		if ([sender isKindOfClass:[NSMenuItem class]])
			[self.document registerUndoWithMenuItem:sender];

		self.snd.sound.debug = TRUE;
	}

	[self.document.debug run:self.cpu];
	self.snd.sound.debug = FALSE;
}

// -----------------------------------------------------------------------------
// хуки
// -----------------------------------------------------------------------------

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
