/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Орион 128»

 *****/

#import "Orion128.h"

// =============================================================================
// Системные регистры ПЭВМ "Орион 128"
// =============================================================================

@implementation Orion128SystemF8
{
	Orion128Screen *crt;
}

- (id) initWithCRT:(Orion128Screen *)_crt
{
	if (self = [super init])
		crt = _crt;

	return self;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	crt.color = data;
}

@end

// -----------------------------------------------------------------------------

@implementation Orion128SystemF9
{
	X8080 __weak *cpu;
}

- (id) initWithCPU:(X8080 *)_cpu
{
	if (self = [super init])
		cpu = _cpu;

	return self;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	cpu.PAGE = (cpu.PAGE & ~0x03) | (data & 0x03);
}

@end

// -----------------------------------------------------------------------------

@implementation Orion128SystemFA
{
	Orion128Screen *crt;
}

- (id) initWithCRT:(Orion128Screen *)_crt
{
	if (self = [super init])
		crt = _crt;

	return self;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	crt.page = data;
}

@end

// =============================================================================
// ПЭВМ "Орион 128"
// =============================================================================

@implementation Orion128

+ (NSString *) title
{
	return @"Орион 128";
}

+ (NSArray *) extensions
{
	return @[@"rko"];
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(colorModule:) || (menuItem.action == @selector(floppy:) && menuItem.tag == 0))
	{
		menuItem.state = TRUE;
		return NO;
	}

	if (menuItem.action == @selector(extraMemory:))
	{
		menuItem.state = self.ram.length != 0x20000;
		menuItem.submenu = nil;
		return TRUE;
	}

	if (menuItem.action == @selector(ROMDisk:) && (menuItem.tag == 0 || menuItem.tag == 1))
	{
		if (menuItem.tag == 0)
		{
			if ((menuItem.state = self.ext.URL && ![self.ext.URL.URLByDeletingLastPathComponent.path isEqualToString:NSBundle.mainBundle.resourcePath]))
			{
				menuItem.title = [([menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingFormat:@": %@", self.ext.URL.lastPathComponent];
			}
			else
			{
				menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;
			}

			menuItem.submenu = nil;
		}
		else
		{
			menuItem.state = [self.ext.URL.URLByDeletingLastPathComponent.path isEqualToString:[NSBundle mainBundle].resourcePath];
			menuItem.hidden = FALSE; // !(menuItem.state || self.ext.URL == nil);
		}

		return YES;
	}

	if (menuItem.action == @selector(floppy:) && (menuItem.tag >= 1 && menuItem.tag <= 4))
	{
		NSURL *url = [self.fdd getDisk:menuItem.tag]; if ((menuItem.state = url != nil))
			menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingFormat:@": %@", url.lastPathComponent];
		else
			menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingString:@":"];

		return menuItem.tag != self.fdd.selected || !self.fdd.busy;
	}
	
	return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Модуль ОЗУ
// -----------------------------------------------------------------------------

- (IBAction) extraMemory:(NSMenuItem *)menuItem
{
	RAM *ram = [[[self.ram class] alloc] initWithLength:self.ram.length == 0x20000 ? 0x40000 : 0x20000 mask:self.ram.mask];

	if (ram) @synchronized(self.cpu)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		memcpy(ram.mutableBytes, self.ram.mutableBytes, 0x20000);
		self.ram = ram; mem[0] = mem[1] = mem[2] = mem[3] = nil;

		[self mapObjects];
		[self.cpu reset];
	}
}

// -----------------------------------------------------------------------------
// Внешний ROM-диск
// -----------------------------------------------------------------------------

- (IBAction) ROMDisk:(NSMenuItem *)menuItem
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.allowedFileTypes = @[@"rom", @"bin"];
	panel.delegate = self.ext;

	if (menuItem.tag == 0)
	{
		if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
		{
			[self.document registerUndoWithMenuItem:menuItem];
			self.ext.URL = panel.URLs.firstObject;
		}
		else if (self.ext.URL != nil && ![self.ext.URL.URLByDeletingLastPathComponent.path isEqualToString:[NSBundle mainBundle].resourcePath])
		{
			[self.document registerUndoWithMenuItem:menuItem];
			self.ext.URL = nil;
		}
	}
	else
	{
		if (![self.ext.URL.URLByDeletingLastPathComponent.path isEqualToString:NSBundle.mainBundle.resourcePath])
		{
			BOOL isMonitor1 = memcmp(self.rom.mutableBytes + 0x42, "\x31\xC9\xF3\xAF\x32\x00\xF8", 7) == 0;

			self.ext.URL = [[NSBundle mainBundle] URLForResource:isMonitor1 ? @"ORDOS-2.40" : @"ORDOS-4.03"
												   withExtension:@"rom"];
		}
		else
		{
			[self.document registerUndoWithMenuItem:menuItem];
			self.ext.URL = nil;
		}
	}
}

