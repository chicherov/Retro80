#import "TextScreen.h"

@implementation TextScreen
{
	NSData *rom;

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
		frame++; CLK += 18000000/25;
		self.needsDisplay = TRUE;
	}

	return 0;
}

// -----------------------------------------------------------------------------

- (void)drawRect:(NSRect)rect
{
	for (unsigned row = 0; row < 32; row++)
	{
		for (unsigned col = 0; col < 64; col++)
		{
			uint8_t ch =  memory[row][col];

			if (screen[row][col] != ch)
			{
				screen[row][col] = ch;

				const uint8_t *fnt = rom.bytes + ((ch & 0x7F) << 3);
				uint32_t *ptr = bitmap + row * 3072 + col * 6;

				for (int line = 0; line < 8; line++)
				{
					uint8_t byte = *fnt++; if (ch & 0x80)
						byte ^= 0xFF;

					for (int i = 0; i < 6; i++, byte <<= 1)
						*ptr++ = byte & 0x20 ? 0xFF000000 : 0xFFFFFFFF;

					ptr += 63 * 6;
				}
			}
		}
	}

	[super drawRect:rect];
}

// -----------------------------------------------------------------------------
// Copy to pasteboard
// -----------------------------------------------------------------------------

- (uint8_t) byteAtX:(NSUInteger)x y:(NSUInteger)y
{
	return screen[y][x] & 0x7F;
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

		[self setupTextWidth:64 height:32 cx:6 cy:8];

		text.height = 32;
		text.width = 64;
		isText = TRUE;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeBytes:memory length:sizeof(memory)];
	[encoder encodeInt64:CLK forKey:@"CLK"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self init])
	{
		NSUInteger length; void *ptr = [decoder decodeBytesWithReturnedLength:&length];

		if (ptr == NULL || length != sizeof(memory))
			return self = nil;

		memcpy(memory, ptr, length);

		CLK = [decoder decodeInt64ForKey:@"CLK"];
	}

	return self;
}

@end
