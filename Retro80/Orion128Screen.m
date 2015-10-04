/*******************************************************************************
 * Интерфейс графического экрана ПЭВМ «Орион-128»
 ******************************************************************************/

#import "Orion128Screen.h"

@implementation Orion128Screen
{
	uint32_t* bitmap;
	NSUInteger width;
}

@synthesize display;

@synthesize memory;
@synthesize color;
@synthesize page;

- (void) draw
{
	if (memory)
	{
		if (bitmap == NULL || (color & 0x04 && width != 384) || ((color & 0x06) == 0x02 && width != 400))
			bitmap = [self.display setupGraphicsWidth:width = ((color & 0x06) == 0x02 ? 400 : 384) height:256];

		if (color & 0x04)
		{
			if (color & 0x02)
			{
				for (uint16_t addr = 0x0000; addr < 0x3000; addr++)
				{
					uint32_t* ptr = bitmap + ((addr & 0xFF00) >> 5)  + (addr & 0xFF) * 384;
					uint8_t byte0 = memory[0x00000 + (page << 14) + addr];
					uint8_t byte1 = memory[0x10000 + (page << 14) + addr];

					uint32_t c0, c1;

					if (byte1 & 0x80)
						c0 = 0xFF555555 | (byte1 & 0x40 ? 0x000000FF : 0) | (byte1 & 0x20 ? 0x0000FF00 : 0) | (byte1 & 0x10 ? 0x00FF0000 : 0);
					else
						c0 = 0xFF000000 | (byte1 & 0x40 ? 0x000000AA : 0) | (byte1 & 0x20 ? 0x0000AA00 : 0) | (byte1 & 0x10 ? 0x00AA0000 : 0);

					if (byte1 & 0x08)
						c1 = 0xFF555555 | (byte1 & 0x04 ? 0x000000FF : 0) | (byte1 & 0x02 ? 0x0000FF00 : 0) | (byte1 & 0x01 ? 0x00FF0000 : 0);
					else
						c1 = 0xFF000000 | (byte1 & 0x04 ? 0x000000AA : 0) | (byte1 & 0x02 ? 0x0000AA00 : 0) | (byte1 & 0x01 ? 0x00AA0000 : 0);

					for (int i = 0; i < 8; i++)
						*ptr++ = byte0 & (0x80 >> i) ? c1 : c0;
				}
			}
			else
			{
				static uint32_t colors[2][2][2] =
				{
					0xFF000000, 0xFF00AA00, 0xFF0000AA, 0xFFAA0000,
					0xFFAA00AA, 0xFF0055AA, 0xFFAAAAAA, 0xFFAAAA00
				};

				for (uint16_t addr = 0x0000; addr < 0x3000; addr++)
				{
					uint32_t* ptr = bitmap + ((addr & 0xFF00) >> 5)  + (addr & 0xFF) * 384;
					uint8_t byte0 = memory[0x00000 + (page << 14) + addr];
					uint8_t byte1 = memory[0x10000 + (page << 14) + addr];

					for (uint8_t mask = 0x80; mask; mask >>= 1)
						*ptr++ = colors[color & 1][(byte1 & mask) != 0][(byte0 & mask) != 0];
				}
			}
		}
		else
		{
			uint32_t c0 = color & 0x02 ? 0xFF000000 : color & 0x01 ? 0xFFFFFF55 : 0xFF000000;
			uint32_t c1 = color & 0x02 ? 0xFF000000 : color & 0x01 ? 0xFF55FFFF : 0xFF00AA00;

			for (uint16_t addr = 0x0000; addr < width * 32; addr++)
			{
				uint32_t* ptr = bitmap + ((addr & 0xFF00) >> 5)  + (addr & 0xFF) * width;
				uint8_t byte = memory[(page << 14) + addr];

				for (uint8_t mask = 0x80; mask; mask >>= 1)
					*ptr++ = byte & mask ? c1 : c0;
			}
		}

		self.display.needsDisplay = TRUE;
	}
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:color forKey:@"color"];
	[encoder encodeInt:page forKey:@"page"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self init])
	{
		color = [decoder decodeIntForKey:@"color"];
		page = [decoder decodeIntForKey:@"page"];
	}

	return self;
}

// -----------------------------------------------------------------------------
// DEBUG: dealloc
// -----------------------------------------------------------------------------

#ifdef DEBUG
- (void) dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