// -----------------------------------------------------------------------------
// Модуль контроллера дисковода
// -----------------------------------------------------------------------------

- (IBAction) floppy:(NSMenuItem *)menuItem
{
	if (menuItem.tag >= 1 && menuItem.tag <= 2)
	{
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		panel.allowedFileTypes = @[@"odi", @"kdi", @"cpm"];
		panel.title = menuItem.title;
		
		if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
		{
			@synchronized(self.cpu)
			{
				[self.document registerUndoWithMenuItem:menuItem];
				[self.fdd setDisk:menuItem.tag URL:panel.URLs.firstObject];
			}
		}
		else if ([self.fdd getDisk:menuItem.tag] != nil)
		{
			@synchronized(self.cpu)
			{
				[self.document registerUndoWithMenuItem:menuItem];
				[self.fdd setDisk:menuItem.tag URL:nil];
			}
		}
	}
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:22500000 start:0xF800]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x40000 mask:0xFFFF]) == nil)
		return FALSE;

	if (self.rom == nil)
		return FALSE;

	if (self.crt == nil && (self.crt = [[Orion128Screen alloc] init]) == nil)
		return FALSE;

	if (self.fdd == nil && (self.fdd = [[Orion128Floppy alloc] initWithQuartz:self.cpu.quartz]) == nil)
		return FALSE;

	if (self.kbd == nil && (self.kbd = [[RKKeyboard alloc] init]) == nil)
		return FALSE;

	if (self.ext == nil && (self.ext = [[ROMDisk alloc] init]) == nil)
		return FALSE;

	if (self.prn == nil && (self.prn = [[X8255 alloc] init]) == nil)
		return FALSE;

	if (self.snd == nil && (self.snd = [[X8253 alloc] init]) == nil)
		return FALSE;

	self.snd.channel0 = TRUE;
	self.snd.rkmode = TRUE;

	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	if (self.sysF8 == nil && (self.sysF8 = [[Orion128SystemF8 alloc] initWithCRT:self.crt]) == nil)
		return FALSE;

	if (self.sysF9 == nil && (self.sysF9 = [[Orion128SystemF9 alloc] initWithCPU:self.cpu]) == nil)
		return FALSE;

	if (self.sysFA == nil && (self.sysFA = [[Orion128SystemFA alloc] initWithCRT:self.crt]) == nil)
		return FALSE;

	self.cpu.INTE = self.snd;
	self.kbd.snd = self.snd;

	self.cpu.FF = TRUE;

	self.crt.memory = self.ram.mutableBytes;

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

	for (uint8_t page = 0; page < 16; page++)
	{
		if (page < 4 && mem[page] == nil)
			mem[page] = [self.ram memoryAtOffest:page << 16 length:0x10000 mask:0xFFFF];

		if ((page & 8) == 0)
		{
			[self.cpu mapObject:mem[page & 3]	atPage:page from:0x0000 to:0xEFFF];
		}
		else
		{
			[self.cpu mapObject:self.ram		atPage:page from:0x0000 to:0x3FFF];
			[self.cpu mapObject:mem[page & 3]	atPage:page from:0x4000 to:0xEFFF];
		}

		if ((page & 4) == 0)
		{
			[self.cpu mapObject:mem[0]			atPage:page from:0xF000 to:0xF3FF];
			[self.cpu mapObject:self.kbd		atPage:page from:0xF400 to:0xF4FF];
			[self.cpu mapObject:self.ext		atPage:page from:0xF500 to:0xF5FF];
			[self.cpu mapObject:self.prn		atPage:page from:0xF600 to:0xF6FF];

			[self.cpu mapObject:self.fdd		atPage:page from:0xF700 to:0xF72F];

			[self.cpu mapObject:self.snd		atPage:page from:0xF740 to:0xF75F];

			[self.cpu mapObject:self.rom		atPage:page from:0xF800 to:0xF8FF WR:self.sysF8];
			[self.cpu mapObject:self.rom		atPage:page from:0xF900 to:0xF9FF WR:self.sysF9];
			[self.cpu mapObject:self.rom		atPage:page from:0xFA00 to:0xFAFF WR:self.sysFA];
			[self.cpu mapObject:self.rom		atPage:page from:0xFB00 to:0xFBFF WR:self.crt];

			[self.cpu mapObject:self.rom		atPage:page from:0xFB00 to:0xFFFF WR:nil];

			[self.cpu mapObject:self.inpHook	atPage:page from:F806 to:F806
							 WR:F806 < 0xF900 ? self.sysF8 : F806 < 0xFA00 ? self.sysF9 : F806 < 0xFB00 ? self.sysFA : F806 < 0xFC00 ? self.crt : nil];

			[self.cpu mapObject:self.outHook	atPage:page from:F80C to:F80C
							 WR:F80C < 0xF900 ? self.sysF8 : F80C < 0xFA00 ? self.sysF9 : F80C < 0xFB00 ? self.sysFA : F80C < 0xFC00 ? self.crt : nil];
		}
		else
		{
			[self.cpu mapObject:mem[page & 3]	atPage:page from:0xF000 to:0xFFFF];
		}
	}

	return TRUE;
}

