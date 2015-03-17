/*******************************************************************************
 Микросхема трехканального таймера КР580ВИ53 (8253)
 ******************************************************************************/

#import "X8253.h"

@implementation X8253

@synthesize sound;

// -----------------------------------------------------------------------------

uint64_t getTimerClock(struct i8253_timer* timer, uint64_t clock)
{
	if (timer->started && timer->div)
	{
		if (timer->gated && timer->gated <= clock)
		{
			if (timer->period && clock - timer->gated >= timer->active)
			{
				uint64_t lastPeriod = (clock - timer->gated) % timer->period;

				if ((timer->mode.MODE & 0x02) != 0x02)
				{
					return timer->clock + ((timer->gated > timer->started ? timer->gated - timer->started - 1 : 0) + (clock - timer->gated) / timer->period * (timer->period - timer->active) + (lastPeriod < timer->active ? 0 : lastPeriod - timer->active)) / timer->div;
				}
				else
				{
					return ((lastPeriod < timer->active ? timer->period : lastPeriod) - timer->active) / timer->div;
				}
			}
			else
			{
				return timer->clock + (timer->gated > timer->started ? timer->gated - timer->started - 1 : 0) / timer->div;
			}
		}
		else
		{
			return timer->clock + (clock - timer->started) / timer->div;
		}
	}
	else
	{
		return timer->clock;
	}
}

// -----------------------------------------------------------------------------

uint16_t getTimerCount(struct i8253_timer *timer, uint64_t clock)
{
	if (timer->started) switch (timer->mode.MODE)
	{
		case 0:
		{
			if (timer->mode.BCD)
				return (10000 - getTimerClock(timer, clock) % 10000 + timer->count) % 10000;
			else
				return timer->count - getTimerClock(timer, clock);
		}

		case 1:
		{
			return 0;
		}

		case 2:
		{
			unsigned count = timer->count ? timer->count : timer->mode.BCD ? 10000 : 0x10000;
			return count - 1 - getTimerClock(timer, clock) % count;
		}

		case 3:
		{
			unsigned count = timer->count ? timer->count : timer->mode.BCD ? 10000 : 0x10000;
			return (count - 1 - getTimerClock(timer, clock) * 2 % count) & ~1;
		}

		case 4:
		{
			return 0;
		}

		case 5:
		{
			return 0;
		}
	}

	return timer->count;
}

// -----------------------------------------------------------------------------

void updateTimer(struct i8253_timer *timer, uint64_t clock)
{
	while (timer && (timer->gate || timer->clk))
	{
		if (timer->gate)
		{
			if (timer->gate->started)
			{
				timer->gate->clock = getTimerClock(timer->gate, clock - 9);
				timer->gate->started = clock - 9;
			}

			switch (timer->mode.MODE)
			{
				case 0:

					if (timer->started && timer->div)
					{
						if (getTimerClock(timer, clock) < timer->count)
							timer->gate->gated = clock + (timer->count - getTimerClock(timer, clock)) * timer->div;
						else
							timer->gate->gated = clock;
					}
					else
						timer->gate->gated = 0;

					timer->gate->period = 0;
					timer->gate->active = 0;
					break;

				case 2:

					if (timer->started && timer->div)
					{
						if (timer->count)
						{
							timer->gate->gated = clock - (getTimerClock(timer, clock) % timer->count) * timer->div;
							timer->gate->period = timer->count * timer->div;
						}
						else if (timer->mode.BCD)
						{
							timer->gate->gated = clock - (getTimerClock(timer, clock) % 10000) * timer->div;
							timer->gate->period = 10000 * timer->div;
						}
						else
						{
							timer->gate->gated = clock - (getTimerClock(timer, clock) & 0xFFFF) * timer->div;
							timer->gate->period = 0x10000 * timer->div;
						}

						timer->gate->active = timer->gate->period - timer->div;
					}

					else
					{
						timer->gate->gated = clock;
						timer->gate->period = 0;
						timer->gate->active = 0;
					}

					break;

				case 3:

					if (timer->started && timer->div)
					{
						if (timer->count)
						{
							timer->gate->gated = clock - (getTimerClock(timer, clock) % timer->count) * timer->div;
							timer->gate->period = timer->count * timer->div;
							timer->gate->active = (timer->count + 1) / 2 * timer->div;
						}
						else if (timer->mode.BCD)
						{
							timer->gate->gated = clock - (getTimerClock(timer, clock) % 10000) * timer->div;
							timer->gate->period = 10000 * timer->div;
							timer->gate->active = 5000 * timer->div;
						}
						else
						{
							timer->gate->gated = clock - (getTimerClock(timer, clock) & 0xFFFF) * timer->div;
							timer->gate->period = 0x10000 * timer->div;
							timer->gate->active = 0x8000 * timer->div;
						}
					}

					else
					{
						timer->gate->gated = clock;
						timer->gate->period = 0;
						timer->gate->active = 0;
					}

					break;

				default:

					timer->gate->gated = 0;
					timer->gate->period = 0;
					timer->gate->active = 0;
					break;
			}

			break;
		}
		else
		{
			if (timer->clk->started)
			{
				if (timer->clk->div)
					timer->clk->clock += (clock - timer->clk->started - 9) / timer->clk->div;

				timer->clk->started = clock;
			}

			if (timer->started && timer->div && (timer->mode.MODE & 0x02) == 0x02)
				timer->clk->div = timer->div * timer->count;
			else
				timer->clk->div = 0;

			timer = timer->clk;
		}
	}
}

// -----------------------------------------------------------------------------

