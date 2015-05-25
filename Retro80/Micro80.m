/*******************************************************************************
 ПЭВМ «Микро-80»
 ******************************************************************************/

#import "Micro80.h"

@implementation Micro80

+ (NSString *) title
{
	return @"Микро-80";
}

+ (NSArray *) extensions
{
	return @[@"rk8"];
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if ((self.cpu = [[X8080 alloc] initWithQuartz:18000000 start:0xF800]) == nil)
		return FALSE;

	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Micro80" mask:0x07FF]) == nil)
		return FALSE;

	if ((self.ram = [[RAM alloc] initWithLength:0xF800 mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.crt = [[Micro80Screen alloc] init]) == nil)
		return FALSE;

	if ((self.kbd = [[Micro80Keyboard alloc] init]) == nil)
		return FALSE;

	return TRUE;
}

- (BOOL) mapObjects
{
	if ((self.snd = [[Micro80Recorder alloc] init]) == nil)
		return FALSE;

	self.crt.WR = self.ram;

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

		self.outHook.extension = @"rk8";
	}

	[self.cpu mapObject:self.ram from:0x0000 to:0xDFFF];
	[self.cpu mapObject:self.crt from:0xE000 to:0xEFFF RD:self.ram];
	[self.cpu mapObject:self.ram from:0xF000 to:0xF7FF];
	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF WR:nil];

	[self.cpu mapObject:self.inpHook from:0xFD95 to:0xFD95 WR:nil];
	[self.cpu mapObject:self.outHook from:0xFDE6 to:0xFDE6 WR:nil];

	[self.cpu mapObject:self.snd atPort:0x00 count:0x02];
	[self.cpu mapObject:self.kbd atPort:0x04 count:0x04];

	return TRUE;
}

- (id) init
{
	if (self = [super init])
	{
		if (![self createObjects])
			return self = nil;

		if (![self mapObjects])
			return self = nil;

		self.inpHook.enabled = TRUE;
		self.outHook.enabled = TRUE;
	}

	return self;
}

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	if (self = [self init])
	{
		self.inpHook.buffer = data;
		[self.kbd paste:@"I\n"];
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

		if (![self mapObjects])
			return self = nil;

		self.inpHook.enabled = [decoder decodeBoolForKey:@"inpHook"];
		self.outHook.enabled = [decoder decodeBoolForKey:@"outHook"];
	}
	
	return self;
}

@end

// -----------------------------------------------------------------------------
// Дисплей "Микро-80"
// -----------------------------------------------------------------------------

@implementation Micro80Screen
{
	NSData *rom;

	uint32_t* bitmap;

	uint8_t memory[32][64];
	uint8_t screen[32][64];
}

@synthesize display;
@synthesize WR;

// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	[WR WR:addr data:data CLK:clock];

	uint8_t ch; if (addr & 0x800)
	{
		ch = (memory[0][addr & 0x7FF] & 0x80) | (data & 0x7F);
	}
	else
	{
		if (data & 0x80)
			ch = memory[0][--addr & 0x7FF] | 0x80;
		else
			ch = memory[0][--addr & 0x7FF] & 0x7F;
	}

	if (memory[0][addr & 0x7FF] != ch)
		memory[0][addr & 0x7FF] = ch;
}

// -----------------------------------------------------------------------------

- (void) draw
{
	for (unsigned row = 0; row < 32; row++)
	{
		for (unsigned col = 0; col < 64; col++)
		{
			uint8_t ch =  memory[row][col];

			if (screen[row][col] != ch)
			{
				if (bitmap == NULL)
					bitmap = [self.display setupTextWidth:64 height:32 cx:6 cy:8];

				if (bitmap)
				{
					screen[row][col] = ch;

					const uint8_t *fnt = rom.bytes + ((ch & 0x7F) << 3);
					uint32_t *ptr = bitmap + (row * 64 * 8 + col) * 6;

					for (int line = 0; line < 8; line++)
					{
						uint8_t byte = *fnt++; if (ch & 0x80)
							byte ^= 0xFF;

						for (int i = 0; i < 6; i++, byte <<= 1)
							*ptr++ = byte & 0x20 ? 0xFF000000 : 0xFFAAAAAA;

						ptr += 63 * 6;
					}
				}
			}
		}
	}

	self.display.needsDisplay = TRUE;
}

