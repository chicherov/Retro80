/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Орион 128»

 *****/

#import "Orion128.h"

@implementation Orion128

@synthesize snd;
@synthesize crt;

@synthesize inpHook;
@synthesize outHook;

+ (NSString *)title
{
	return @"Орион 128";
}

- (instancetype)init
{
	return self = [super initWithQuartz:22500000];
}

- (instancetype)initWithData:(NSData *)data
{
	if (self = [self init])
		self.inpHook.buffer = data;

	return self;
}

- (BOOL)createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] init8080:0xF800]) == nil)
		return NO;

	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-2" mask:0x07FF]) == nil)
		return NO;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x40000 mask:0xFFFF]) == nil)
		return NO;

	if (self.crt == nil && (self.crt = [[Orion128Screen alloc] init]) == nil)
		return NO;

	if (self.snd == nil && (self.snd = [[X8253 alloc] init]) == nil)
		return NO;

	if (self.kbd == nil && (self.kbd = [[RKKeyboard alloc] init]) == nil)
		return NO;

	if (self.ext == nil && (self.ext = [[ROMDisk alloc] initWithContentsOfResource:@"ORDOS-4.03"]) == nil)
		return NO;

	if (self.prn == nil && (self.prn = [[X8255 alloc] init]) == nil)
		return NO;

	if (self.fdd == nil && (self.fdd = [[Orion128Floppy alloc] initWithQuartz:self.quartz]) == nil)
		return NO;

	if (self.mem == nil && (self.mem = [self.ram memoryAtOffest:0]) == nil)
		return NO;

	self.snd.channel0 = YES;
	self.snd.rkmode = YES;
	return YES;
}

- (BOOL)mapObjects
{
	self.nextResponder = self.kbd;
	self.kbd.computer = self;

	self.kbd.nextResponder = self.ext;
	self.ext.computer = self;

	self.ext.nextResponder = self.fdd;
	self.fdd.computer = self;

	self.fdd.nextResponder = self.snd;

	if (self.sys == nil && (self.sys = [[Orion128System alloc] init]) == nil)
		return NO;

	self.sys.orion = self;

	self.cpu.INTE = self.snd;

	self.cpu.FF = YES;

	self.crt.pMemory = self.ram.pMutableBytes;

	if (self.inpHook == nil)
	{
		self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
		self.inpHook.mem = self.rom;
		self.inpHook.snd = self.snd;

		self.inpHook.extension = @"rko";
		self.inpHook.type = 1;
	}

	if (self.outHook == nil)
	{
		self.outHook = [[F80C alloc] initWithX8080:self.cpu];
		self.outHook.mem = self.rom;
		self.outHook.snd = self.snd;

		self.outHook.extension = @"rko";
		self.outHook.type = 1;
	}

	uint16_t F806 = (self.rom.mutableBytes[0x08] << 8) | self.rom.mutableBytes[0x07];
	uint16_t F80C = (self.rom.mutableBytes[0x0E] << 8) | self.rom.mutableBytes[0x0D];

	for (uint8_t page = 0; page < 4; page++)
	{
		if ((page & 2) == 0)
		{
			[self.cpu mapObject:self.ram atPage:page from:0x0000 to:0xEFFF];
		}
		else
		{
			[self.cpu mapObject:self.mem atPage:page from:0x0000 to:0x3FFF];
			[self.cpu mapObject:self.ram atPage:page from:0x4000 to:0xEFFF];
		}

		if ((page & 1) == 0)
		{
			[self.cpu mapObject:[self.ram memoryAtOffest:0]
						 atPage:page from:0xF000 to:0xF3FF];

			[self.cpu mapObject:self.kbd atPage:page from:0xF400 to:0xF4FF];
			[self.cpu mapObject:self.ext atPage:page from:0xF500 to:0xF5FF];
			[self.cpu mapObject:self.prn atPage:page from:0xF600 to:0xF6FF];

			[self.cpu mapObject:self.fdd atPage:page from:0xF700 to:0xF72F];

			[self.cpu mapObject:self.snd atPage:page from:0xF740 to:0xF75F];

			[self.cpu mapObject:self.rom atPage:page from:0xF800 to:0xFFFF WR:self.sys];
			[self.cpu mapObject:self.inpHook atPage:page from:F806 to:F806 WR:self.sys];
			[self.cpu mapObject:self.outHook atPage:page from:F80C to:F80C WR:self.sys];
		}
		else
		{
			[self.cpu mapObject:self.ram atPage:page from:0xF000 to:0xFFFF];
		}
	}

	return YES;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(extraMemory:))
	{
		switch (menuItem.tag)
		{
			case 1:
			{
				menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;
				menuItem.title = [menuItem.title stringByAppendingFormat:@": %luK", self.ram.length >> 10];

				menuItem.state = NO;
				break;
			}

			case 128: case 192: case 256: case 512: case 1024:

				menuItem.state = menuItem.tag == self.ram.length >> 10;
				break;

			default:

				menuItem.state = NO;
				menuItem.hidden = YES;
				return NO;
		}

		menuItem.hidden = NO;
		return YES;
	}

