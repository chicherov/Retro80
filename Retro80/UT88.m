#import "UT88.h"

@implementation UT88

+ (NSString *) title
{
	return @"ЮТ-88";
}

+ (NSArray *) extensions
{
	return @[@"rku"];
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(extraMemory:))
	{
		menuItem.state = self.ram.length >= 0x10000;
		return YES;
	}

	if (menuItem.action == @selector(UT88:))
	{
		menuItem.hidden = menuItem.tag < 1 || menuItem.tag > 4;

		switch (menuItem.tag)
		{
			case 1:	// Монитор 0

				menuItem.state = self.is0xxx;
				return YES;

			case 2:	// Монитор F

				menuItem.state = self.isFxxx;
				return self.isExxx;

			case 3:	// Дисплейный модуль

				menuItem.state = self.isExxx;
				return YES;

			case 4:	// RAM диск

				menuItem.state = self.ram.length > 0x10000;
				return self.ram.length >= 0x10000;
		}
	}

	return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Модуль ОЗУ
// -----------------------------------------------------------------------------

- (IBAction) extraMemory:(NSMenuItem *)menuItem
{
	@synchronized(self.snd.sound)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		if (self.ram.length < 0x10000)
		{
			RAM *ram = [[RAM alloc] initWithLength:0x10000 mask:0xFFFF];

			memcpy(ram.mutableBytes + 0x3000, self.ram.mutableBytes + 0x0000, 0x1000);
			memcpy(ram.mutableBytes + 0xC000, self.ram.mutableBytes + 0x1000, 0x0400);
			memcpy(ram.mutableBytes + 0xF400, self.ram.mutableBytes + 0x1400, 0x0400);

			self.ram = ram;
		}
		else
		{
			RAM *ram = [[RAM alloc] initWithLength:0x1800 mask:0xFFF];

			memcpy(ram.mutableBytes + 0x0000, self.ram.mutableBytes + 0x3000, 0x1000);
			memcpy(ram.mutableBytes + 0x1000, self.ram.mutableBytes + 0xC000, 0x4000);
			memcpy(ram.mutableBytes + 0x1400, self.ram.mutableBytes + 0xF400, 0x0400);

			self.ram = ram;
		}

		[self mapObjects];
	}
}

// -----------------------------------------------------------------------------
// Монитор 0/Монитор F/RAM диск
// -----------------------------------------------------------------------------

- (IBAction)UT88:(NSMenuItem *)menuItem
{
	@synchronized(self.snd.sound)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		switch (menuItem.tag)
		{
			case 1:

				self.is0xxx = !self.is0xxx;
				[self mapObjects];
				break;

			case 2:

				self.isFxxx = !self.isFxxx;
				[self mapObjects];
				break;

			case 3:

				if (!(self.isFxxx = self.isExxx = !(self.is0xxx = self.isExxx)))
					memset(self.ramE800.mutableBytes, 0x80, 0x800);

				[self mapObjects];
				[self.cpu reset];

				if (self.is0xxx)
					self.cpu.PC = 0x0000;

				break;

			case 4:

				if (self.ram.length >= 0x10000)
				{
					RAM *ram = [[RAM alloc] initWithLength:self.ram.length == 0x10000 ? 0x50000 : 0x10000 mask:0xFFFF];
					memcpy(ram.mutableBytes, self.ram.mutableBytes, 0x10000);
					self.ram = ram; [self mapObjects];
				}
		}

	}
}

// -----------------------------------------------------------------------------
// reset
// -----------------------------------------------------------------------------

- (IBAction) reset:(NSMenuItem *)menuItem
{
	@synchronized(self.snd.sound)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		[self.cpu reset]; if (self.is0xxx)
			self.cpu.PC = 0x0000;
	}
}


// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:16000000 start:0xF800]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x1800 mask:0x0FFF]) == nil)
		return FALSE;

	if (self.kbd == nil && (self.kbd = [[UT88Keyboard alloc] init]) == nil)
		return FALSE;

	if (self.crt == nil && (self.crt = [[UT88Screen alloc] init]) == nil)
		return FALSE;
	
	if (self.ramE800 == nil && (self.ramE800 = [[RAM alloc] initWithLength:0x800 mask:0x7FF]) == nil)
		return FALSE;

	self.isExxx = TRUE;

	if (self.monitor0 == nil && (self.monitor0 = [[ROM alloc] initWithContentsOfResource:@"UT88-0" mask:0x03FF]) == nil)
		return FALSE;

	self.is0xxx = FALSE;

	if (self.monitorF == nil && (self.monitorF = [[ROM alloc] initWithContentsOfResource:@"UT88-F" mask:0x07FF]) == nil)
		return FALSE;

	self.isFxxx = TRUE;

	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	if (self.snd == nil && (self.snd = [[Micro80Recorder alloc] init]) == nil)
		return FALSE;

	if (self.sys == nil && (self.sys = [[UT88Port40 alloc] init]) == nil)
		return FALSE;

	self.sys.cpu = self.cpu;

	self.crt.memory = self.ramE800.mutableBytes;
	self.crt.cursor = self.ramE800.mutableBytes;
	self.crt.rows = 28;

	self.cpu.IRQ = self.crt;
	self.cpu.RST = 0xFF;
	self.cpu.FF = TRUE;

	// 0000-0FFF

	if (self.is0xxx)
		[self.cpu mapObject:self.monitor0 from:0x0000 to:0x0FFF WR:nil];
	else if (self.ram.length >= 0x10000)
		[self.cpu mapObject:self.ram from:0x0000 to:0x0FFF];
	else
		[self.cpu mapObject:nil from:0x0000 to:0x0FFF];

	// 1000-2FFF

	if (self.ram.length >= 0x10000)
		[self.cpu mapObject:self.ram from:0x1000 to:0x2FFF];
	else
		[self.cpu mapObject:nil from:0x1000 to:0x2FFF];

	// 3000-3FFF

	if (self.isFxxx || self.ram.length >= 0x10000)
		[self.cpu mapObject:self.ram from:0x3000 to:0x3FFF];
	else
		[self.cpu mapObject:nil from:0x3000 to:0x3FFF];

	// 4000-BFFF

	if (self.ram.length >= 0x10000)
		[self.cpu mapObject:self.ram from:0x4000 to:0xBFFF];
	else
		[self.cpu mapObject:nil from:0x4000 to:0xBFFF];

	// C000-CFFF

	if (self.ram.length >= 0x10000)
		[self.cpu mapObject:self.ram from:0xC000 to:0xCFFF];
	else if (self.is0xxx)
		[self.cpu mapObject:[self.ram memoryAtOffest:0x1000 length:0x0400 mask:0x03FF] from:0xC000 to:0xCFFF];
	else
		[self.cpu mapObject:nil from:0xC000 to:0xCFFF];

	// D000-DFFF

	if (self.ram.length >= 0x10000)
		[self.cpu mapObject:self.ram from:0xD000 to:0xDFFF];
	else
		[self.cpu mapObject:nil from:0xD000 to:0xDFFF];

	// E000-EFFF

	if (self.isExxx)
		[self.cpu mapObject:self.ramE800 from:0xE000 to:0xEFFF];
	else if (self.ram.length >= 0x10000)
		[self.cpu mapObject:self.ram from:0xE000 to:0xEFFF];
	else
		[self.cpu mapObject:nil from:0xE000 to:0xEFFF];

	// F000-FFFF

	if (self.isFxxx)
	{
		[self.cpu mapObject:[self.ram memoryAtOffest:self.ram.length >= 0x10000 ? 0xF400 : 0x1400
											  length:0x0400 mask:0x03FF]
					   from:0xF000 to:0xF7FF];

		[self.cpu mapObject:self.monitorF from:0xF800 to:0xFFFF WR:nil];

		if (self.inpHook == nil)
		{
			self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
			self.inpHook.mem = self.monitorF;
			self.inpHook.snd = self.snd;

			self.inpHook.extension = @"rku";
			self.inpHook.type = 4;

			self.inpHook.enabled = TRUE;
		}

		[self.cpu mapObject:self.inpHook from:0xFB71 to:0xFB71 WR:nil];

		if (self.outHook == nil)
		{
			self.outHook = [[F80C alloc] initWithX8080:self.cpu];
			self.inpHook.mem = self.monitorF;
			self.outHook.snd = self.snd;

			self.outHook.extension = @"rku";
			self.outHook.type = 4;

			self.outHook.enabled = TRUE;
		}

		[self.cpu mapObject:self.outHook from:0xFBEE to:0xFBEE WR:nil];
	}
	else
	{
		if (self.ram.length >= 0x10000)
			[self.cpu mapObject:self.ram from:0xF000 to:0xFFFF];
		else
			[self.cpu mapObject:nil from:0xF000 to:0xFFFF];

		self.inpHook = nil;
		self.outHook = nil;
	}

	// 9000-9002

	self.crt.mem = self.ram.length >= 0x10000 ? self.ram : nil;
	[self.cpu mapObject:self.crt from:0x9000 to:0x9002 RD:self.crt.mem];

	[self.cpu mapObject:self.crt atPort:0x90 count:0x03];
	[self.cpu mapObject:self.kbd atPort:0xA0 count:0x01];
	[self.cpu mapObject:self.snd atPort:0xA1 count:0x01];
	[self.cpu mapObject:self.kbd atPort:0x04 count:0x04];

	if (self.ram.length > 0x10000)
	{
		[self.cpu mapObject:self.sys atPort:0x40 count:0x01];

		for (unsigned page = 1; page <= 4; page++)
			[self.cpu mapObject:[self.ram memoryAtOffest:page << 16 length:0x10000 mask:0xFFFF]
						 atPage:page from:0x0000 to:0xFFFF];
	}
	else
	{
		[self.cpu mapObject:nil atPort:0x40 count:0x01];

		for (unsigned page = 1; page <= 4; page++)
			[self.cpu mapObject:nil atPage:page from:0x0000 to:0xFFFF];
	}

	return TRUE;
}

