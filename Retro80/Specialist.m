/*******************************************************************************
 ПЭВМ «Специалист»
 ******************************************************************************/

#import "Specialist.h"

// =============================================================================
// Интерфейс графического экрана ПЭВМ "Специалист"
// =============================================================================

@implementation SpecialistScreen
{
	uint8_t colors[0x3000];

	uint32_t* bitmap;
	uint64_t CLK;

	uint32_t color0;
	uint32_t color1;

	uint8_t color;
	BOOL isColor;
}

@synthesize screen;

// -----------------------------------------------------------------------------
// @protocol ReadWrite
// -----------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	return screen && addr & 0x3000 ? screen[(addr & 0x3FFF) - 0x1000] : status;
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	if (screen && addr & 0x3000)
	{
		addr = (addr & 0x3FFF) - 0x1000; screen[addr] = data; colors[addr] = color; if (bitmap)
		{
			uint32_t* ptr = bitmap + ((addr & 0x3F00) >> 5) + (addr & 0xFF) * 384;

			for (int i = 0; i < 8; i++)
				*ptr++ = data & (0x80 >> i) ? color1 : color0;
		}

	}
}

// -----------------------------------------------------------------------------
// @protocol Bytes
// -----------------------------------------------------------------------------

- (const uint8_t*) bytesAtAddress:(uint16_t)addr
{
	return screen && addr & 0x3000 ? screen + (addr & 0x3FFF) - 0x1000 : NULL;
}

- (uint8_t*) mutableBytesAtAddress:(uint16_t)addr
{
	return NULL;
}

// -----------------------------------------------------------------------------
// @protocol HLDA
// -----------------------------------------------------------------------------

- (unsigned) HLDA:(uint64_t)clock WR:(BOOL)wr
{
	if (CLK < clock)
	{
		if (bitmap == NULL)
		{
			bitmap = [self.display setupGraphicsWidth:384 height:256];

			uint8_t c = color; for (uint16_t addr = 0x0000; addr < 0x3000; addr++)
			{
				uint32_t* ptr = bitmap + ((addr & 0x3F00) >> 5) + (addr & 0xFF) * 384;

				[self setColor:colors[addr]];

				for (int i = 0; i < 8; i++)
					*ptr++ = screen[addr] & (0x80 >> i) ? color1 : color0;
			}

			[self setColor:c];
		}

		self.display.needsDisplay = TRUE;
		CLK += 18000000/50;
	}

	return 0;
}

// -----------------------------------------------------------------------------
// isColor
// -----------------------------------------------------------------------------

- (void) setIsColor:(BOOL)setIsColor
{
	if (!(isColor = setIsColor))
	{
		color0 = 0xFF000000;
		color1 = 0xFFFFFFFF;
	}
	else
	{
		self.color = color;
	}

	bitmap = NULL;
}


- (BOOL) isColor
{
	return isColor;
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------

- (void) setColor:(uint8_t)setColor
{
	color = setColor; if (isColor)
	{
		if (color & 0x80)
		{
			color1 = 0xFF000000 | (color & 0x40 ? 0x000000FF : 0) | (color & 0x20 ? 0x0000FF00 : 0) | (color & 0x10 ? 0x00FF0000 : 0);
		}
		else
		{
			color1 = 0xFF000000 | (color & 0x40 ? 0x000000AA : 0) | (color & 0x20 ? 0x0000AA00 : 0) | (color & 0x10 ? 0x00AA0000 : 0);
		}

		if (color & 0x08)
		{
			color0 = 0xFF000000 | (color & 0x04 ? 0x000000FF : 0) | (color & 0x02 ? 0x0000FF00 : 0) | (color & 0x01 ? 0x00FF0000 : 0);
		}
		else
		{
			color0 = 0xFF000000 | (color & 0x04 ? 0x000000AA : 0) | (color & 0x02 ? 0x0000AA00 : 0) | (color & 0x01 ? 0x00AA0000 : 0);
		}
	}
}

- (uint8_t) color
{
	return color;
}

// -----------------------------------------------------------------------------
// @protocol DisplayController
// -----------------------------------------------------------------------------

- (unichar) charAtX:(unsigned int)x Y:(unsigned int)y
{
	return 0;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		self.isColor = FALSE;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeBytes:colors length:sizeof(colors) forKey:@"colors"];

	[encoder encodeInt:color forKey:@"color"];
	[encoder encodeBool:isColor forKey:@"isColor"];

	[encoder encodeInt64:CLK forKey:@"CLK"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self init])
	{
		NSUInteger length; const void *ptr;

		if ((ptr = [decoder decodeBytesForKey:@"colors" returnedLength:&length]) && length == sizeof(colors))
		{
			memcpy(colors, ptr, sizeof(colors));

			color = [decoder decodeIntForKey:@"color"];
			self.isColor = [decoder decodeBoolForKey:@"isColor"];

			CLK = [decoder decodeInt64ForKey:@"CLK"];
		}
		else
		{
			return self = nil;
		}
	}

	return self;
}

