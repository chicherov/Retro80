/*******************************************************************************
 Микросхема трехканального таймера КР580ВИ53 (8253)
 ******************************************************************************/

#import "X8253.h"

@implementation X8253

// -----------------------------------------------------------------------------

- (SInt8) sample:(uint64_t)clock
{
	SInt8 sample = 0; for (int i = 0; i < 3; i++)
	{
		if (((i == 0 && _channel0) || (i == 1 && _channel1) || (i == 2 && _channel2)) && timer[i].CLK && timer[i].mode.MODE == 3 && timer[i].count > 40)
			sample += (timer[i].count - clock / 9 % timer[i].count) > (timer[i].count >> 1) ? 20 : -20;
	}

	return sample;
}

// -----------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	addr &= 3; if (addr == 3)
		return status;

	uint16_t value; if (timer[addr].bLatch)
	{
		timer[addr].bLatch = timer[addr].bRLow && timer[addr].mode.RL == 3;

		value = timer[addr].latch;
	}

	else
	{
		value = timer[addr].count; if (timer[addr].CLK)
		{
			switch (timer[addr].mode.MODE)
			{
				case 0:

					value -= ((clock - timer[addr].CLK) / 9) & 0xFFFF;
					break;

				case 1:

					break;

				case 2:
				case 4:

					if (value)
						value -= ((clock - timer[addr].CLK) / 9) % value;
					else
						value -= ((clock - timer[addr].CLK) / 9) & 0xFFFF;

					break;

				case 3:

					if (value)
						value -= (clock - timer[addr].CLK) / 9 * 2 % value;
					else
						value -= (clock - timer[addr].CLK) / 9 * 2 & 0xFFFF;

					break;

				case 5:

					break;
			}
		}
	}

	if (timer[addr].bRLow)
	{
		if (timer[addr].mode.RL == 3)
			timer[addr].bRLow = FALSE;

		return value & 0xFF;
	}
	else
	{
		if (timer[addr].mode.RL == 3)
			timer[addr].bRLow = TRUE;

		return value >> 8;
	}
}

// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	addr &= 3; if (addr == 3)
	{
		union i8253_mode mode; mode.byte = data;
		if (mode.SC == 3) return;

		if (mode.RL == 0)
		{
			timer[mode.SC].latch = timer[addr].count; if (timer[addr].CLK)
			{
				if (timer[addr].count)
					timer[mode.SC].latch -= ((clock - timer[addr].CLK) / 9) % timer[addr].count;
				else
					timer[mode.SC].latch -= ((clock - timer[addr].CLK) / 9) & 0xFFFF;
			}

			timer[mode.SC].bRLow = timer[mode.SC].mode.RL != 2;
			timer[mode.SC].bLatch = TRUE;
		}
		else
		{
			if (timer[mode.SC].CLK)
			{
				if (timer[mode.SC].count)
					timer[mode.SC].count -= ((clock - timer[mode.SC].CLK) / 9) % timer[mode.SC].count;
				else
					timer[mode.SC].count -= ((clock - timer[mode.SC].CLK) / 9) & 0xFFFF;
			}

			if ((mode.MODE & 0x02) == 0x02)
				mode.MODE &= 0x03;

			timer[mode.SC].mode.byte = mode.byte;

			timer[mode.SC].CLK = 0;

			timer[mode.SC].bWLow = mode.RL != 2;
			timer[mode.SC].bRLow = mode.RL != 2;
			timer[mode.SC].bLatch = FALSE;
		}
	}
	else
	{
		if (timer[addr].bWLow)
		{
			if (timer[addr].mode.RL != 3)
			{
				timer[addr].CLK = clock + 18;
				timer[addr].count = data;
			}
			else
			{
				timer[addr].bWLow = FALSE;
				timer[addr].load = data;
			}
		}
		else
		{
			timer[addr].count = (data << 8);
			timer[addr].CLK = clock + 18;

			if (timer[addr].mode.RL == 3)
			{
				timer[addr].count |= timer[addr].load;
				timer[addr].bWLow = TRUE;
			}
		}
	}
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		timer[0].CLK = timer[1].CLK = timer[2].CLK = random() | 0xFFFFFFFFFFFF0000;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeBytes:&timer length:sizeof(timer)];

	[encoder encodeBool:_channel0 forKey:@"channel0"];
	[encoder encodeBool:_channel1 forKey:@"channel1"];
	[encoder encodeBool:_channel2 forKey:@"channel2"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super init])
	{
		NSUInteger length; const void *ptr = [decoder decodeBytesWithReturnedLength:&length];

		if (length == sizeof(timer))
			memcpy(timer, ptr, sizeof(timer));
		else
			return self = nil;

		_channel0 = [decoder decodeBoolForKey:@"channel0"];
		_channel1 = [decoder decodeBoolForKey:@"channel1"];
		_channel2 = [decoder decodeBoolForKey:@"channel2"];
	}

	return self;
}

@end