// -----------------------------------------------------------------------------
// Copy to pasteboard
// -----------------------------------------------------------------------------

- (unichar) charAtX:(unsigned int)x Y:(unsigned int)y
{
	NSString *unicode = @
	" ▘▝▀▗▚▐▜ ⌘ ⬆  ➡⬇▖▌▞▛▄▙▟█   ┃━⬅☼ "
	" !\"#$%&'()*+,-./0123456789:;<=>?"
	"@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
	"ЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧ▇";


	return [unicode characterAtIndex:screen[y][x] & 0x7F];
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		if ((rom = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Micro80" ofType:@"fnt"]]) == nil)
			return self = nil;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeValueOfObjCType:"[2048c]" at:memory];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self init])
	{
		[decoder decodeValueOfObjCType:"[2048c]" at:memory];
	}
	
	return self;
}

@end

// -----------------------------------------------------------------------------
// Интерфейс сопряжения "Микро-80"
// -----------------------------------------------------------------------------

@implementation Micro80Recorder

@synthesize sound;

- (SInt8) sample:(uint64_t)clock
{
	return 0;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	*data = sound.input;
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	sound.output = data != 0x00;
}

@end

// -----------------------------------------------------------------------------
// Интерфейс клавиатуры "Микро-80"
// -----------------------------------------------------------------------------

@implementation Micro80Keyboard

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	[super RD:addr ^ 3 data:data CLK:clock];
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	[super WR:addr ^ 3 data:data CLK:clock];
}

// -----------------------------------------------------------------------------
// Порт C
// -----------------------------------------------------------------------------

- (uint8_t) C
{
	[self scan:current];

	uint8_t data = 0xFF & ~(RUSLAT | CTRL | SHIFT);

	if (!(modifierFlags & NSAlphaShiftKeyMask))
		data |= RUSLAT;

	if (!(modifierFlags & NSControlKeyMask))
		data |= CTRL;

	if (!(modifierFlags & NSShiftKeyMask))
		data |= SHIFT;

	else if (self.qwerty) for (int i = 8; i < 48; i++)
	{
		if (i != 40 && i != 41 && keyboard[i])
		{
			data &= ~RUSLAT; data |= SHIFT; break;
		}
	}

	memset(keyboard, 0x00, sizeof(keyboard));
	return data;
}

- (void) setC:(uint8_t)data
{
}

- (id) init
{
	if (self = [super init])
	{
		kbdmap = @[
				   // 18 08    19    1A    0D    1F    0C    ?
				   @124, @123, @126, @125, @36,  @117, @115, @-1,
				   // 5A 5B    5C    5D    5E    5F    20    ?
				   @35,  @34,  @39,  @31,  @7,   @51,  @49,  @-1,
				   // 53 54    55    56    57    58    59    ?
				   @8,   @45,  @14,  @41,  @2,   @46,  @1,   @-1,
				   // 4C 4D    4E    4F    50    51    52    ?
				   @40,  @9,   @16,  @38,  @5,   @6,   @4,   @-1,
				   // 45 46    47    48    49    4A    4B    ?
				   @17,  @0,   @32,  @33,  @11,  @12,  @15,  @-1,
				   // 2E 2F    40    41    42    43    44    ?
				   @42,  @50,  @47,  @3,   @43,  @13,  @37,  @-1,
				   // 37 38    39    3A    3B    2C    2D    ?
				   @26,  @28,  @25,  @30,  @10,  @44,  @27,  @-1,
				   // 30 31    32    33    34    35    36    ?
				   @29,  @18,  @19,  @20,  @21,  @23,  @22,  @-1
				   ];

		chr1Map =  @"\r\0Z[\\]^_ \0STUVWXY\0LMNOPQR\0EFGHIJK\0./@ABCD\0""789:;,-\0""0123456\0";
		chr2Map =  @"\r\0ЗШЭЩЧ\0 \0СТУЖВЬЫ\0ЛМНОПЯР\0ЕФГХИЙК\0>?ЮАБЦД\0'()*+<=\0""0!\"#$%&\0";

		RUSLAT = 0x01;
		SHIFT = 0x04;
		CTRL = 0x02;
	}

	return self;
}

@end
