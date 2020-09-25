/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Базовый класс ретрокомпьютера с процессором КР580ВМ80А/Z80

 *****/

#import "Retro80.h"
#import "Sound.h"
#import "Dbg80.h"
#import "mem.h"

@implementation Retro80
{
	BOOL inDebugMode;
}

@synthesize cpu;
@synthesize rom;
@synthesize ram;

@dynamic crt;
@dynamic snd;

- (void)start
{
	self.crt.display = self.display;
	self.snd.sound = self.sound;

	[super start];
}

- (uint64_t)clock
{
	return self.cpu.CLK;
}

- (BOOL)execute:(uint64_t)clki
{
	if ([self.crt respondsToSelector:@selector(draw)])
		[self.crt draw];

	if (!inDebugMode && ![self.cpu execute:clki])
	{
		[self performSelectorOnMainThread:@selector(debug:)
							   withObject:nil
							waitUntilDone:NO];

		inDebugMode = YES;
	}

	if (self.clock >= clki)
	{
		if ([self.snd respondsToSelector:@selector(flush:)])
			[self.snd flush:clki];

		return YES;
	}
	else
	{
		return NO;
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(debug:))
		return inDebugMode == NO;

	if (sel_isEqual(menuItem.action, @selector(reset:)))
		return YES;

	return [super validateMenuItem:menuItem];
}

- (IBAction)debug:(NSMenuItem *)menuItem;
{
	@synchronized(self)
	{
		inDebugMode = YES;
	}

	if (![self.debug.delegate isKindOfClass:Dbg80.class])
		self.debug.delegate = [Dbg80 dbg80WithDebug:self.debug];

	[(Dbg80 *) self.debug.delegate setCpu:self.cpu];
	[(Dbg80 *) self.debug.delegate run];

	inDebugMode = NO;
}

- (IBAction)reset:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		[self registerUndoWithMenuItem:menuItem];
		[self.cpu reset];
	}
}

@end
