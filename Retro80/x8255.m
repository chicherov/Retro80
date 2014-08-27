#import "x8255.h"

@implementation X8255

//------------------------------------------------------------------------------
// @property uint8_t mode
//------------------------------------------------------------------------------

- (void) setMode:(uint8_t)mode
{
	_mode.byte = mode & 0x3F;

	if (_mode.A == 1)
		_A = 0xFF;
	else
		self.A = 0x00;

	if (_mode.B == 1)
		_B = 0xFF;
	else
		self.B = 0x00;

	if (_mode.H == 1)
		_C |= 0xF0;
	else
		self.C = _C & 0x0F;

	if (_mode.L == 1)
		_C |= 0x0F;
	else
		self.C = _C & 0xF0;
}

- (uint8_t) mode
{
	return _mode.byte;
}

//------------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	switch (addr & 3)
	{
		case 0:

			return self.A;

		case 1:

			return self.B;

		case 2:

			return self.C;
	}

	return 0xFF;
}

//------------------------------------------------------------------------------

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	switch (addr & 3)
	{
		case 0:

			if (_mode.A == 0)
				self.A = data;

			break;

		case 1:

			if (_mode.B == 0)
				self.B = data;

			break;

		case 2:

			if (_mode.H == 0 && _mode.L == 0)
			{
				self.C = data;
			}

			else if (_mode.H == 0)
			{
				self.C = (data & 0xF0) | (_C & 0x0F);
			}

			else if (_mode.L == 0)
			{
				self.C = (_C & 0xF0) | (data & 0x0F);
			}

			break;

		case 3:

			if ((data & 0x80) == 0x00)
			{
				switch (data & 0x0E)
				{
					case 0x00:

						if (_mode.L == 0)
							self.C = (_C & ~0x01) | ((data & 0x01) << 0);

						break;

					case 0x02:

						if (_mode.L == 0)
							self.C = (_C & ~0x02) | ((data & 0x01) << 1);

						break;

					case 0x04:

						if (_mode.L == 0)
							self.C = (_C & ~0x04) | ((data & 0x01) << 2);

						break;


					case 0x06:

						if (_mode.L == 0)
							self.C = (_C & ~0x08) | ((data & 0x01) << 3);

						break;


					case 0x08:

						if (_mode.H == 0)
							self.C = (_C & ~0x10) | ((data & 0x01) << 4);

						break;

					case 0x0A:

						if (_mode.H == 0)
							self.C = (_C & ~0x20) | ((data & 0x01) << 5);

						break;

					case 0x0C:

						if (_mode.H == 0)
							self.C = (_C & ~0x40) | ((data & 0x01) << 6);

						break;

					case 0x0E:

						if (_mode.H == 0)
							self.C = (_C & ~0x80) | ((data & 0x01) << 7);

						break;
				}
			}

			else
			{
				self.mode = data;
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
		_mode.A = 1;
		_A = 0xFF;

		_mode.B = 1;
		_B = 0xFF;

		_mode.H = 1;
		_mode.L = 1;
		_C = 0xFF;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:_mode.byte forKey:@"mode"];
	[encoder encodeInt:_A forKey:@"A"];
	[encoder encodeInt:_B forKey:@"B"];
	[encoder encodeInt:_C forKey:@"C"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self init])
	{
		_mode.byte = [decoder decodeIntForKey:@"mode"];
		_A = [decoder decodeIntForKey:@"A"];
		_B = [decoder decodeIntForKey:@"B"];
		_C = [decoder decodeIntForKey:@"C"];
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
