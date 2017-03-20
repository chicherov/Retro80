/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Микро-80»

 *****/

#import "Micro80.h"

@implementation Micro80

@synthesize crt;
@synthesize snd;

@synthesize inpHook;
@synthesize outHook;

+ (NSString *)title
{
	return @"Микро-80";
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(extraMemory:))
	{
		switch (menuItem.tag)
		{
			case 1:

				if (self.ram.length != 2048)
					menuItem.title = [[menuItem.title componentsSeparatedByString:@":"].firstObject
						stringByAppendingFormat:@": %luK", (self.ram.length >> 10) - 2];
				else
					menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;

				menuItem.state = FALSE;
				break;

			case 2:
			case 18:
			case 34:
			case 50:
			case 62:

				menuItem.state = self.ram.length == menuItem.tag*1024;
				break;

			default:

				menuItem.state = FALSE;
				menuItem.hidden = TRUE;
				return NO;
		}

		menuItem.hidden = FALSE;
		return YES;
	}

	return [super validateMenuItem:menuItem];
}

- (IBAction)extraMemory:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		NSUInteger newLength = self.ram.length;

		switch (menuItem.tag)
		{
			case 1:

				newLength = newLength == 2048 ? 62*1024 : 2048;
				break;

			case 2:
			case 18:
			case 34:
			case 50:
			case 62:

				newLength = menuItem.tag*1024;
				break;
		}

		if (self.ram.length != newLength)
		{
			[self registerUndoWithMenuItem:menuItem];
			self.ram.length = newLength;
		}
	}
}

- (BOOL)createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] init8080:0x0F800]) == nil)
		return FALSE;

	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Micro80" mask:0x07FF]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0xF800 mask:0x07FF]) == nil)
		return FALSE;

	if (self.crt == nil && (self.crt = [[Micro80Screen alloc] init]) == nil)
		return FALSE;

	if (self.kbd == nil && (self.kbd = [[Micro80Keyboard alloc] init]) == nil)
		return FALSE;

	return TRUE;
}

- (BOOL)mapObjects
{
	self.nextResponder = self.kbd;
	self.kbd.computer = self;

	if (self.snd == nil && (self.snd = [[Micro80Recorder alloc] init]) == nil)
		return FALSE;

	MEM *mem;

	if ((mem = [self.ram memoryAtOffest:2048]) == nil)
		return FALSE;

	self.crt.mem = mem;

	[self.cpu mapObject:mem from:0x0000 to:0xDFFF];
	[self.cpu mapObject:self.crt from:0xE000 to:0xEFFF RD:mem];
	[self.cpu mapObject:self.ram from:0xF000 to:0xF7FF];
	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF WR:nil];

	if (self.inpHook == nil)
	{
		self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
		self.inpHook.mem = self.rom;
		self.inpHook.snd = self.snd;

		self.inpHook.extension = @"rk8";
	}

	if (self.outHook == nil)
	{
		self.outHook = [[F80C alloc] initWithX8080:self.cpu];
		self.outHook.mem = self.rom;
		self.outHook.snd = self.snd;

		self.outHook.extension = @"rk8";
	}

	uint16_t F806 = (self.rom.mutableBytes[0x08] << 8) | self.rom.mutableBytes[0x07];
	[self.cpu mapObject:self.inpHook from:F806 to:F806 WR:nil];

	uint16_t F80C = (self.rom.mutableBytes[0x0E] << 8) | self.rom.mutableBytes[0x0D];
	[self.cpu mapObject:self.outHook from:F80C to:F80C WR:nil];

	[self.cpu mapObject:self.snd atPort:0x00 count:0x04];
	[self.cpu mapObject:self.kbd atPort:0x04 count:0x04];

	self.cpu.FF = TRUE;
	return TRUE;
}

- (instancetype)init
{
	return self = [super initWithQuartz:18000000];
}

- (instancetype)initWithData:(NSData *)data
{
	if (self = [self init])
	{
		[self.kbd pasteString:@"I\n"];
		self.inpHook.buffer = data;
	}

	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:self.cpu forKey:@"cpu"];
	[coder encodeObject:self.rom forKey:@"rom"];
	[coder encodeObject:self.ram forKey:@"ram"];
	[coder encodeObject:self.crt forKey:@"crt"];
	[coder encodeObject:self.kbd forKey:@"kbd"];
}

- (BOOL)decodeWithCoder:(NSCoder *)coder
{
	if (![super decodeWithCoder:coder])
		return FALSE;

	if ((self.cpu = [coder decodeObjectForKey:@"cpu"]) == nil)
		return FALSE;

	if ((self.rom = [coder decodeObjectForKey:@"rom"]) == nil)
		return FALSE;

	if ((self.ram = [coder decodeObjectForKey:@"ram"]) == nil)
		return FALSE;

	if ((self.crt = [coder decodeObjectForKey:@"crt"]) == nil)
		return FALSE;

	if ((self.kbd = [coder decodeObjectForKey:@"kbd"]) == nil)
		return FALSE;

	return TRUE;
}

@end

// Микро-80 с доработками

@implementation Micro80II

- (BOOL)createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"M80RK86" mask:0x07FF]) == nil)
		return FALSE;

	if (self.ext == nil && (self.ext = [[RKSDCard alloc] init]) == nil)
		return FALSE;

	return [super createObjects];
}

- (BOOL)mapObjects
{
	if ([super mapObjects] == FALSE)
		return FALSE;

	self.kbd.nextResponder = self.ext;
	self.ext.computer = self;

	[self.cpu mapObject:self.ext atPort:0xA0 count:0x04];

	[self.cpu mapObject:self.crt from:0xE000 to:0xEFFF];

	self.inpHook.type = 1;
	self.outHook.type = 1;
	return TRUE;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
	[coder encodeObject:self.ext forKey:@"ext"];
}

- (BOOL)decodeWithCoder:(NSCoder *)coder
{
	if (![super decodeWithCoder:coder])
		return FALSE;

	if ((self.ext = [coder decodeObjectForKey:@"ext"]) == nil)
		return FALSE;

	return TRUE;
}

@end