// -----------------------------------------------------------------------------

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	if ((self.ram = [[RAM alloc] initWithLength:0x10000 mask:0xFFFF]) == nil)
		return self = nil;

	if (self = [self initWithType:0])
	{
		self.inpHook.buffer = data;
		[self.kbd paste:@"I\n"];
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/decodeWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];

	[encoder encodeObject:self.cpu forKey:@"cpu"];
	[encoder encodeObject:self.ram forKey:@"ram"];
	[encoder encodeObject:self.kbd forKey:@"kbd"];
	[encoder encodeObject:self.crt forKey:@"crt"];

	[encoder encodeObject:self.ramE800 forKey:@"ramE800"];
	[encoder encodeBool:self.isExxx forKey:@"isExxx"];

	[encoder encodeObject:self.monitor0 forKey:@"monitor0"];
	[encoder encodeBool:self.is0xxx forKey:@"is0xxx"];

	[encoder encodeObject:self.monitorF forKey:@"monitorF"];
	[encoder encodeBool:self.isFxxx forKey:@"isFxxx"];
}

// -----------------------------------------------------------------------------

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
	if (![super decodeWithCoder:decoder])
		return FALSE;

	if ((self.cpu = [decoder decodeObjectForKey:@"cpu"]) == nil)
		return FALSE;

	if ((self.ram = [decoder decodeObjectForKey:@"ram"]) == nil)
		return FALSE;

	if ((self.kbd = [decoder decodeObjectForKey:@"kbd"]) == nil)
		return FALSE;

	if ((self.crt = [decoder decodeObjectForKey:@"crt"]) == nil)
		return FALSE;

	if ((self.ramE800 = [decoder decodeObjectForKey:@"ramE800"]) == nil)
		return FALSE;

	self.isExxx = [decoder decodeBoolForKey:@"isExxx"];
	
	if ((self.monitor0 = [decoder decodeObjectForKey:@"monitor0"]) == nil)
		return FALSE;

	self.is0xxx = [decoder decodeBoolForKey:@"is0xxx"];

	if ((self.monitorF = [decoder decodeObjectForKey:@"monitorF"]) == nil)
		return FALSE;

	self.isFxxx = [decoder decodeBoolForKey:@"isFxxx"];

	return TRUE;
}

