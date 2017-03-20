/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Микросхема параллельного интерфейса КР580ВВ55А (8255A)

 *****/

#import "x8255.h"

@implementation X8255

@synthesize computer;

- (void)setMode:(uint8_t)data
{
	mode.byte = data & 0x7F;

	A = self.A = 0x00;
	B = self.B = 0x00;
	C = self.C = 0x00;
}

- (uint8_t)mode
{
	return mode.byte;
}

- (void)setA:(uint8_t)data
{
}

- (uint8_t)A
{
	return 0xFF;
}

- (void)setB:(uint8_t)data
{
}

- (uint8_t)B
{
	return 0xFF;
}

- (void)setC:(uint8_t)data
{
}

- (uint8_t)C
{
	return 0xFF;
}

- (void)RESET:(uint64_t)clock
{
	self.mode = 0x1B;
}

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	switch (addr & 3)
	{
		case 0:

			*data = mode.A ? self.A : A;
			break;

		case 1:

			*data = mode.B ? self.B : B;
			break;

		case 2:

			if (mode.H)
			{
				if (mode.L)
					*data = self.C;
				else
					*data = (self.C & 0xF0) | (C & 0x0F);
			}
			else
			{
				if (mode.L)
					*data = (C & 0xF0) | (self.C & 0x0F);
				else
					*data = C;
			}

			break;

		case 3:

			*data = 0xFF;
			break;
	}
}

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	switch (addr & 3)
	{
		case 0:

			if (!mode.A)
				A = self.A = data;

			break;

		case 1:

			if (!mode.B)
				B = self.B = data;

			break;

		case 3:

			if ((data & 0x80) == 0x80)
			{
				self.mode = data;
				break;
			}
			else
			{
				uint8_t mask = 0x01 << ((data & 0x0E) >> 1);
				data = data & 1 ? C | mask : C & ~mask;
			}

		case 2:

			if (!mode.H && !mode.L)
				C = self.C = data;

			else if (!mode.H)
				C = self.C = data & 0xF0;

			else
				C = self.C = data & 0x0F;

			break;
	}
}

- (id)init
{
	if (self = [super init])
		[self RESET:0];

	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt:mode.byte forKey:@"mode"];
	[coder encodeInt:A forKey:@"A"];
	[coder encodeInt:B forKey:@"B"];
	[coder encodeInt:C forKey:@"C"];
}

- (id)initWithCoder:(NSCoder *)coder
{
	if (self = [super initWithCoder:coder])
	{
		mode.byte = [coder decodeIntForKey:@"mode"];
		A = [coder decodeIntForKey:@"A"];
		B = [coder decodeIntForKey:@"B"];
		C = [coder decodeIntForKey:@"C"];
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
