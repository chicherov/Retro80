/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 *****/

#import "Retro80.h"

@implementation Computer

+ (NSArray<NSString*> *) extensions
{
	return nil;
}

+ (NSString *) title
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
		return [self.cpu respondsToSelector:@selector(reset)];

	else if (menuItem.action == @selector(outHook:))
	{
		if (!self.snd.sound.isOutput)
		{
            menuItem.state = self.outHook.enabled;
            return self.outHook != nil;
		}
	}

	else if (menuItem.action == @selector(inpHook:))
	{
		if (!self.snd.sound.isInput)
		{
            menuItem.state = self.inpHook.enabled;
            return self.inpHook != nil;
		}
	}

	else if (menuItem.action == @selector(qwerty:))
	{
		menuItem.state = self.kbd.qwerty;
		return self.kbd != nil;
	}
    
    else if (menuItem.action == @selector(extraMemory:))
    {
        menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;

        menuItem.hidden = menuItem.tag != 0;
    }

	else if (menuItem.action == @selector(floppy:))
    {
        if (menuItem.tag)
            menuItem.title = [[menuItem.title componentsSeparatedByString:@":"].firstObject stringByAppendingString:@":"];
        else
            menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;
    }

	else if (menuItem.action == @selector(ROMDisk:))
	{
        menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;

        menuItem.hidden = menuItem.tag != 0;
	}

	else if (menuItem.action == @selector(UT88:))
		menuItem.hidden = TRUE;
    
    menuItem.alternate = FALSE;
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

- (IBAction) UT88:(id)sender
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
	@synchronized(self.cpu)
	{
		[self.document registerUndoWithMenuItem:menuItem];
		[self.cpu reset];
	}
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