@end

// =============================================================================
// Интерфейс клавиатуры ПЭВМ "Специалист"
// =============================================================================

@implementation SpecialistKeyboard

// -----------------------------------------------------------------------------
// Порт A
// -----------------------------------------------------------------------------

- (uint8_t) A
{
	keyboard[60] = (modifierFlags & NSAlternateKeyMask) != 0;

	uint8_t data = 0xFF; for (int i = 0; i < 72; i++) if (i % 12 > 3 && keyboard[i])
	{
		if ((B & (0x80 >> (i / 12))) == 0)
			data &= (0x80 >> (i % 12 - 4)) ^ 0xFF;
	}

	return data;
}


// -----------------------------------------------------------------------------
// Порт B
// -----------------------------------------------------------------------------

- (uint8_t) B
{
	keyboard[60] = (modifierFlags & NSAlternateKeyMask) != 0;

	uint8_t data = 0xFF; for (int i = 0; i < 72; i++) if (keyboard[i])
	{
		if (((((C & 0x0F) << 8) | A) & (0x800 >> (i % 12))) == 0)
			data &= (0x80 >> (i / 12)) ^ 0xFF;
	}

	if ((modifierFlags & NSShiftKeyMask))
		data &= ~0x02;

	if (self.snd.sound.input)
		data &= ~0x01;

	return data;
}

// -----------------------------------------------------------------------------
// Порт C
// -----------------------------------------------------------------------------

- (void) setC:(uint8_t)data
{
	self.snd.sound.output = data & 0x80;
	self.snd.sound.beeper = data & 0x20;

	if (self.crt)
		self.crt.color = ~(((data >> 1) & 0x60) | (data & 0x10) | 0x07);
}

- (uint8_t) C
{
	keyboard[60] = (modifierFlags & NSAlternateKeyMask) != 0;

	uint8_t data = 0xFF; for (int i = 0; i < 72; i++) if (i % 12 < 4 && keyboard[i])
	{
		if ((B & (0x80 >> (i / 12))) == 0)
			data &= (0x08 >> (i % 12)) ^ 0xFF;
	}

	return data;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		kbdmap = @[
				   @122, @120, @99,  @118, @96,  @97,  @98,  @100, @101, @109, @103, @117,
				   @10,  @18,  @19,  @20,  @21,  @23,  @22,  @26,  @28,  @25,  @29,  @27,
				   @12,  @13,  @14,  @15,  @17,  @16,  @32,  @34,  @31,  @35,  @33,  @30,
				   @0,   @1,   @2,   @3,   @5,   @4,   @38,  @40,  @37,  @41,  @39,  @42,
				   @6,   @7,   @8,   @9,   @11,  @45,  @46,  @43,  @47,  @44,  @50,  @51,
				   @999, @115, @126, @125, @48,  @53,  @49,  @123, @111, @124, @76,  @36
				   ];
	}

	return self;
}

@end

// =============================================================================
// ПЭВМ "Специалист"
// =============================================================================

@implementation Specialist

+ (NSString *) title
{
	return @"Специалист";
}

+ (NSString *) ext
{
	return @"rks";
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(colorModule:))
	{
		menuItem.state = self.crt.isColor;
		return self.kbd.crt != nil;
	}

	return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Модуль цветности
// -----------------------------------------------------------------------------

- (IBAction) colorModule:(NSMenuItem *)menuItem
{
	[self.document registerUndoWithMenuItem:menuItem];
	self.crt.isColor = !self.crt.isColor;
}

// -----------------------------------------------------------------------------
// Управление компьютером
// -----------------------------------------------------------------------------

