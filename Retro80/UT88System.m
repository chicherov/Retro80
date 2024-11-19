/*****
 
 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>
 
 Интерфейс RAM диска и прерывания ПЭВМ «ЮТ-88»
 
 *****/

#import "UT88System.h"

@implementation UT88System
{
	NSUInteger offset;
	MEM *mem;
}

@synthesize cpu;

- (MEM *)RAMDISK:(RAM *)ram
{
	return mem = [ram memoryAtOffest:offset];
}

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	if ((data & 0x0F) == 0x0F)
		cpu.RAMDISK = 0;

	else
	{
		cpu.RAMDISK = 8;

		if ((data & 0x08) == 0x00)
			mem.offset = 0x40800;

		else if ((data & 0x04) == 0x00)
			mem.offset = 0x30800;

		else if ((data & 0x02) == 0x00)
			mem.offset = 0x20800;

		else if ((data & 0x01) == 0x00)
			mem.offset = 0x10800;
	}
}

- (void)RESET:(uint64_t)clock
{
	cpu.RAMDISK = 0;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if (self = [super init])
	{
		offset = [coder decodeIntegerForKey:@"offset"];
	}

	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInteger:mem.offset forKey:@"offset"];
}

@end
