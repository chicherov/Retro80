/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Флеш диск для Специалист MX2

 *****/

#import "SpecialistMX2Flash.h"

@implementation SpecialistMX2Flash

- (uint8_t) A
{
	addr = ((C & 0x1F) << 16) | (addr & 0xFF00) | B;

	if (addr < rom.length)
		return ((const uint8_t *)rom.bytes)[addr];
	else
		return 0xFF;
}

- (void)setB:(uint8_t)data
{
}

- (void)setC:(uint8_t)data
{
	if ((data ^ C) & 0x20)
		addr = (addr & ~0xFF00) | (B << 8);
}

@end
