/*******************************************************************************
 * Интерфейс графического экрана ПЭВМ «Специалист»
 ******************************************************************************/

#import "SpecialistScreen.h"

@implementation SpecialistScreen
{
	uint8_t colors[0x3000];

	uint32_t* bitmap;
	uint32_t color0;
	uint32_t color1;
}

@synthesize display;
@synthesize screen;

@synthesize isColor;
@synthesize color;


// -----------------------------------------------------------------------------
// @protocol WR
// -----------------------------------------------------------------------------

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
// draw
// -----------------------------------------------------------------------------

- (void) draw
{
	if (bitmap == NULL)
	{
		if ((bitmap = [self.display setupGraphicsWidth:384 height:256]))
		{
			uint8_t c = color; for (uint16_t addr = 0x0000; addr < 0x3000; addr++)
			{
				uint32_t* ptr = bitmap + ((addr & 0x3F00) >> 5) + (addr & 0xFF) * 384;

				[self setColor:colors[addr]];

				for (int i = 0; i < 8; i++)
					*ptr++ = screen[addr] & (0x80 >> i) ? color1 : color0;
			}

			[self setColor:c];
		}
	}

	self.display.needsDisplay = TRUE;
}

// -----------------------------------------------------------------------------
// @property BOOL isColor;
// -----------------------------------------------------------------------------

- (void) setIsColor:(BOOL)setIsColor
{
	if (!(isColor = setIsColor))
	{
		color0 = 0xFF000000;
		color1 = 0xFFAAAAAA;
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
// @property uint8_t color;
// -----------------------------------------------------------------------------

- (void) setColor:(uint8_t)setColor
{
	color = setColor; if (isColor)
	{
		if (color & 0x80)
			color1 = 0xFF000000 | (color & 0x40 ? 0x000000FF : 0) | (color & 0x20 ? 0x0000FF00 : 0) | (color & 0x10 ? 0x00FF0000 : 0);
		else
			color1 = 0xFF000000 | (color & 0x40 ? 0x000000AA : 0) | (color & 0x20 ? 0x0000AA00 : 0) | (color & 0x10 ? 0x00AA0000 : 0);

		if (color & 0x08)
			color0 = 0xFF000000 | (color & 0x04 ? 0x000000FF : 0) | (color & 0x02 ? 0x0000FF00 : 0) | (color & 0x01 ? 0x00FF0000 : 0);
		else
			color0 = 0xFF000000 | (color & 0x04 ? 0x000000AA : 0) | (color & 0x02 ? 0x0000AA00 : 0) | (color & 0x01 ? 0x00AA0000 : 0);
	}
}

- (uint8_t) color
{
	return color;
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
		self.isColor = FALSE;

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeBytes:colors length:sizeof(colors) forKey:@"colors"];

	[encoder encodeBool:isColor forKey:@"isColor"];
	[encoder encodeInt:color forKey:@"color"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self init])
	{
		NSUInteger length; const void *ptr;

		if ((ptr = [decoder decodeBytesForKey:@"colors" returnedLength:&length]) && length == sizeof(colors))
		{
			memcpy(colors, ptr, sizeof(colors));

			self.isColor = [decoder decodeBoolForKey:@"isColor"];
			color = [decoder decodeIntForKey:@"color"];
		}
		else
		{
			return self = nil;
		}
	}
	
	return self;
}

@end

