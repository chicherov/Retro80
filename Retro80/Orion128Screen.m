/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Интерфейс графического экрана ПЭВМ «Орион-128»

 *****/

#import "Orion128Screen.h"
#import "Display.h"

@implementation Orion128Screen
{
	uint32_t *bitmap;
	NSUInteger width;
	uint64_t IRQ;
}

@synthesize display;

@synthesize pMemory;
@synthesize color;
@synthesize page;

@synthesize IE;

- (void)draw
{
	if (pMemory)
	{
		if (bitmap == NULL || (page & 0x80 ? width != 480 : width == 480) || (color & 0x04 && width == 400) || ((color & 0x06) == 0x02 && width == 384))
				bitmap = [self.display setupGraphicsWidth:width = (page & 0x80 ? 480 : (color & 0x06) == 0x02 ? 400 : 384) height:256];

		const uint8_t *mem = *pMemory + ((~page & 0x03) << 14);

		if (color & 0x04)
		{
			if (color & 0x02)
			{
				for (uint16_t addr = 0x0000; addr < width * 32; addr++)
				{
					uint32_t* ptr = bitmap + ((addr & 0xFF00) >> 5)  + (addr & 0xFF) * width;
					uint8_t byte0 = mem[addr], byte1 = mem[addr + 0x10000];

					uint32_t c0, c1;

					if (byte1 & 0x80)
						c0 = 0xFF000000 | (byte1 & 0x40 ? 0x000000FF : 0) | (byte1 & 0x20 ? 0x0000FF00 : 0) | (byte1 & 0x10 ? 0x00FF0000 : 0);
					else
						c0 = 0xFF000000 | (byte1 & 0x40 ? 0x000000AA : 0) | (byte1 & 0x20 ? 0x0000AA00 : 0) | (byte1 & 0x10 ? 0x00AA0000 : 0);

					if (byte1 & 0x08)
						c1 = 0xFF000000 | (byte1 & 0x04 ? 0x000000FF : 0) | (byte1 & 0x02 ? 0x0000FF00 : 0) | (byte1 & 0x01 ? 0x00FF0000 : 0);
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
						{{0xFF000000, 0xFF00AA00}, {0xFF0000AA, 0xFFAA0000}},
						{{0xFFAAAA00, 0xFF00AAAA}, {0xFFAAAAAA, 0xFFAA00AA}}
				};

				for (uint16_t addr = 0x0000; addr < width * 32; addr++)
				{
					uint32_t* ptr = bitmap + ((addr & 0xFF00) >> 5)  + (addr & 0xFF) * width;
					uint8_t byte0 = mem[addr], byte1 = mem[addr + 0x10000];

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
				uint8_t byte = mem[addr];

				for (uint8_t mask = 0x80; mask; mask >>= 1)
					*ptr++ = byte & mask ? c1 : c0;
			}
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			[self.display setNeedsDisplay:YES];
		});
	}
}

- (void)RESET:(uint64_t)clock
{
	bitmap = NULL;
	color = 0x00;
	page = 0x00;

	IE = NO;
}

- (BOOL)IRQ:(uint64_t)clock
{
	if (IRQ <= clock)
	{
		IRQ += 900000;
		return IE;
	}

	return NO;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:color forKey:@"color"];
	[encoder encodeInt:page forKey:@"page"];

	[encoder encodeInt64:IRQ forKey:@"IRQ"];
	[encoder encodeBool:IE forKey:@"IE"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if (self = [super init])
	{
		color = [decoder decodeIntForKey:@"color"];
		page = [decoder decodeIntForKey:@"page"];

		IRQ = [decoder decodeInt64ForKey:@"IRQ"];
		IE = [decoder decodeBoolForKey:@"IE"];
	}

	return self;
}

#ifdef DEBUG
- (void)dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