- (SInt8) sample:(uint64_t)clock
{
	SInt8 sample = 0; for (int i = 0; i < 3; i++)
	{
		if (timers[i].channel && timers[i].started && timers[i].div == 9 && timers[i].mode.MODE == 3 && timers[i].count > 100)
		{
			if (timers[i].gated == 0 || timers[i].gated > clock)
			{
				sample += (clock / 9) % timers[i].count > (timers[i].count >> 1) ? 20 : -20;
			}
		}
	}

	return sample;
}

// -----------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	if ((addr & 3) == 3)
		return status;

	struct i8253_timer *timer = timers + (addr & 3);

	uint16_t value; if (timer->bLatch)
	{
		value = timer->latch; timer->bLatch = timer->bRLow && timer->mode.RL == 3;
	}
	else
	{
		value = getTimerCount(timer, clock);
	}

	if (timer->mode.BCD)
	{
	}

	if (timer->bRLow)
	{
		if (timer->mode.RL == 3)
			timer->bRLow = FALSE;

		return value & 0xFF;
	}
	else
	{
		if (timer->mode.RL == 3)
			timer->bRLow = TRUE;

		return value >> 8;
	}
}

// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
//#ifdef DEBUG
//	NSLog(@"%04X: %02X", addr, data);
//#endif

	if ((addr & 3) == 3)
	{
		union i8253_mode mode; mode.byte = data; if (mode.SC == 3) return;
		struct i8253_timer *timer = timers + mode.SC;

//#ifdef DEBUG
//		NSLog(@"Timer %d: mode %d", mode.SC, mode.MODE);
//#endif

		if (mode.RL == 0)
		{
			timer->latch = getTimerCount(timer, clock);
			timer->bRLow = timer->mode.RL != 2;
			timer->bLatch = TRUE;
		}
		else
		{
			if (mode.MODE & 0x02 && timer->clk && timer->clk->started)
			{
				BOOL output = FALSE; switch (timer->mode.MODE)
				{
					case 0:

						output = timer->started && timer->count <= getTimerClock(timer, clock);
						break;

					case 3:

						if (timer->started)
						{
							if (timer->count)
								output = getTimerClock(timer, clock) % timer->count < ((timer->count + 1) / 2);
							else if (timer->mode.BCD)
								output = getTimerClock(timer, clock) % 10000 < 5000;
							else
								output = !(getTimerClock(timer, clock) & 0x8000);
						}
						else
						{
							output = TRUE;
						}
				}

				if (output == FALSE)
					timer->clk->clock++;
			}

			if (timer->started)
				timer->count = getTimerCount(timer, clock);

			if (mode.MODE & 0x02)
				mode.MODE &= 0x03;

			timer->started = 0;
			timer->mode = mode;

			timer->bWLow = mode.RL != 2;
			timer->bRLow = mode.RL != 2;
			timer->bLatch = FALSE;

			updateTimer(timer, clock);
		}
	}
	else
	{
		struct i8253_timer *timer = timers + (addr & 3);

		if (timer->bWLow && timer->mode.RL == 3)
		{
			timer->bWLow = FALSE;
			timer->load = data;

			if (timer->mode.MODE == 0 && timer->started)
			{
				timer->count = getTimerCount(timer, clock);
				timer->started = 0;

				updateTimer(timer, clock);
			}
		}
		else
		{
			uint16_t value = timer->bWLow ? data : data << 8;

			if (timer->mode.RL == 3)
			{
				value |= timer->load;
				timer->bWLow = TRUE;
			}

//#ifdef DEBUG
//			NSLog(@"Timer %d: %04X", addr & 3, value);
//#endif

			if (timer->mode.BCD)
			{
			}

			timer->started = clock + 18;
			timer->count = value;
			timer->clock = 0;

			updateTimer(timer, clock + 18);
		}
	}
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------

- (void) setGate2:(BOOL)gate clock:(uint64_t)clock
{
	if (timers[2].started)
	{
		timers[2].clock = getTimerClock(timers + 2, clock - 9);
		timers[2].started = clock - 9;
	}

	timers[2].gated = gate ? 0 : clock;
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------

- (void) setChannel0:(BOOL)channel0 { timers[0].channel = channel0; }
- (void) setChannel1:(BOOL)channel1 { timers[1].channel = channel1; }
- (void) setChannel2:(BOOL)channel2 { timers[2].channel = channel2; }

- (BOOL) channel0 { return timers[0].channel; }
- (BOOL) channel1 { return timers[1].channel; }
- (BOOL) channel2 { return timers[2].channel; }

- (void) setRkmode:(BOOL)rkmode
{
	timers[0].gate = timers[0].clk = timers[1].gate = timers[1].clk = timers[2].gate = timers[2].clk = NULL;
	if (rkmode) timers[1].clk = timers + 2; timers[2].gate = timers;
}

- (BOOL) rkmode
{
	return timers[1].clk == timers + 2 && timers[2].gate == timers;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		timers[0].started = timers[1].started = timers[2].started = random() | 0xFFFFFFFFFFFF0000;
		timers[0].div = timers[1].div = timers[2].div = 9;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeBytes:(const uint8_t*)timers length:sizeof(timers) forKey:@"timers"];
	[encoder encodeBool:self.rkmode forKey:@"rkmode"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super init])
	{
		NSUInteger length; const void *ptr;

		if ((ptr = [decoder decodeBytesForKey:@"timers" returnedLength:&length]) && length == sizeof(timers))
		{
			memcpy(timers, ptr, sizeof(timers)); self.rkmode = [decoder decodeBoolForKey:@"rkmode"];
		}
		else
		{
			return self = nil;
		}
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
