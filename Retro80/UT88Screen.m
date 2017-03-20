/*****
 
 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>
 
 Контроллер дисплея ПЭВМ «ЮТ-88» и lcd
 
 *****/

#import "UT88Screen.h"

@implementation UT88Screen
{
	uint8_t segments[6];
}

- (void)setDisplay:(Display *)display
{
	display.digit1.hidden = FALSE;
	display.digit1.segments = segments[0];
	display.digit2.hidden = FALSE;
	display.digit2.segments = segments[1];
	display.digit3.hidden = FALSE;
	display.digit3.segments = segments[2];
	display.digit4.hidden = FALSE;
	display.digit4.segments = segments[3];
	display.digit5.hidden = FALSE;
	display.digit5.segments = segments[4];
	display.digit6.hidden = FALSE;
	display.digit6.segments = segments[5];

	[super setDisplay:display];
}

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	if (addr >= 0x9000 && addr <= 0x9FFF)
	{
		if (*pMutableBytes != mutableBytes && offset + (addr & mask) < *pLength)
			(*pMutableBytes)[offset + (addr & mask)] = data;

		static uint8_t lcd_mask[] = {
			0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71
		};

		if ((addr & 3) == 0)
		{
			segments[4] = self.display.digit5.segments = lcd_mask[data >> 4];
			segments[5] = self.display.digit6.segments = lcd_mask[data & 15];
		}

		if ((addr & 3) == 1)
		{
			segments[2] = self.display.digit3.segments = lcd_mask[data >> 4];
			segments[3] = self.display.digit4.segments = lcd_mask[data & 15];
		}

		if ((addr & 2) == 2)
		{
			segments[0] = self.display.digit1.segments = lcd_mask[data >> 4];
			segments[1] = self.display.digit2.segments = lcd_mask[data & 15];
		}
	}

	else
	{
		mutableBytes[addr & 0x7FF] = data;
	}
}

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	*data = mutableBytes[addr & 0x7FF];
}

- (instancetype)init
{
	if (self = [super init])
	{
		segments[0] = 0x71;
		segments[1] = 0x71;
		segments[2] = 0x71;
		segments[3] = 0x71;
		segments[4] = 0x71;
		segments[5] = 0x71;
	}

	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if (self = [super initWithCoder:coder])
		[coder decodeValueOfObjCType:@encode(uint8_t[6]) at:&segments];

	return self;
}

// -----------------------------------------------------------------------------

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
	[coder encodeValueOfObjCType:@encode(uint8_t[6]) at:&segments];
}

@end
