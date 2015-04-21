/*******************************************************************************
 Микросхема параллельного интерфейса КР580ВВ55А (8255A)
 ******************************************************************************/

#import "x8255.h"

@implementation X8255

//------------------------------------------------------------------------------
// @property uint8_t mode
//------------------------------------------------------------------------------

- (void) setMode:(uint8_t)data
{
	mode.byte = data & 0x7F;

#ifdef DEBUG
	if (mode.GA)
		NSLog(@"Group A mode: %d", mode.GA);
	if (mode.GB)
		NSLog(@"Group B mode: %d", mode.GB);
#endif

	A = self.A = 0x00;
	B = self.B = 0x00;
	C = self.C = 0x00;
}

- (uint8_t) mode
{
	return mode.byte;
}

//------------------------------------------------------------------------------
// @property uint8_t A
//------------------------------------------------------------------------------

- (void) setA:(uint8_t)data
{
}

- (uint8_t) A
{
	return 0xFF;
}

//------------------------------------------------------------------------------
// @property uint8_t B
//------------------------------------------------------------------------------

- (void) setB:(uint8_t)data
{
}

- (uint8_t) B
{
	return 0xFF;
}

//------------------------------------------------------------------------------
// @property uint8_t C
//------------------------------------------------------------------------------

- (void) setC:(uint8_t)data
{
}

- (uint8_t) C
{
	return 0xFF;
}

//------------------------------------------------------------------------------
// RESET/RD/WR
//------------------------------------------------------------------------------

- (void) RESET
{
	self.mode = 0x1B;
}

//------------------------------------------------------------------------------

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	current = clock; switch (addr & 3)
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

//------------------------------------------------------------------------------

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	current = clock; switch (addr & 3)
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
			{
				C = self.C = data;
			}

			else if (!mode.H)
			{
				C = self.C = data & 0xF0;
			}

			else
			{
				C = self.C = data & 0x0F;
			}

			break;

	}
}

//------------------------------------------------------------------------------
// Инициализация
//------------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		[self RESET];
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:mode.byte forKey:@"mode"];
	[encoder encodeInt:A forKey:@"A"];
	[encoder encodeInt:B forKey:@"B"];
	[encoder encodeInt:C forKey:@"C"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self init])
	{
		mode.byte = [decoder decodeIntForKey:@"mode"];
		A = [decoder decodeIntForKey:@"A"];
		B = [decoder decodeIntForKey:@"B"];
		C = [decoder decodeIntForKey:@"C"];
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
