/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Специалист MX»

 *****/

#import "SpecialistMX.h"
#import "SpecialistMXKeyboard.h"
#import "SpecialistMX2Flash.h"

// ПЭВМ "Специалист MX" с RAMFOS

@implementation SpecialistMX

+ (NSString *)title
{
	return @"Специалист MX";
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(extraMemory:))
	{
		switch (menuItem.tag)
		{
			case 1:
			{
				menuItem.title = [[menuItem.title componentsSeparatedByString:@":"].firstObject
					stringByAppendingFormat:@": 64K + %luK", (self.ram.length >> 10) - 64];

				menuItem.state = FALSE;
				break;
			}

			case 64064:
			case 64128:
			case 64256:
			case 64512:

				menuItem.state = self.ram.length == (64 + menuItem.tag - 64000) * 1024;
				break;

			default:

				menuItem.state = FALSE;
				menuItem.hidden = TRUE;
				return NO;
		}

		menuItem.hidden = FALSE;
		return YES;
	}

	if (menuItem.action == @selector(colorModule:))
	{
		if (!(menuItem.hidden = menuItem.tag != 0))
		{
			menuItem.state = self.crt.isColor;
			return YES;
		}
		else
		{
			menuItem.state = FALSE;
			return NO;
		}
	}

	return [super validateMenuItem:menuItem];
}

- (IBAction)extraMemory:(NSMenuItem *)menuItem
{
	NSUInteger length = self.ram.length;

	switch (menuItem.tag)
	{
		case 1:

			length = length == 128 * 1024 ? length = (512 + 64) * 1024 : (64 + 64) * 1024;
			break;

		case 64064:
		case 64128:
		case 64256:
		case 64512:

			length = (NSUInteger) (64 + menuItem.tag - 64000) * 1024;
			break;

		default:

			return;
	}

	@synchronized(self)
	{
		if (self.ram.length != length)
		{
			[self registerUndoWithMenuItem:menuItem];

			self.ram.length = length;
			self.ram.offset = 0x10000;

			self.crt.screen = *self.ram.pMutableBytes + 0x9000;
			[self.cpu reset];
		}
	}
}

- (IBAction)colorModule:(NSMenuItem *)menuItem
{
	[self registerUndoWithMenuItem:menuItem];
	self.crt.isColor = !self.crt.isColor;
}

- (BOOL)createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] init8080:0x20000]) == nil)
		return FALSE;

	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"SpecialistMX_RAMFOS" mask:0xFFFF]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x20000 mask:0xFFFF]) == nil)
		return FALSE;

	self.ram.offset = 0x10000;

	if (self.kbd == nil && (self.kbd = [[SpecialistMXKeyboard alloc] initRAMFOS]) == nil)
		return FALSE;

	if (self.ext == nil && (self.ext = [[ROMDisk alloc] init]) == nil)
		return FALSE;

	if ([super createObjects] == FALSE)
		return FALSE;

	if (self.fdd == nil && (self.fdd = [[VG93 alloc] initWithQuartz:self.quartz]) == nil)
		return FALSE;

	self.crt.isColor = TRUE;
	self.crt.color = 0x70;

	self.snd.channel0 = TRUE;
	self.snd.rkmode = TRUE;
	return TRUE;
}

- (BOOL)mapObjects
{
	self.nextResponder = self.kbd;
	self.kbd.computer = self;

	self.kbd.nextResponder = self.ext;
	self.ext.computer = self;

	self.ext.nextResponder = self.fdd;
	self.fdd.computer = self;

	self.crt.screen = *self.ram.pMutableBytes + 0x9000;

	MEM *mem = [self.ram memoryAtOffest:0x0000];

	[self.cpu mapObject:mem atPage:0 from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt atPage:0 from:0x9000 to:0xBFFF RD:mem];
	[self.cpu mapObject:mem atPage:0 from:0xC000 to:0xFFBF];

	[self.cpu mapObject:self.ram atPage:1 from:0x0000 to:0xFFBF];

	[self.cpu mapObject:self.rom atPage:2 from:0x0000 to:0xBFFF WR:nil];
	[self.cpu mapObject:mem atPage:2 from:0xC000 to:0xFFBF];

	if (self.sys == nil && (self.sys = [[SpecialistMXSystem alloc] init]) == nil)
		return FALSE;

	for (uint8_t page = 0; page <= 2; page++)
	{
		[self.cpu mapObject:mem atPage:page from:0xFFC0 to:0xFFDF];
		[self.cpu mapObject:self.kbd atPage:page from:0xFFE0 to:0xFFE3];        // U7
		[self.cpu mapObject:self.ext atPage:page from:0xFFE4 to:0xFFE7];        // U6
		[self.cpu mapObject:self.fdd atPage:page from:0xFFE8 to:0xFFEB];        // U5
		[self.cpu mapObject:self.snd atPage:page from:0xFFEC to:0xFFEF];        // U4
		[self.cpu mapObject:self.sys atPage:page from:0xFFF0 to:0xFFF3];        // U3
		[self.cpu mapObject:nil      atPage:page from:0xFFF4 to:0xFFF7];        // U2
		[self.cpu mapObject:self.sys atPage:page from:0xFFF8 to:0xFFFB];        // U1
		[self.cpu mapObject:self.sys atPage:page from:0xFFFC to:0xFFFF];        // U0
	}

	self.sys.specialist = self;
	self.cpu.HLDA = self.fdd;
	return TRUE;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
	[coder encodeObject:self.fdd forKey:@"fdd"];
}

