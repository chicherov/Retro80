/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Микросхема трехканального таймера КР580ВИ53 (8253)

 *****/

#import "X8253.h"

@implementation X8253
{
	// -------------------------------------------------------------------------
	// Таймеры i8253 (0-2) и бипер (3)
	// -------------------------------------------------------------------------

	struct i8253_timer
	{
		uint64_t clk;

		BOOL enable;
		BOOL gate;

		union i8253_mode
		{
			uint8_t byte; struct
			{
				unsigned  BCD:1;
				unsigned MODE:3;
				unsigned   RL:2;
				unsigned   SC:2;
			};

		} mode;
		
		uint16_t count;
		uint16_t latch;

		BOOL bLatch;
		BOOL bLow;

//		uint64_t started;
//		uint64_t value;
		BOOL output;

		uint64_t zero;

		uint64_t reload;
		uint64_t reloadHi;
		uint64_t reloadLo;

	} timers[4];

	uint64_t last_clock;
	unsigned last_mix;
	unsigned snd;

	uint64_t start_interval;
	uint16_t sample;
}

@synthesize sound;

// -----------------------------------------------------------------------------
// Функции для работы с таймером
// -----------------------------------------------------------------------------

static void update_timers(X8253 *sound, uint64_t clock)
{
	uint64_t c; do
	{
		c = sound->timers[0].reload && sound->timers[0].reload < clock ? sound->timers[0].reload : clock;
		if (sound->timers[1].reload && sound->timers[1].reload < c) c = sound->timers[1].reload;
		if (sound->timers[2].reload && sound->timers[2].reload < c) c = sound->timers[2].reload;
		if (sound->timers[3].reload && sound->timers[3].reload < c) c = sound->timers[3].reload;

		unsigned mix = 0; for (int i = 0; i < 4; i++) if (sound->timers[i].reload == c)
		{
			if ((sound->timers[i].output = !sound->timers[i].output))
			{
				if (sound->timers[i].reloadHi)
					sound->timers[i].zero = sound->timers[i].reload += sound->timers[i].reloadHi;
				else
					sound->timers[i].reload = 0;
			}
			else
			{
				if (sound->timers[i].enable && (sound->timers[i].mode.MODE != 3 || sound->timers[i].reloadLo > 300))
					mix++;

				if (sound->timers[i].reloadLo)
					sound->timers[i].zero = sound->timers[i].reload += sound->timers[i].reloadLo;
				else
					sound->timers[i].reload = 0;
			}

			if (sound->rkmode && i == 2)
				change_gate(sound, sound->timers + 0, !sound->timers[2].output, c);
		}
		else if (!sound->timers[i].output)
		{
			if (sound->timers[i].enable && (sound->timers[i].mode.MODE != 3 || sound->timers[i].reloadLo > 300))
				mix++;
		}

		if (mix != sound->last_mix)
		{
			sound->snd += sound->last_mix * (c - sound->last_clock);
			sound->last_mix = mix;
			sound->last_clock = c;
		}

	} while (c != clock);
}

static void change_output(X8253 *sound, struct i8253_timer *timer, BOOL output, uint64_t clock)
{
	if (timer->output != output)
	{
		timer->reload = clock; update_timers(sound, clock);
	}
	else
	{
		timer->reload = 0;
	}
}

static void change_gate(X8253 *sound, struct i8253_timer *timer, BOOL gate, uint64_t clock)
{
	if (timer->gate != gate)
	{
		if (timer->zero) switch (timer->mode.MODE)
		{
			case 0:

				if (gate)
				{
					timer->zero = clock + timer->count * timer->clk;

					if (timer->output == FALSE)
						timer->reload = timer->zero;
				}
				else
				{
					timer->count = count(timer, clock);
					timer->reload = 0;
				}

				break;

			case 1:

				if (gate)
				{
					if (timer->output)
						change_output(sound, timer, FALSE, clock + timer->clk);
					else
						timer->zero = timer->reload = clock + timer->reloadLo;
				}

				break;

			case 2:
			case 3:
			case 6:
			case 7:

				if (gate)
				{
					timer->zero = timer->reload = clock + timer->reloadHi;
				}
				else
				{
					timer->count = count(timer, clock);

					change_output(sound, timer, TRUE, clock);
					timer->reload = 0;
				}

				break;

			case 4:

				if (gate)
				{
					timer->reload = timer->zero = clock + timer->count * timer->clk;
				}
				else
				{
					timer->count = count(timer, clock);
					timer->reload = 0;
				}
				
			default:
				
				break;
		}

		timer->gate = gate;
	}
}

