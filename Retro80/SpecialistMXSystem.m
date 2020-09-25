/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Системные регистры ПЭВМ «Специалист MX»

 *****/

#import "SpecialistMX.h"

// Системные регистры Специалист MX
@implementation SpecialistMXSystem

@synthesize specialist;

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	switch (addr & 0x1F)
	{
		case 0x10:    // D3.1 (pF0 - захват)

			specialist.fdd.HOLD = YES;
			break;

		case 0x11:    // D3.2 (pF1 - мотор)

			break;

		case 0x12:    // D4.2 (pF2 - сторона)

			if (specialist.fdd.selected == 0)
				specialist.fdd.selected = 1;

			specialist.fdd.head = data & 1;
			break;

		case 0x13:    // D4.1 (pF3 - дисковод)

			specialist.fdd.selected = (data & 1) + 1;
			break;

		case 0x18:    // Регистр цвета
		case 0x19:
		case 0x1A:
		case 0x1B:

			specialist.crt.color = data;
			break;

		case 0x1C:    // Выбрать RAM

			specialist.cpu.PAGE = 0;
			break;

		case 0x1D:    // Выбрать RAM-диск

			if (specialist.ram.length != 0x20000)
				specialist.ram.offset = ((data & 7) + 1) << 16;

			specialist.cpu.PAGE = 1;
			break;

		case 0x1E:    // Выбрать ROM-диск
		case 0x1F:

			specialist.cpu.PAGE = 2;
			break;
	}
}

- (void)RESET:(uint64_t)clock
{
	specialist.fdd.selected = 1;
}

#ifdef DEBUG
- (void)dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end

// Системные регистры Специалист MX2
@implementation SpecialistMX2System

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	switch (addr & 0x1F)
	{
		case 0x18:
		case 0x19:
		case 0x1A:
		case 0x1B:

			if ((self.specialist.cpu.PAGE & ~1) == 4)
			{
				self.specialist.kbd.colorScheme = data & 2 ? 2 : 1;
				self.specialist.cpu.PAGE = 4 | (data & 1);
				return;
			}

			break;

		case 0x1C:    // Выбрать RAM
		case 0x1D:    // Выбрать RAM-диск
		case 0x1E:    // Выбрать ROM-диск

			self.specialist.kbd.colorScheme |= 4;
			break;

		case 0x1F:    // Выбрать STD

			self.specialist.kbd.colorScheme &= 3;
			self.specialist.cpu.PAGE = 4;
			return;
	}

	[super WR:addr data:data CLK:clock];
}

- (void)RESET:(uint64_t)clock
{
	self.specialist.kbd.colorScheme |= 4;
	[super RESET:clock];
}

@end
