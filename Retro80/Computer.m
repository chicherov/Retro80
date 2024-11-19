/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Базовый класс ретрокомпьютера

 *****/

#import "Document.h"
#import "Computer.h"
#import "Sound.h"

@implementation Computer
{
	NSCondition *condition;
	NSRunLoop *runLoop;
	NSTimer *timer;
}

@synthesize quartz;

@dynamic title;
@dynamic clock;

- (NSObject<Enabled> *)inpHook
{
	return nil;
}

- (NSObject<Enabled> *)outHook
{
	return nil;
}

- (void)registerUndoWithMenuItem:(NSMenuItem *)menuItem
{
	[self.document registerUndo:menuItem.title];
}

- (void)timer:(NSTimer *)theTimer
{
	@synchronized(self)
	{
		[self execute:self.clock + self.quartz*theTimer.timeInterval];
	}
}

- (BOOL)execute:(uint64_t)clki
{
	return NO;
}

- (void)thread
{
#ifndef NDEBUG
	NSLog(@"%@ thread start", NSStringFromClass(self.class));
#endif

	[condition lock];

	runLoop = [NSRunLoop currentRunLoop];

	if (self.document.inViewingMode || ![self.sound start])
	{
		timer = [NSTimer scheduledTimerWithTimeInterval:0.02
												 target:self
											   selector:@selector(timer:)
											   userInfo:nil
												repeats:YES];
	}

	[condition signal];
	[condition unlock];

	while ([runLoop runMode:NSDefaultRunLoopMode
				 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]]);

	[condition lock];

	runLoop = nil;

	[condition signal];
	[condition unlock];

#ifndef NDEBUG
	NSLog(@"%@ thread stop", NSStringFromClass(self.class));
#endif
}

- (void)start
{
	[NSThread detachNewThreadSelector:@selector(thread)
							 toTarget:self
						   withObject:self];

	[condition lock];

	while (!runLoop)
		[condition wait];

	[condition unlock];
}

- (void)stop
{
	if (timer)
	{
		[timer invalidate];
		timer = nil;
	}
	else
	{
		[self.sound stop];
	}

	[condition lock];

	while (runLoop)
		[condition wait];

	[condition unlock];

#ifndef NDEBUG
	NSLog(@"%@ stop", NSStringFromClass(self.class));
#endif
}

- (instancetype)initWithQuartz:(unsigned)value
{
	if (self = [super init])
	{
		condition = [[NSCondition alloc] init];

		quartz = value;

		if (![self createObjects])
			return self = nil;

		if (![self mapObjects])
			return self = nil;

		self.inpHook.enabled = YES;
		self.outHook.enabled = YES;
	}

	return self;
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		condition = [[NSCondition alloc] init];

		if (![self decodeWithCoder:decoder])
			return self = nil;

		if (![self mapObjects])
			return self = nil;

		self.inpHook.enabled = [decoder decodeBoolForKey:@"inpHook"];
		self.outHook.enabled = [decoder decodeBoolForKey:@"outHook"];
	}

	return self;
}

- (BOOL)decodeWithCoder:(NSCoder *)coder
{
	if ((quartz = [coder decodeInt32ForKey:@"quartz"]) == 0)
		return NO;
	else
		return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt32:quartz forKey:@"quartz"];

	[coder encodeBool:self.inpHook.enabled forKey:@"inpHook"];
	[coder encodeBool:self.outHook.enabled forKey:@"outHook"];
}

- (BOOL)createObjects
{
	return NO;
}

- (BOOL)mapObjects
{
	return NO;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(outHook:))
	{
		if (!self.sound.isOutput)
		{
			menuItem.state = self.outHook.enabled;
			return self.outHook != nil;
		}
	}
	else if (menuItem.action == @selector(inpHook:))
	{
		if (!self.sound.isInput)
		{
			menuItem.state = self.inpHook.enabled;
			return self.inpHook != nil;
		}
	}

	menuItem.alternate = NO;
	menuItem.state = NO;
	return NO;
}

- (IBAction)inpHook:(NSMenuItem *)menuItem
{
	self.inpHook.enabled = !self.inpHook.enabled;
}

- (IBAction)outHook:(NSMenuItem *)menuItem
{
	self.outHook.enabled = !self.outHook.enabled;
}

#ifndef NDEBUG
- (void)dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