static uint16_t count(struct i8253_timer *timer, uint64_t clock)
{
	if (timer->zero) switch (timer->mode.MODE)
	{
		case 0:

			if (timer->gate)
			{
				if (timer->mode.BCD == 0 || timer->zero > clock)
					return (int64_t)(timer->zero - clock) / timer->clk;
				else
					return 10000 - (clock - timer->zero) / timer->clk % 10000;
			}

			break;

		case 1:
		case 5:

			if (timer->mode.BCD == 0 || timer->zero > clock)
				return (int64_t)(timer->zero - clock) / timer->clk;
			else
				return 10000 - (clock - timer->zero) / timer->clk % 10000;

		case 2:
		case 6:

			if (timer->gate)
			{
				if (timer->output)
					return (int64_t)(timer->zero - clock) / timer->clk + 1;
				else
					return timer->reloadHi / timer->clk + 1;
			}

			break;

		case 3:
		case 7:

			if (timer->gate)
			{
				if (timer->zero != clock)
					return ((int64_t)(timer->zero - clock) / timer->clk) * 2;
				else if (timer->mode.BCD == 0)
					return (timer->reloadHi + timer->reloadLo) / timer->clk;
				else
					return ((timer->reloadHi + timer->reloadLo) / timer->clk) % 10000;
			}

			break;

		case 4:

			if (timer->gate)
			{
				if (timer->zero > clock)
					return (timer->zero - clock) / timer->clk;
				else if (timer->mode.BCD == 0)
					return (int64_t)(timer->zero - clock) / timer->clk - 1;
				else
					return 9999 - (clock - timer->zero) / timer->clk % 10000;
			}

			break;
	}

	return timer->count;
}

// -----------------------------------------------------------------------------
// sample
// -----------------------------------------------------------------------------

- (uint16_t) sample:(uint64_t)clock
{
	update_timers(self, clock); if (clock > last_clock)
	{
		snd += last_mix * (clock - last_clock); last_clock = clock;
	}

	sample = ((snd << 13) / (clock - start_interval) + sample) / 2;

	start_interval = clock;
	snd = 0; return sample;
}

// -----------------------------------------------------------------------------
// Чтение/запись регистров ВИ53
// -----------------------------------------------------------------------------

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	update_timers(self, clock);

	if ((addr & 3) != 3)
	{
		struct i8253_timer *timer = timers + (addr & 3);

		uint16_t value; if (timer->bLatch)
		{
			value = timer->latch; timer->bLatch = timer->mode.RL == 3 && timer->bLow;
		}
		else
		{
			value = count(timer, clock);
		}

		if (timer->mode.BCD)
			value = ((value / 1000 % 10) << 12) | ((value / 100 % 10) << 8) | ((value / 10 % 10) << 4) | (value % 10);

		if (timer->bLow)
		{
			if (timer->mode.RL == 3)
				timer->bLow = FALSE;

			*data = value & 0xFF;
		}
		else
		{
			if (timer->mode.RL == 3)
				timer->bLow = TRUE;

			*data = value >> 8;
		}
	}
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	update_timers(self, clock);

	if ((addr & 3) == 3)
	{
		union i8253_mode mode = { data }; if (mode.SC != 3)
		{
			struct i8253_timer *timer = timers + mode.SC;

			if (mode.RL == 0)
			{
				if (timer->mode.RL != 3 || timer->bLow)
				{
					timer->latch = count(timer, clock + timer->clk);
					timer->bLatch = TRUE;
				}
			}
			else
			{
				timer->count = count(timer, clock + timer->clk);

				if (timer->mode.BCD)
				{
					if (mode.BCD == 0)
						timer->count = ((timer->count / 1000 % 10) << 12) | ((timer->count / 100 % 10) << 8) | ((timer->count / 10 % 10) << 4) | (timer->count % 10);
				}
				else if (mode.BCD)
					timer->count = (timer->count >> 12) * 1000 + ((timer->count & 0xF00) >> 8) * 100 + ((timer->count & 0xF0) >> 4) * 10 + (timer->count & 0xF);

				timer->mode = mode;

				timer->bLow = mode.RL != 2;
				timer->bLatch = FALSE;

				timer->reloadHi = 0;
				timer->reloadLo = 0;
				timer->zero = 0;

				change_output(self, timer, mode.MODE != 0, clock);

				if (rkmode && mode.SC == 1)
					timers[2].clk = 9;
			}
		}
	}
	else
	{
		struct i8253_timer *timer = timers + (addr & 3);

		if (timer->mode.RL == 3 && timer->bLow)
		{
			timer->latch = ((0xFF - data) << 8) | data;

			timer->bLatch = TRUE;
			timer->bLow = FALSE;

			if (timer->mode.MODE == 0)
			{
				change_output(self, timer, FALSE, clock + timer->clk);

				timer->count = count(timer, clock + timer->clk);
				timer->zero = 0;
			}
		}
		else
		{
			if ((timer->mode.MODE == 1 || timer->mode.MODE == 5) && (timer->zero == 0))
				timer->zero = clock + (timer->count + 3) * timer->clk;

			if (timer->mode.RL == 3)
			{
				timer->count = (data << 8) | (timer->latch & 0xFF);

				timer->bLatch = FALSE;
				timer->bLow = TRUE;
			}

			else if (timer->mode.RL == 2)
			{
				timer->count = data << 8;
			}

			else
			{
				timer->count = data;
			}

			if (timer->mode.BCD)
				timer->count = (timer->count >> 12) * 1000 + ((timer->count & 0xF00) >> 8) * 100 + ((timer->count & 0xF0) >> 4) * 10 + (timer->count & 0xF);

			switch (timer->mode.MODE)
			{
				case 0:

					change_output(self, timer, FALSE, clock);

					timer->zero = clock + (timer->count ? timer->count + 3 : 0x10003) * timer->clk;

					if (timer->gate)
						timer->reload = timer->zero;

					break;

				case 1:

					timer->reloadLo = (timer->count ? timer->count : 0x10000) * timer->clk;
					break;

				case 2:
				case 6:

					timer->reloadHi = (timer->count ? timer->count - 1 : timer->mode.BCD ? 9999 : 0xFFFF) * timer->clk;
					timer->reloadLo = timer->clk;

					if (timer->zero == 0)
					{
						timer->zero = clock + timer->clk * 3 + timer->reloadHi;

						if (timer->gate)
							timer->reload = timer->zero;
					}

					break;

				case 3:
				case 7:

					timer->reloadLo = (timer->count > 1 ? timer->count >> 1 : timer->mode.BCD ? 5000 : 0x8000) * timer->clk;
					timer->reloadHi = timer->reloadLo + (timer->count & 1) * timer->clk;

					if (timer->zero == 0)
					{
						timer->zero = clock + timer->clk * 3 + timer->reloadHi;

						if (timer->gate)
							timer->reload = timer->zero;
					}

					break;

				case 4:

					timer->zero = clock + ((timer->count ? timer->count : timer->mode.BCD ? 10000 : 0x10000) + 3) * timer->clk;
					timer->reloadLo = timer->clk;

					if (timer->gate)
						timer->reload = timer->zero;

					break;

				case 5:

					timer->reloadLo = (timer->count ? timer->count : 0x10000) * timer->clk;

					break;
					
			}

			if (rkmode && timer->mode.SC == 1 && (timer->mode.MODE == 2 || timer->mode.MODE == 3))
			{
				timers[2].clk = (uint32_t) (timer->reloadHi + timer->reloadLo);
			}
		}
	}
}