- (void) reset
{
	[self.kbd RESET];
	[self.ext RESET];

	self.cpu.PC = 0xC000;
	self.cpu.IF = FALSE;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if ((self.cpu = [[X8080 alloc] initWithQuartz:18000000]) == nil)
		return FALSE;

	if (self.rom == nil && (self.rom = [[Memory alloc] initWithContentsOfResource:@"Specialist2" mask:0x3FFF]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[Memory alloc] initWithLength:0xC000 mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.crt = [[SpecialistScreen alloc] init]) == nil)
		return FALSE;

	if (self.kbd == nil && (self.kbd = [[SpecialistKeyboard alloc] init]) == nil)
		return FALSE;

	if ((self.ext = [[X8255 alloc] init]) == nil)
		return FALSE;

	if ((self.snd = [[X8253 alloc] init]) == nil)
		return FALSE;

	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	self.crt.screen = [self.ram mutableBytesAtAddress:0x9000];

	[self.cpu mapObject:self.ram from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt from:0x9000 to:0xBFFF];
	[self.cpu mapObject:self.rom from:0xC000 to:0xEFFF RO:YES];
	[self.cpu mapObject:self.ext from:0xF000 to:0xF7FF];
	[self.cpu mapObject:self.kbd from:0xF800 to:0xFFFF];

	self.kbdHook = [[F812 alloc] initWithRKKeyboard:self.kbd];
	[self.cpu mapHook:[[F803 alloc] initWithF812:(F812 *)self.kbdHook] atAddress:0xC337];

	[self.cpu mapHook:self.inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xC377];
	self.inpHook.extension = @"rks";
	self.inpHook.type = 3;

	[self.cpu mapHook:self.outHook = [[F80C alloc] init] atAddress:0xC3D0];
	self.outHook.extension = @"rks";
	self.outHook.type = 3;

	self.cpu.HLDA = self.crt;
	self.kbd.crt = self.crt;
	self.kbd.snd = self.snd;
	return TRUE;
}

// -----------------------------------------------------------------------------

- (id) init:(NSInteger)variant
{
	switch (variant)
	{
		case 1:
		case 2:
		case 3:
		case 4:

			if ((self.rom = [[Memory alloc] initWithContentsOfResource:@[@"Specialist1", @"Specialist2", @"SpecialistW", @"SpecialistL"][variant - 1] mask:0x3FFF]) == nil)
				return self = nil;

			if (self = [self init])
				self.crt.isColor = variant != 4;

			return self;

		case 5:

			return self = [[SpecialistSP580 alloc] init];
			
		case 6:

			return self = [[SpecialistMX alloc] init];
			
		default:

			return self = nil;

	}
}

// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		if (![self createObjects])
			return self = nil;

		if (![self mapObjects])
			return self = nil;

		self.cpu.PC = 0xC000;

		self.kbdHook.enabled = FALSE;
		self.inpHook.enabled = TRUE;
		self.outHook.enabled = TRUE;
	}

	return self;
}

// -----------------------------------------------------------------------------

- (id) initWithData:(NSData *)data
{
	const uint8_t* ptr = data.bytes;
	NSUInteger length = data.length;

	if (length > 23 && memcmp(ptr, "\x70\x8F\x82\x8F", 4) == 0)
	{
		ptr += 23; length -= 23; while (length && *ptr == 0x00)
		{
			length--; ptr++;
		}

		if (length-- && *ptr++ == 0xE6 && (self = [self init:4]))
			[self.inpHook setData:[NSData dataWithBytes:ptr length:length]];
		else
			return self = nil;
	}
	else if (length > 4 && memcmp(ptr, "\xD9\xD9\xD9", 3) == 0)
	{
		ptr += 3; length -= 3; while (length && *ptr != 0x00)
		{
			length--; ptr++;
		}

		while (length && *ptr == 0x00)
		{
			length--; ptr++;
		}

		if (length-- && *ptr++ == 0xE6 && (self = [self init:2]))
			[self.inpHook setData:[NSData dataWithBytes:ptr length:length]];
		else
			return self = nil;
	}
	else
	{
		if (self = [self init:2])
		{
			[self.inpHook setData:data];
		}
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];

	[encoder encodeObject:self.cpu forKey:@"cpu"];
	[encoder encodeObject:self.rom forKey:@"rom"];
	[encoder encodeObject:self.ram forKey:@"ram"];
	[encoder encodeObject:self.crt forKey:@"crt"];
	[encoder encodeObject:self.kbd forKey:@"kbd"];
	[encoder encodeObject:self.ext forKey:@"ext"];
	[encoder encodeObject:self.snd forKey:@"snd"];

	[encoder encodeBool:self.kbdHook.enabled forKey:@"kbdHook"];
	[encoder encodeBool:self.inpHook.enabled forKey:@"inpHook"];
	[encoder encodeBool:self.outHook.enabled forKey:@"outHook"];
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

	if ((self.kbd = [decoder decodeObjectForKey:@"kbd"]) == nil)
		return FALSE;

	if ((self.ext = [decoder decodeObjectForKey:@"ext"]) == nil)
		return FALSE;

	if ((self.snd = [decoder decodeObjectForKey:@"snd"]) == nil)
		return FALSE;

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

		self.kbdHook.enabled = [decoder decodeBoolForKey:@"kbdHook"];
		self.inpHook.enabled = [decoder decodeBoolForKey:@"inpHook"];
		self.outHook.enabled = [decoder decodeBoolForKey:@"outHook"];
	}

	return self;
}