/*
	if (menuItem.action == @selector(ROMDisk:) && (menuItem.tag == 0 || menuItem.tag == 1))
	{
		if (menuItem.tag == 0)
		{
			if ((menuItem.state = self.ext.URL != nil) && ![self.ext.URL.URLByDeletingLastPathComponent.path isEqualToString:NSBundle.mainBundle.resourcePath])
			{
				menuItem.title = [([menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingFormat:@": %@", self.ext.URL.lastPathComponent];
			}
			else
			{
				menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;
			}
		}
		else
		{
			menuItem.state = [self.ext.URL.URLByDeletingLastPathComponent.path isEqualToString:[NSBundle mainBundle].resourcePath];
			menuItem.hidden = NO;
		}

		return YES;
	}
*/

	return [super validateMenuItem:menuItem];
}

- (IBAction)extraMemory:(NSMenuItem *)menuItem
{
	NSUInteger length = self.ram.length;

	switch (menuItem.tag)
	{
		case 1:

			if (length == 128 * 1024)
				length = 256 * 1024;
			else
				length = 128 * 1024;

			break;

		case 128:
		case 192:
		case 256:
		case 512:
		case 1024:

			length = menuItem.tag << 10;
			break;

		default:

			return;
	}

	if (self.ram.length != length)
	{
		@synchronized(self)
		{
			[self registerUndoWithMenuItem:menuItem];

			self.ram.length = length;
//			self.crt.memory = *self.ram.pMutableBytes;
			[self.cpu reset];
		}
	}
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:self.cpu forKey:@"cpu"];
	[coder encodeObject:self.rom forKey:@"rom"];
	[coder encodeObject:self.ram forKey:@"ram"];
	[coder encodeObject:self.crt forKey:@"crt"];
	[coder encodeObject:self.snd forKey:@"snd"];
	[coder encodeObject:self.kbd forKey:@"kbd"];
	[coder encodeObject:self.ext forKey:@"ext"];
	[coder encodeObject:self.prn forKey:@"prn"];
	[coder encodeObject:self.fdd forKey:@"fdd"];

	[coder encodeInteger:self.mem.offset forKey:@"mem"];
}

- (BOOL)decodeWithCoder:(NSCoder *)coder
{
	if (![super decodeWithCoder:coder])
		return NO;

	if ((self.cpu = [coder decodeObjectForKey:@"cpu"]) == nil)
		return NO;

	if ((self.rom = [coder decodeObjectForKey:@"rom"]) == nil)
		return NO;

	if ((self.ram = [coder decodeObjectForKey:@"ram"]) == nil)
		return NO;

	if ((self.crt = [coder decodeObjectForKey:@"crt"]) == nil)
		return NO;

	if ((self.snd = [coder decodeObjectForKey:@"snd"]) == nil)
		return NO;

	if ((self.kbd = [coder decodeObjectForKey:@"kbd"]) == nil)
		return NO;

	if ((self.ext = [coder decodeObjectForKey:@"ext"]) == nil)
		return NO;

	if ((self.prn = [coder decodeObjectForKey:@"prn"]) == nil)
		return NO;

	if ((self.fdd = [coder decodeObjectForKey:@"fdd"]) == nil)
		return NO;

	if ((self.mem = [self.ram memoryAtOffest:0]) == nil)
		return NO;

	self.mem.offset = [coder decodeIntegerForKey:@"mem"];

	return YES;
}

