#import "TextScreen.h"

@implementation TextScreen
{
	NSData *rom;

	uint32_t* bitmap;

	uint8_t memory[32][64];
	uint8_t screen[32][64];
	uint64_t CLK;
}

@synthesize WR;

// -----------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	return status;
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	[WR WR:addr byte:data CLK:clock];

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

- (unsigned) HLDA:(uint64_t)clock WR:(BOOL)wr
{
	if (CLK < clock)
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
		CLK += 18000000/25;
	}

	return 0;
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
	[encoder encodeInt64:CLK forKey:@"CLK"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self init])
	{
		[decoder decodeValueOfObjCType:"[2048c]" at:memory];
		CLK = [decoder decodeInt64ForKey:@"CLK"];
	}

	return self;
}

@end