- (BOOL)decodeWithCoder:(NSCoder *)coder
{
	if (![super decodeWithCoder:coder])
		return FALSE;

	if ((self.fdd = [coder decodeObjectForKey:@"fdd"]) == nil)
		return FALSE;

	return TRUE;
}

@end

// ПЭВМ "Специалист MX" с MXOS (Commander)

@implementation SpecialistMX_MXOS

- (BOOL)createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"SpecialistMX_Commander" mask:0xFFFF]) == nil)
		return FALSE;

	if (self.kbd == nil && (self.kbd = [[SpecialistMXKeyboard alloc] init]) == nil)
		return FALSE;

	if ([super createObjects] == FALSE)
		return FALSE;

	return TRUE;
}

@end

// ПЭВМ "Специалист MX2"

@implementation SpecialistMX2

- (instancetype)init
{
	return self = [super initWithQuartz:22500000];
}

- (BOOL)mapObjects
{
	if (self.sys == nil && (self.sys = [[SpecialistMX2System alloc] init]) == nil)
		return FALSE;

	if (![super mapObjects])
		return FALSE;

	if (self.rom.length <= 0x8000)
		return FALSE;

	MEM *mem = [self.ram memoryAtOffest:0x0000];

	[self.cpu mapObject:[self.rom memoryAtOffest:0x8000 mask:0x7FFF] atPage:2 from:0x0000 to:0x7FFF WR:nil];

	[self.cpu mapObject:mem atPage:2 from:0x8000 to:0x8FFF];
	[self.cpu mapObject:self.crt atPage:2 from:0x9000 to:0xBFFF RD:mem];

	[self.cpu mapObject:self.rom atPage:4 from:0x0000 to:0x7FFF WR:nil];
	[self.cpu mapObject:mem atPage:5 from:0x0000 to:0x7FFF];

	for (uint8_t page = 4; page <= 5; page++)
	{
		[self.cpu mapObject:mem atPage:page from:0x8000 to:0x8FFF];
		[self.cpu mapObject:self.crt atPage:page from:0x9000 to:0xBFFF RD:mem];
		[self.cpu mapObject:mem atPage:page from:0xC000 to:0xEFFF];

		for (uint16_t addr = 0xF000; addr < 0xF800; addr += 32)
		{
			[self.cpu mapObject:self.kbd atPage:page from:addr + 0x00 to:addr + 0x03];        // U7
			[self.cpu mapObject:self.ext atPage:page from:addr + 0x04 to:addr + 0x07];        // U6
			[self.cpu mapObject:self.fdd atPage:page from:addr + 0x08 to:addr + 0x0B];        // U5
			[self.cpu mapObject:self.snd atPage:page from:addr + 0x0C to:addr + 0x0F];        // U4
			[self.cpu mapObject:self.sys atPage:page from:addr + 0x10 to:addr + 0x13];        // U3
			[self.cpu mapObject:nil      atPage:page from:addr + 0x14 to:addr + 0x17];        // U2
			[self.cpu mapObject:self.sys atPage:page from:addr + 0x18 to:addr + 0x1B];        // U1
			[self.cpu mapObject:self.sys atPage:page from:addr + 0x1C to:addr + 0x1F];        // U0
		}

		[self.cpu mapObject:self.kbd atPage:page from:0xF800 to:0xFFFF];
	}

	return TRUE;
}

- (BOOL)createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"SpecialistMX2" mask:0x7FFF]) == nil)
		return FALSE;

	if (self.cpu == nil && (self.cpu = [[X8080 alloc] init8080:0x40000]) == nil)
		return FALSE;

	if (self.ext == nil && (self.ext = [[SpecialistMX2Flash alloc] init]) == nil)
		return FALSE;

	if (![super createObjects])
		return FALSE;

	return TRUE;
}

@end