@end

// ПЭВМ «Орион-128» с Монитором 1

@implementation Orion128M1

- (BOOL)createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-1" mask:0x07FF]) == nil)
		return NO;

	if (self.ram == nil)
	{
		if ((self.ram = [[RAM alloc] initWithLength:0x20000 mask:0xFFFF]) == nil)
			return NO;

		self.ram.mutableBytes [0x10000] = 0xFF;
	}

	if (self.ext == nil && (self.ext = [[ROMDisk alloc] initWithContentsOfResource:@"ORDOS-2.40"]) == nil)
		return NO;

	if (![super createObjects])
		return NO;

	self.fdd.enabled = NO;
	self.snd.enabled = NO;
	return YES;
}

@end

// ПЭВМ «Орион-128» с Монитором 3

@implementation Orion128M3

- (BOOL)createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-3.1" mask:0x07FF]) == nil)
		return NO;

	if (self.ext == nil && (self.ext = [[ROMDisk alloc] initWithContentsOfResource:@"M3-EXT-1.3"]) == nil)
		return NO;

	return [super createObjects];
}

@end

// ПЭВМ «Орион-128» с Z80 Card V3.1

@implementation Orion128Z80V31

- (BOOL)createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initZ80:0xF800]) == nil)
		return NO;

	return [super createObjects];
}

@end

// ПЭВМ «Орион-128» с Z80 Card V3.2

@implementation Orion128Z80V32

- (instancetype)init
{
	return self = [super initWithQuartz:31500000];
}

@end

// ПЭВМ «Орион-128» с Z80 Card II

@implementation Orion128Z80II

- (instancetype)init
{
	return self = [super initWithQuartz:45000000];
}

- (BOOL)createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initZ80:0xF800]) == nil)
		return NO;

	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-3.2" mask:0x07FF]) == nil)
		return NO;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x80000 mask:0xFFFF]) == nil)
		return NO;

	return [super createObjects];
}

-(BOOL)mapObjects
{
	if (![super mapObjects])
		return NO;

	if (self.card == nil && (self.card = [[Z80CardII alloc] init]) == nil)
		return NO;

	self.card.orion = self;

	[self.cpu mapObject:self.card atPort:0xF8 count:8];

	self.cpu.IRQLoop = 900000;
	self.cpu.INTE = nil;
	return YES;
}

@end

@implementation Orion128Z80IIM33

- (BOOL)createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-3.3" mask:0x07FF]) == nil)
		return NO;

	return [super createObjects];
}

@end

// Системные регистры ПЭВМ «Орион 128»

@implementation Orion128System

@synthesize orion;

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	switch (addr & 0xFB00)
	{
		case 0xF800:

			self.orion.crt.color = data;
			break;

		case 0xF900:

			self.orion.ram.offset = (data & 0x0F) << 16;
			break;

		case 0xFA00:

			self.orion.crt.page = data;
			break;

		case 0xFB00:

			break;
	}
}

@end

// Z80 Card II

@implementation Z80CardII
{
	BOOL beeper;
}

- (void)RESET:(uint64_t)clock
{
	[self.orion.snd setBeeper:(beeper = NO) clock:clock];
	self.orion.ext.MSB = 0x00;
}

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	switch (addr & 0xFF)
	{
		case 0xF8:

			self.orion.crt.color = data;
			break;

		case 0xF9:

			self.orion.ram.offset = (data & 0x0F) << 16;
			break;

		case 0xFA:

			self.orion.crt.page = data;
			break;

		case 0xFB:

			self.orion.cpu.PAGE = ((~data & 0x80) >> 6) | ((data & 0x20) >> 5);
			self.orion.mem.offset = (data & 0x1F) << 14;

			if(data & 0x40)
				self.orion.cpu.IRQ = (self.orion.cpu.CLK / 900000 + 1) * 900000;
			else
				self.orion.cpu.IRQ = -1;
			break;

		case 0xFC:

			break;

		case 0xFD:

			break;

		case 0xFE:

			[self.orion.snd setBeeper:data & 0x10 clock:clock];
			self.orion.ext.MSB = data & 0x0F;
			break;

		case 0xFF:

			[self.orion.snd setBeeper:(beeper = !beeper) clock:clock];
			break;

	}
}

@end