@end

// -----------------------------------------------------------------------------
// UT88Port40
// -----------------------------------------------------------------------------

@implementation UT88Port40

@synthesize cpu;

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	cpu.RAMDISK = data & 0x08 ? data & 0x04 ? data & 0x02 ? data & 0x01 ? 0 : 1 : 2 : 3 : 4;
}

- (void) RESET
{
	cpu.RAMDISK = 0;
}

@end

// -----------------------------------------------------------------------------
// UT88Keyboard
// -----------------------------------------------------------------------------

@implementation UT88Keyboard
{
	uint8_t key;
}

- (void) keyDown:(NSEvent*)theEvent
{
//	if ((theEvent.modifierFlags & NSAlternateKeyMask))
//	{
		NSUInteger index = [@"0123456789ABCDEF\x7F" rangeOfString:theEvent.charactersIgnoringModifiers.uppercaseString].location;
		key = index == NSNotFound ? 0x00 : index == 0 ? 0x10 : index == 16 ? 0x80 : (uint8_t)index;
//	}
//	else
//	{
		[super keyDown:theEvent];
//	}
}

- (void) keyUp:(NSEvent *)theEvent
{
//	if ((theEvent.modifierFlags & NSAlternateKeyMask) == 0)
		[super keyUp:theEvent];
//	else
		key = 0x00;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if (addr != 0xA0A0)
		[super RD:addr data:data CLK:clock];

	else
		*data = key;
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	if (addr != 0xA0A0)
		[super WR:addr data:data CLK:clock];
}

- (void) RESET
{
	[super RESET];
	key = 0x00;
}

@end

// -----------------------------------------------------------------------------
// UT88Screen
// -----------------------------------------------------------------------------

@implementation UT88Screen
{
	uint8_t lcd[3];
	uint64_t IRQ;
	BOOL update;
}

- (void) setDisplay:(Display *)display
{
	display.digit1.hidden = FALSE;
	display.digit2.hidden = FALSE;
	display.digit3.hidden = FALSE;
	display.digit4.hidden = FALSE;
	display.digit5.hidden = FALSE;
	display.digit6.hidden = FALSE;

	[super setDisplay:display];
}

- (void) draw
{
	if (update)
	{
		static uint8_t mask[] =
		{
			0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71
		};

		self.display.digit1.segments = mask[lcd[2] >> 4];
		self.display.digit2.segments = mask[lcd[2] & 15];
		self.display.digit3.segments = mask[lcd[1] >> 4];
		self.display.digit4.segments = mask[lcd[1] & 15];
		self.display.digit5.segments = mask[lcd[0] >> 4];
		self.display.digit6.segments = mask[lcd[0] & 15];
	}

	[super draw];
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if (addr >= 0x9000 && addr <= 0x9002)
		[self.mem RD:addr data:data CLK:clock];
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	if (addr >= 0x9000 && addr <= 0x9002)
		[self.mem WR:addr data:data CLK:clock];

	lcd[addr & 3] = data;
	update = TRUE;
}

- (BOOL) IRQ:(uint64_t)clock
{
	if (IRQ <= clock)
	{
		IRQ += 16000000;
		return TRUE;
	}

	return FALSE;
}

- (void) RESET
{
	lcd[0] = 0xFF;
	lcd[1] = 0xFF;
	lcd[2] = 0xFF;
	update = TRUE;
}

- (id) init
{
	if (self = [super init])
		[self RESET];

	return self;
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self init])
	{
		[decoder decodeValueOfObjCType:@encode(uint8_t[3]) at:&lcd];
		IRQ = [decoder decodeInt64ForKey:@"IRQ"];
	}

	return self;
}

- (void) encodeWithCoder:(NSCoder *)coder
{
	[coder encodeValueOfObjCType:@encode(uint8_t[3]) at:&lcd];
	[coder encodeInt64:IRQ forKey:@"IRQ"];
}

@end
