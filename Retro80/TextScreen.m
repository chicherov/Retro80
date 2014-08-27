#import "TextScreen.h"

@implementation TextScreen
{
	NSData *rom;

	NSObject<ReadWrite> *MEM[256];
	uint8_t memory[32][64];
	uint8_t screen[32][64];
	uint64_t CLK;
}

// -----------------------------------------------------------------------------

- (void) mapObject:(NSObject<ReadWrite> *)object atPage:(uint8_t)page
{
	MEM[page] = object;
}

// -----------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	uint8_t page = addr >> 8; if (MEM[page])
		return [MEM[page] RD:addr CLK:clock status:status];

	return status;
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	uint8_t page = addr >> 8; if (MEM[page])
		[MEM[page] WR:addr byte:data CLK:clock];

	uint8_t ch; if (addr & 0x800)
	{
		ch = (memory[0][addr & 0x7FF] & 0x80) | (data & 0x7F);
	}
	else
	{
		if (data)
			ch = memory[0][--addr & 0x7FF] | 0x80;
		else
			ch = memory[0][--addr & 0x7FF] & 0x7F;
	}

	if (memory[0][addr & 0x7FF] != ch)
	{
		memory[0][addr & 0x7FF] = ch;
	}
}

// -----------------------------------------------------------------------------

- (unsigned) HOLD:(uint64_t)clock
{
	if (CLK < clock)
	{
		self.needsDisplay = TRUE;
		CLK += 18000000/25;
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

			if (isSelected)
				if (row >= selected.origin.y && row < selected.origin.y + selected.size.height)
					if (col >= selected.origin.x && col < selected.origin.x + selected.size.width)
						ch ^= 0x80;

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

- (IBAction) copy:(id)sender
{
	if (isSelected)
	{
		uint8_t *buf = malloc(selected.size.height * (selected.size.width + 2)), *ptr = buf;

		for (unsigned y = selected.origin.y; y < selected.origin.y + selected.size.height; y++)
		{
			for (unsigned x = selected.origin.x; x < selected.origin.x + selected.size.width; x++)
			{
				*ptr = screen[y][x] & 0x7F;

				if (*ptr < 0x20 || *ptr >= 0x80) *ptr = 0x20;
				else if (*ptr >= 0x60) *ptr |= 0x80;

				ptr++;
			}

			if (selected.size.height > 1)
			{
				while (ptr > buf && ptr[-1] == ' ')
					ptr--;

				*ptr++ = '\n';
			}
		}

		NSString *string = [[NSString alloc] initWithBytes:buf
													length:ptr - buf
												  encoding:(NSStringEncoding) 0x80000A02];

		NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
		[pasteBoard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
		[pasteBoard setString:string forType:NSPasteboardTypeString];

		isSelected = FALSE;
	}

	else
	{
		[super copy:sender];
	}
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		if ((rom = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"TextScreen" ofType:@"fnt"]]) == nil)
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