@end

// =============================================================================
// ПЭВМ "Специалист SP580"
// =============================================================================

@implementation SpecialistSP580

- (BOOL) createObjects
{
	if ((self.rom = [[Memory alloc] initWithContentsOfResource:@"SpecialistSP580" mask:0x0FFF]) == nil)
		return FALSE;

	if ((self.ram = [[Memory alloc] initWithLength:0x10000 mask:0xFFFF]) == nil)
		return FALSE;

	if ([super createObjects] == FALSE)
		return FALSE;

	self.snd.channel0 = TRUE;
	self.snd.rkmode = TRUE;
	return TRUE;
}

- (BOOL) mapObjects
{
	self.crt.screen = [self.ram mutableBytesAtAddress:0x9000];

	[self.cpu mapObject:self.ram from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt from:0x9000 to:0xBFFF];
	[self.cpu mapObject:self.rom from:0xC000 to:0xC7FF RO:YES];
	[self.cpu mapObject:self.ram from:0xC800 to:0xDFFF];
	[self.cpu mapObject:self.snd from:0xE000 to:0xE7FF];
	[self.cpu mapObject:self.ext from:0xE800 to:0xEFFF];
	[self.cpu mapObject:self.kbd from:0xF000 to:0xF7FF];
	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF RO:YES];

	[self.cpu mapHook:self.kbdHook = [[F81B alloc] initWithRKKeyboard:self.kbd] atAddress:0xF81B];

	self.cpu.HLDA = self.crt;
	self.kbd.crt = self.crt;
	self.kbd.snd = self.snd;
	return TRUE;
}

@end

// =============================================================================
// Интерфейс клавиатуры ПЭВМ "Специалист MX"
// =============================================================================

@implementation SpecialistMXKeyboard

- (id) init
{
	if (self = [super init])
	{
		kbdmap = @[
				   @53,  @109, @122, @120, @99,  @118, @96,  @97,  @98,  @100, @101, @51,
				   @10,  @18,  @19,  @20,  @21,  @23,  @22,  @26,  @28,  @25,  @29,  @27,
				   @12,  @13,  @14,  @15,  @17,  @16,  @32,  @34,  @31,  @35,  @33,  @30,
				   @0,   @1,   @2,   @3,   @5,   @4,   @38,  @40,  @37,  @41,  @39,  @42,
				   @6,   @7,   @8,   @9,   @11,  @45,  @46,  @43,  @47,  @44,  @50,  @117,
				   @999, @115, @126, @125, @999, @999, @49,  @123, @48,  @124, @76,  @36
				   ];
	}

	return self;
}

@end

// =============================================================================
// Системный регистр ПЭВМ "Специалист MX"
// =============================================================================

@implementation SpecialistMXSystem

@synthesize cpu;

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	return status;
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	switch (addr)
	{
		case 0xFFFC:
			cpu.PAGE = 0;
			break;

		case 0xFFFD:
			cpu.PAGE = 2 + (data & 7);
			break;

		case 0xFFFE:
			cpu.PAGE = 1;
			break;

		case 0xFFFF:
			break;
	}
}

