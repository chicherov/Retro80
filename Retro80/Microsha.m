/*******************************************************************************
 ПЭВМ «Микроша»
 ******************************************************************************/

#import "Microsha.h"

// -----------------------------------------------------------------------------
// Первый интерфейс 8255, вариант клавиатуры РК86 для Микроши
// -----------------------------------------------------------------------------

@implementation MicroshaKeyboard

- (id) init
{
	if (self = [super init])
	{
		kbdmap = @[@7,   @16,  @6,   @33,  @42,  @30,  @39,  @51,
				   @35,  @12,  @15,  @1,   @17,  @32,  @9,   @13,
				   @4,   @34,  @38,  @40,  @37,  @46,  @45,  @31,
				   @41,  @0,   @11,  @8,   @2,   @14,  @3,   @5,
				   @28,  @25,  @24,  @50,  @43,  @27,  @47,  @44,
				   @29,  @18,  @19,  @20,  @21,  @23,  @22,  @26,
				   @126, @125, @115, @122, @120, @99,  @118, @96,
				   @49,  @53,  @48,  @76,  @36,  @117, @123, @124];

		RUSLAT = 0x20;
		SHIFT = 0x80;
	}

	return self;
}

// -----------------------------------------------------------------------------

- (void) setC:(uint8_t)C
{
	if ((C ^ _C) & 0x06)
		self.snd.channel2 = (C & 0x06) == 0x06 ? TRUE : FALSE;

	if ((C ^ _C) & 0x02)
		self.snd.beeper = C & 0x02 ? TRUE : FALSE;

	[super setC:C];
}

@end

// -----------------------------------------------------------------------------
// Второй интерфейс 8255, управление знакогенератором
// -----------------------------------------------------------------------------

@implementation MicroshaExt

- (void) setB:(uint8_t)B
{
	if ((B ^ _B) & 0x80)
		[self.crt setFontOffset:B & 0x80 ? 0x2800 : 0x0C00];

	_B = B;
}

- (uint8_t) A
{
	return 0x00;
}

- (uint8_t) C
{
	return 0x00;
}

@end

// -----------------------------------------------------------------------------
// Модуль дополнительной памяти
// -----------------------------------------------------------------------------

@implementation MicroshaExtRAM
{
	Microsha* __weak _microsha;
}

- (id) initWithMicrosha:(Microsha *)microsha
{
	if (self = [super init])
	{
		_microsha = microsha;
	}

	return self;
}

- (void) setEnabled:(BOOL)enabled
{
	if ((_microsha.extRAM = enabled))
	{
		[_microsha.cpu mapObject:_microsha.ram atPage:0x80 count:40];
	}
	else
	{
		[_microsha.cpu mapObject:nil atPage:0x80 count:40];
	}
}

- (BOOL) enabled
{
	return _microsha.extRAM;
}

- (NSInteger) tag
{
	return 4;
}

@end

// -----------------------------------------------------------------------------
// FCAB - Вывод байта на магнитофон (Микроша)
// -----------------------------------------------------------------------------

@implementation FCAB

- (int) execute:(X8080 *)cpu
{
	if (cpu.SP == 0x76CD && MEMR(cpu, 0x76CD, 0) == 0x9D && MEMR(cpu, 0x76CE, 0) == 0xF8)
		return 2;

	return [super execute:cpu];
}

@end

// -----------------------------------------------------------------------------
// ПЭВМ Микроша
// -----------------------------------------------------------------------------

@implementation Microsha

+ (NSString *) title
{
	return @"Микроша";
}

// -----------------------------------------------------------------------------

- (void) setColor:(BOOL)color
{
	if (color)
	{
		*(uint8_t *)[self.rom bytesAtAddress:0xF842] = 0xD3;

		static uint32_t colors[] =
		{
			0xFFFFFFFF, 0xFF00FFFF, 0xFFFFFFFF, 0xFF00FFFF,
			0xFFFFFF00, 0xFF00FF00, 0xFFFFFF00, 0xFF00FF00,
			0xFFFF00FF, 0xFF0000FF, 0xFFFF00FF, 0xFF0000FF,
			0xFFFF0000, 0xFF000000, 0xFFFF0000, 0xFF000000
		};

		self.crt.attributesMask = 0xFF;
		self.crt.colors = colors;
	}
	else
	{
		*(uint8_t *)[self.rom bytesAtAddress:0xF842] = 0x93;

		self.crt.attributesMask = 0xEF;
		self.crt.colors = NULL;
	}
}

- (BOOL) isColor
{
	return *(uint8_t *)[self.rom bytesAtAddress:0xF842] == 0xD3;
}

// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Microsha" mask:0x07FF]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0xC000 mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.kbd = [[MicroshaKeyboard alloc] init]) == nil)
		return FALSE;

	if ((self.ext = [[MicroshaExt alloc] init]) == nil)
		return FALSE;

	if (![super createObjects])
		return FALSE;

	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	[self.cpu mapObject:self.ram atPage:0x00 count:self.extRAM ? 0xC0 : 0x80];
	[self.cpu mapObject:self.kbd atPage:0xC0 count:0x08];
	[self.cpu mapObject:self.ext atPage:0xC8 count:0x08];
	[self.cpu mapObject:self.crt atPage:0xD0 count:0x08];
	[self.cpu mapObject:self.snd atPage:0xD8 count:0x08];
	[self.cpu mapObject:self.dma atPage:0xF8 count:0x08];
	[self.cpu mapObject:self.rom atPage:0xF8 count:0x08];

	self.ext.crt = self.crt;

	[self.crt setFontOffset:self.ext.B & 0x80 ? 0x2800 : 0x0C00];

	self.snd.channel2 = self.kbd.C & 0x04 ? TRUE : FALSE;

	[self.crt addAdjustment:[[MicroshaExtRAM alloc] initWithMicrosha:self]];

	[self.crt addAdjustment:[[Adjustment alloc] initWithTag:5
												   computer:self
													 setter:@selector(setColor:)
													 getter:@selector(isColor)]];

	[self setColor:[self isColor]];

	F81B *kbdHook; [self.cpu mapHook:kbdHook = [[F81B alloc] initWithRKKeyboard:self.kbd] atAddress:0xFEEA];
	[self.crt addAdjustment:kbdHook];

	F806 *inpHook; [self.cpu mapHook:inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xF806];
	inpHook.extension = @"rkm";
	inpHook.readError = 0xF8C7;
	[self.crt addAdjustment:inpHook];

	FCAB *outHook; [self.cpu mapHook:outHook = [[FCAB alloc] init] atAddress:0xFCAB];
	outHook.extension = @"rkm";
	[self.crt addAdjustment:outHook];

	return TRUE;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeBool:self.extRAM forKey:@"extRAM"];
	[super encodeWithCoder:encoder];
}


- (id) initWithCoder:(NSCoder *)decoder
{
	self.extRAM = [decoder decodeBoolForKey:@"extRAM"];
	return [super initWithCoder:decoder];
}

@end
