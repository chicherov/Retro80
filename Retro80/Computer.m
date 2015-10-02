#import "Retro80.h"

@implementation Computer

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

	if (menuItem.action == @selector(UT88:))
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

- (IBAction) UT88:(id)sender
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
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	return FALSE;
}

- (BOOL) mapObjects
{
	return FALSE;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeBool:self.inpHook.enabled forKey:@"inpHook"];
	[encoder encodeBool:self.outHook.enabled forKey:@"outHook"];
}

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
	return TRUE;
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		if (![self decodeWithCoder:decoder])
			return self = nil;

		if (![self mapObjects])
			return self = nil;

		self.inpHook.enabled = [decoder decodeBoolForKey:@"inpHook"];
		self.outHook.enabled = [decoder decodeBoolForKey:@"outHook"];
	}

	return self;
}

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	return self = nil;
}

- (id) initWithType:(NSInteger)type
{
	if (self = [super init])
	{
		if (![self createObjects])
			return self = nil;

		if (![self mapObjects])
			return self = nil;

		self.inpHook.enabled = TRUE;
		self.outHook.enabled = TRUE;
	}

	return self;
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