// -----------------------------------------------------------------------------
// Управление вход gate 2 для Микроши
// -----------------------------------------------------------------------------

- (void) setGate2:(BOOL)gate clock:(uint64_t)clock
{
	change_gate(self, timers + 2, gate, clock);
}

// -----------------------------------------------------------------------------
// Динамик на EI/DI для Радио-86РК/Орион-128
// -----------------------------------------------------------------------------

- (void) INTE:(BOOL)IF clock:(uint64_t)clock
{
	change_output(self, timers + 3, !IF, clock);
}

// -----------------------------------------------------------------------------
// Динамик на бите одного из порта
// -----------------------------------------------------------------------------

- (void) setBeeper:(BOOL)beeper clock:(uint64_t)clock
{
	change_output(self, timers + 3, !beeper, clock);
}

// -----------------------------------------------------------------------------
// "Пищалка" для Партнер 01.01
// -----------------------------------------------------------------------------

- (void) setTone:(unsigned)tone clock:(uint64_t)clock
{
	if (tone)
	{
		timers[3].reloadHi = (tone >> 1);
		timers[3].reloadLo = (tone >> 1);

		if (timers[3].reload == 0)
			timers[3].reload = clock + timers[3].reloadHi;
	}
	else
	{
		timers[3].reloadHi = 0;
	}
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------

- (void) setChannel0:(BOOL)channel0 { timers[0].enable = channel0; }
- (void) setChannel1:(BOOL)channel1 { timers[1].enable = channel1; }
- (void) setChannel2:(BOOL)channel2 { timers[2].enable = channel2; }

- (BOOL) channel0 { return timers[0].enable; }
- (BOOL) channel1 { return timers[1].enable; }
- (BOOL) channel2 { return timers[2].enable; }

@synthesize rkmode;

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		timers[0].zero = timers[1].zero = timers[2].zero = random();
		timers[0].clk = timers[1].clk = timers[2].clk = 9;

		timers[0].gate = 1;
		timers[1].gate = 1;
		timers[2].gate = 1;
		timers[3].gate = 1;

		timers[0].output = 1;
		timers[1].output = 1;
		timers[2].output = 1;
		timers[3].output = 1;

		timers[3].enable = 1;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:[NSData dataWithBytes:&timers length:sizeof(timers)] forKey:[NSString stringWithUTF8String:@encode(struct i8253_timer)]];
	[encoder encodeBool:self.rkmode forKey:@"rkmode"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super init])
	{
		NSData *data;

		if ((data = [decoder decodeObjectForKey:[NSString stringWithUTF8String:@encode(struct i8253_timer)]]) == nil)
			return self = nil;

		[data getBytes:&timers];

		self.rkmode = [decoder decodeBoolForKey:@"rkmode"];
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
