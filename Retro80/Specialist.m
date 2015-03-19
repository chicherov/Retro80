/*******************************************************************************
 ПЭВМ «Специалист»
 ******************************************************************************/

#import "Specialist.h"

// =============================================================================
// Интерфейс графического экрана ПЭВМ "Специалист"
// =============================================================================

@implementation SpecialistScreen
{
	uint8_t screen[2][0x3000];

	uint32_t* bitmap;
	uint64_t CLK;
}

@synthesize color;

// -----------------------------------------------------------------------------
// @protocol ReadWrite
// -----------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	return addr & 0x3000 ? screen [0][(addr & 0x3FFF) - 0x1000] : status;
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	if (addr & 0x3000)
	{
		addr = (addr & 0x3FFF) - 0x1000; screen[0][addr] = data; screen[1][addr] = color; if (bitmap)
		{
			uint32_t* ptr = bitmap + ((addr & 0x3F00) >> 5) + (addr & 0xFF) * 384;	for (int i = 0; i < 8; i++)
				*ptr++ = data & (0x80 >> i) ? (color & 0x80 ? 0xFF000000 : 0xFF0000FF ) | (color & 0x40 ? 0 : 0xFF00)  | (color & 0x10 ? 0 : 0xFF0000) : 0xFF000000;
		}

	}
}

// -----------------------------------------------------------------------------
// @protocol Bytes
// -----------------------------------------------------------------------------

- (const uint8_t*) bytesAtAddress:(uint16_t)addr
{
	return addr & 0x3000 ? screen[0] + (addr & 0x3FFF) - 0x1000 : NULL;
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

			for (uint16_t addr = 0x0000; addr < 0x3000; addr++)
			{
				uint32_t* ptr = bitmap + ((addr & 0x3F00) >> 5) + (addr & 0xFF) * 384;	for (int i = 0; i < 8; i++)
					*ptr++ = screen[0][addr] & (0x80 >> i) ? (screen[1][addr] & 0x80 ? 0xFF000000 : 0xFF0000FF ) | (screen[1][addr] & 0x40 ? 0 : 0xFF00)  | (screen[1][addr] & 0x10 ? 0 : 0xFF0000) : 0xFF000000;
			}
		}

		self.display.needsDisplay = TRUE;
		CLK += 18000000/50;
	}

	return 0;
}

// -----------------------------------------------------------------------------
// isColor
// -----------------------------------------------------------------------------

- (void) setIsColor:(BOOL)isColor
{
	if (!isColor)
	{
		memset(screen[1], color = 0x20, sizeof(screen[1])); bitmap = NULL;
	}
	else
	{
		color = 0x00;
	}
}

- (BOOL) isColor
{
	return color != 0x20;
}

// -----------------------------------------------------------------------------
// @protocol DisplayController
// -----------------------------------------------------------------------------

- (unichar) charAtX:(unsigned int)x Y:(unsigned int)y
{
	return 0;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeBytes:screen[0] length:sizeof(screen) forKey:@"screen"];
	[encoder encodeInt:color forKey:@"color"];
	[encoder encodeInt64:CLK forKey:@"CLK"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self init])
	{
		NSUInteger length; const void *ptr;

		if ((ptr = [decoder decodeBytesForKey:@"screen" returnedLength:&length]) && length == sizeof(screen))
		{
			memcpy(screen[0], ptr, sizeof(screen));

			color = [decoder decodeIntForKey:@"color"];
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

	if (self.crt.isColor)
		self.crt.color = data & 0xD0;
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
		return YES;
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

	if ((self.ram = [[Memory alloc] initWithLength:0x9000 mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.crt = [[SpecialistScreen alloc] init]) == nil)
		return FALSE;

	if ((self.kbd = [[SpecialistKeyboard alloc] init]) == nil)
		return FALSE;

	if ((self.ext = [[X8255 alloc] init]) == nil)
		return FALSE;

	if ((self.snd = [[X8253 alloc] init]) == nil)
		return FALSE;

	return TRUE;
}

- (BOOL) mapObjects
{
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
			{
				if (variant == 4)
					self.crt.isColor = FALSE;
			}

			return self;

		case 5:

			return self = [[SpecialistSP580 alloc] init];

		default:

			return self = nil;

	}
}

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
		if (self = [self init])
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

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		if ((self.cpu = [decoder decodeObjectForKey:@"cpu"]) == nil)
			return self = nil;

		if ((self.rom = [decoder decodeObjectForKey:@"rom"]) == nil)
			return self = nil;

		if ((self.ram = [decoder decodeObjectForKey:@"ram"]) == nil)
			return self = nil;

		if ((self.crt = [decoder decodeObjectForKey:@"crt"]) == nil)
			return self = nil;

		if ((self.kbd = [decoder decodeObjectForKey:@"kbd"]) == nil)
			return self = nil;

		if ((self.ext = [decoder decodeObjectForKey:@"ext"]) == nil)
			return self = nil;

		if ((self.snd = [decoder decodeObjectForKey:@"snd"]) == nil)
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

+ (NSString *) title
{
	return @"Специалист SP580";
}

- (BOOL) createObjects
{
	if ((self.rom = [[Memory alloc] initWithContentsOfResource:@"SpecialistSP580" mask:0x0FFF]) == nil)
		return FALSE;

	if ([super createObjects] == FALSE)
		return FALSE;

	self.snd.channel0 = TRUE;
	self.snd.rkmode = TRUE;
	return TRUE;
}

- (BOOL) mapObjects
{
	[self.cpu mapObject:self.ram from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt from:0x9000 to:0xBFFF];
	[self.cpu mapObject:self.rom from:0xC000 to:0xDFFF RO:YES];

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