// -----------------------------------------------------------------------------

- (id) initWithType:(NSInteger)type
{
	if (self = [super init])
	{
		switch (type)
		{
			case 1:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-1" mask:0x07FF]) == nil)
					return self = nil;

				break;

			case 2:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-2" mask:0x07FF]) == nil)
					return self = nil;

				break;

			case 3:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-3.1" mask:0x07FF]) == nil)
					return self = nil;

				break;

			case 4:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-3.2" mask:0x07FF]) == nil)
					return self = nil;

				if ((self.cpu = [[X8080 alloc] initZ80WithQuartz:5000000 start:0xF800]) == nil)
					return FALSE;

				break;

			case 5:
			case 6:

				return self = [[Orion128Z80CardII alloc] initWithType:type];
		}

		if (![self createObjects])
			return self = nil;

		self.ext.URL = [[NSBundle mainBundle] URLForResource:type == 1 ? @"ORDOS-2.40" : @"ORDOS-4.03"
											   withExtension:@"rom"];
		if (![self mapObjects])
			return self = nil;

		self.inpHook.enabled = TRUE;
		self.outHook.enabled = TRUE;
	}

	return self;
}

// -----------------------------------------------------------------------------

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	if (self = [self initWithType:3])
	{
		self.inpHook.buffer = data;
		[self.kbd paste:@"\nI\n"];
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/decodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];

	[encoder encodeObject:self.cpu forKey:@"cpu"];
	[encoder encodeObject:self.rom forKey:@"rom"];
	[encoder encodeObject:self.ram forKey:@"ram"];
	[encoder encodeObject:self.crt forKey:@"crt"];
	[encoder encodeObject:self.fdd forKey:@"fdd"];
	[encoder encodeObject:self.kbd forKey:@"kbd"];
	[encoder encodeObject:self.ext forKey:@"ext"];
	[encoder encodeObject:self.prn forKey:@"prn"];
	[encoder encodeObject:self.snd forKey:@"snd"];
}

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
	if ((self.cpu = [decoder decodeObjectForKey:@"cpu"]) == nil)
		return FALSE;

	if ((self.rom = [decoder decodeObjectForKey:@"rom"]) == nil)
		return FALSE;

	if ((self.ram = [decoder decodeObjectForKey:@"ram"]) == nil)
		return FALSE;

	if ((self.crt = [decoder decodeObjectForKey:@"crt"]) == nil)
		return FALSE;

	if ((self.fdd = [decoder decodeObjectForKey:@"fdd"]) == nil)
		return FALSE;

	if ((self.kbd = [decoder decodeObjectForKey:@"kbd"]) == nil)
		return FALSE;

	if ((self.ext = [decoder decodeObjectForKey:@"ext"]) == nil)
		return FALSE;

	if ((self.prn = [decoder decodeObjectForKey:@"prn"]) == nil)
		return FALSE;

	if ((self.snd = [decoder decodeObjectForKey:@"snd"]) == nil)
		return FALSE;

	return TRUE;
}

@end

// =============================================================================
// Системные регистры Z80Card-II
// =============================================================================

@implementation Orion128RAM

