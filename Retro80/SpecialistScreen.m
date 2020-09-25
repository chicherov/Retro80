/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Интерфейс графического экрана ПЭВМ «Специалист»

 *****/

#import "SpecialistScreen.h"
#import "Display.h"

@implementation SpecialistScreen
{
	uint8_t colors[0x3000];

	uint32_t* bitmap;
}

@synthesize display;
@synthesize screen;

@synthesize isColor;
@synthesize color;

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	if (screen && addr & 0x3000)
	{
		addr = (addr & 0x3FFF) - 0x1000;
		colors[addr] = color;
		screen[addr] = data;
	}
}

- (void)draw
{
	if (screen)
	{
		if (bitmap == NULL)
			bitmap = [self.display setupGraphicsWidth:384 height:256];

		uint32_t c0 = 0xFF000000;
		uint32_t c1 = 0xFFAAAAAA;

		for (uint16_t addr = 0x0000; addr < 0x3000; addr++)
		{
			uint32_t *ptr = bitmap + ((addr & 0xFF00) >> 5) + (addr & 0xFF)*384;

			if (isColor)
			{
				uint8_t c = colors[addr];

				if (c & 0x80)
					c1 = 0xFF555555 | (c & 0x40 ? 0x000000FF : 0) | (c & 0x20 ? 0x0000FF00 : 0)
						| (c & 0x10 ? 0x00FF0000 : 0);
				else
					c1 = 0xFF000000 | (c & 0x40 ? 0x000000AA : 0) | (c & 0x20 ? 0x0000AA00 : 0)
						| (c & 0x10 ? 0x00AA0000 : 0);

				if (c & 0x08)
					c0 = 0xFF555555 | (c & 0x04 ? 0x000000FF : 0) | (c & 0x02 ? 0x0000FF00 : 0)
						| (c & 0x01 ? 0x00FF0000 : 0);
				else
					c0 = 0xFF000000 | (c & 0x04 ? 0x000000AA : 0) | (c & 0x02 ? 0x0000AA00 : 0)
						| (c & 0x01 ? 0x00AA0000 : 0);
			}

			for (int i = 0; i < 8; i++)
				*ptr++ = screen[addr] & (0x80 >> i) ? c1 : c0;
		}

		dispatch_async(dispatch_get_main_queue(), ^{
			[self.display setNeedsDisplay:YES];
		});
	}
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeBytes:colors length:sizeof(colors) forKey:@"colors"];

	[coder encodeBool:isColor forKey:@"isColor"];
	[coder encodeInt:color forKey:@"color"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if (self = [self init])
	{
		NSUInteger length;
		const void *ptr;

		if ((ptr = [coder decodeBytesForKey:@"colors" returnedLength:&length]) && length == sizeof(colors))
		{
			memcpy(colors, ptr, sizeof(colors));

			isColor = [coder decodeBoolForKey:@"isColor"];
			color = [coder decodeIntForKey:@"color"];
		}
		else
		{
			return self = nil;
		}
	}

	return self;
}

#ifdef DEBUG
- (void) dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