@end

// =============================================================================
// Регистр цвета ПЭВМ "Специалист MX"
// =============================================================================

@implementation SpecialistMXColor

@synthesize crt;

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	return status;
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	crt.color = data;
}

@end

// =============================================================================
// ПЭВМ "Специалист MX"
// =============================================================================


@implementation SpecialistMX

+ (NSString *) title
{
	return @"Специалист MX";
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(extraMemory:))
	{
		return !(menuItem.state = self.quasi.count > 1);
	}

	return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Модуль ОЗУ
// -----------------------------------------------------------------------------

- (IBAction) extraMemory:(NSMenuItem *)menuItem
{
	while (self.quasi.count < 8)
	{
		[self.quasi addObject:[[Memory alloc] initWithLength:0x10000 mask:0xFFFF]];

		[self.cpu mapObject:self.quasi.lastObject
					 atPage:self.quasi.count + 1
					   from:0x0000
						 to:0xFFBF];
	}
}


- (void) reset
{
	[self.kbd RESET];
	[self.ext RESET];

	self.cpu.PC = 0x0000;
	self.cpu.IF = FALSE;
	self.cpu.PAGE = 1;
}

- (id) init
{
	if (self = [super init])
	{
		self.cpu.PC = 0x0000;
		self.cpu.PAGE = 1;
	}

	return self;
}

- (BOOL) createObjects
{
	if ((self.rom = [[Memory alloc] initWithContentsOfResource:@"SpecialistMX" mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.ram = [[Memory alloc] initWithLength:0x10000 mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.kbd = [[SpecialistMXKeyboard alloc] init]) == nil)
		return FALSE;

	if ([super createObjects] == FALSE)
		return FALSE;

	Memory *mem; if ((mem = [[Memory alloc] initWithLength:0x10000 mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.quasi = [NSMutableArray arrayWithObject:mem]) == nil)
		return FALSE;

	self.crt.isColor = TRUE;

	self.snd.channel0 = TRUE;
	self.snd.rkmode = TRUE;
	return TRUE;
}

- (BOOL) mapObjects
{
	self.crt.screen = [self.ram mutableBytesAtAddress:0x9000];

	[self.cpu mapObject:self.ram atPage:0 from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt atPage:0 from:0x9000 to:0xBFFF];
	[self.cpu mapObject:self.ram atPage:0 from:0xC000 to:0xFFBF];

	[self.cpu mapObject:self.rom atPage:1 from:0x0000 to:0xBFFF];
	[self.cpu mapObject:self.ram atPage:1 from:0xC000 to:0xFFBF];

	unsigned page = 2; for (Memory* dsk in self.quasi)
		[self.cpu mapObject:dsk atPage:page++ from:0x0000 to:0xFFBF];

	if ((self.sys1 = [[SpecialistMXSystem alloc] init]) == nil)
		return FALSE;

	self.sys1.cpu = self.cpu;

	if ((self.sys2 = [[SpecialistMXColor alloc] init]) == nil)
		return FALSE;

	self.sys2.crt = self.crt;

	[self.cpu mapObject:self.sys1 from:0xFFFC to:0xFFFF];
	[self.cpu mapObject:self.sys2 from:0xFFF8 to:0xFFFB];
//	[self.cpu mapObject:nil       from:0xFFF4 to:0xFFF7];
//	[self.cpu mapObject:nil       from:0xFFF0 to:0xFFF3];
	[self.cpu mapObject:self.snd  from:0xFFEC to:0xFFEF];
//	[self.cpu mapObject:nil       from:0xFFE8 to:0xFFEB];
	[self.cpu mapObject:self.ext  from:0xFFE4 to:0xFFE7];
	[self.cpu mapObject:self.kbd  from:0xFFE0 to:0xFFE3];
	[self.cpu mapObject:self.ram  from:0xFFC0 to:0xFFDF];

	self.cpu.HLDA = self.crt;
	self.kbd.snd = self.snd;
	return TRUE;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];

	[encoder encodeObject:self.quasi forKey:@"quasi"];
}

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
	if (![super decodeWithCoder:decoder])
		return FALSE;

	if ((self.quasi = [decoder decodeObjectForKey:@"quasi"]) == nil)
		return FALSE;

	return TRUE;
}

@end

// -----------------------------------------------------------------------------