@synthesize offset;

- (uint8_t *) BYTE:(uint16_t)addr
{
	return offset + (addr & mask) >= length ? NULL : mutableBytes + offset + (addr & mask);
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if (offset + (addr & mask) < length) *data = mutableBytes[offset + (addr & mask)];
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	if (offset + (addr & mask) < length) mutableBytes[offset + (addr & mask)] = data;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	[encoder encodeInt:offset forKey:@"offset"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		offset = [decoder decodeIntForKey:@"offset"];
	}

	return self;
}

@end

// -----------------------------------------------------------------------------

@implementation Orion128SystemFB
{
	Orion128Screen *crt;
	X8080 __weak *cpu;
	Orion128RAM *ram;
}

- (id) initWithCPU:(X8080 *)_cpu RAM:(Orion128RAM *)_ram CRT:(Orion128Screen *)_crt
{
	if (self = [super init])
	{
		cpu = _cpu;
		ram = _ram;
		crt = _crt;
	}

	return self;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	cpu.PAGE = ((~data & 0x80) >> 4) | ((data & 0x20) >> 3) | (cpu.PAGE & 0x03);
	ram.offset = (data & 0x0F) << 14;
	crt.IE = data & 0x40;
}

@end

// -----------------------------------------------------------------------------

@implementation Orion128SystemFE
{
	X8253 *snd;
	ROMDisk *ext;
}

- (id) initWithX8253:(X8253 *)s EXT:(ROMDisk *)e
{
	if (self = [super init])
	{
		snd = s;
		ext = e;
	}

	return self;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	[snd setBeeper:data & 0x10 clock:clock];
	ext.MSB = data & 0x0F;
}

@end

// -----------------------------------------------------------------------------

@implementation Orion128SystemFF
{
	BOOL beeper;
	X8253 *snd;
}

- (id) initWithX8253:(X8253 *)s
{
	if (self = [super init])
		snd = s;

	return self;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	[snd setBeeper:beeper = !beeper clock:clock];
}

@end

// =============================================================================
// ПЭВМ "Орион 128" + Z80Card-II
// =============================================================================

@implementation Orion128Z80CardII

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
//	if (menuItem.action == @selector(extraMemory:) || (menuItem.action == @selector(floppy:) && menuItem.tag == 0))
//	{
//		menuItem.submenu = nil; menuItem.state = TRUE; return FALSE;
//	}

	return [super validateMenuItem:menuItem];
}

- (id) initWithType:(NSInteger)type
{
	if (self = [super init])
	{
		switch (type)
		{
			case 5:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-3.2" mask:0x07FF]) == nil)
					return self = nil;

				break;

			case 6:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-3.3" mask:0x07FF]) == nil)
					return self = nil;

				break;
		}

		if (![self createObjects])
			return self = nil;

		if (![self mapObjects])
			return self = nil;

		self.inpHook.enabled = TRUE;
		self.outHook.enabled = TRUE;
	}
	
	return self;
}

- (BOOL) createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initZ80WithQuartz:5000000 start:0xF800]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[Orion128RAM alloc] initWithLength:0x40000 mask:0xFFFF]) == nil)
		return FALSE;

	return [super createObjects];
}

- (BOOL) mapObjects
{
	if (self.sysFB == nil && (self.sysFB = [[Orion128SystemFB alloc] initWithCPU:self.cpu RAM:self.ram CRT:self.crt]) == nil)
		return FALSE;

	if (self.sysFE == nil && (self.sysFE = [[Orion128SystemFE alloc] initWithX8253:self.snd EXT:self.ext]) == nil)
		return FALSE;

	if (self.sysFF == nil && (self.sysFF = [[Orion128SystemFF alloc] initWithX8253:self.snd]) == nil)
		return FALSE;

	if ([super mapObjects])
	{
		[self.cpu mapObject:self.sysF8 atPort:0xF8];
		[self.cpu mapObject:self.sysF9 atPort:0xF9];
		[self.cpu mapObject:self.sysFA atPort:0xFA];
		[self.cpu mapObject:self.sysFB atPort:0xFB];

		[self.cpu mapObject:self.sysFE atPort:0xFE];
		[self.cpu mapObject:self.sysFF atPort:0xFF];

		self.cpu.IRQ = self.crt;
		self.cpu.RST = 0xFF;

		self.cpu.INTE = nil;
		return TRUE;
	}

	return FALSE;
}

@end
