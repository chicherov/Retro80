/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Микросхема трехканального таймера КР580ВИ53 (8253)

 *****/

#import "x8253.h"
#import "Sound.h"

@implementation X8253
{
	// Таймеры i8253 (0-2),  бипер (3) и выход на магнитофон (4)
	struct i8253_timer
	{
		uint32_t clk;

		BOOL enable;
		BOOL gate;

		union i8253_mode
		{
			uint8_t byte;
			struct
			{
				unsigned BCD:1;
				unsigned MODE:3;
				unsigned RL:2;
				unsigned SC:2;
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

	} timers[5];

	unsigned last_mix;
}

@synthesize enabled;
@synthesize sound;

static void update_timers(X8253 *x8253, uint64_t clock)
{
	uint64_t clk;

	do
	{
		clk = clock;

		if (x8253->timers[0].reload) clk = MIN(clk, x8253->timers[0].reload);
		if (x8253->timers[1].reload) clk = MIN(clk, x8253->timers[1].reload);
		if (x8253->timers[2].reload) clk = MIN(clk, x8253->timers[2].reload);
		if (x8253->timers[3].reload) clk = MIN(clk, x8253->timers[3].reload);
		if (x8253->timers[4].reload) clk = MIN(clk, x8253->timers[4].reload);

		unsigned mix = 0;

		for (int i = 0; i < 5; i++)
		{
			if (x8253->timers[i].reload == clk)
			{
				if ((x8253->timers[i].output = !x8253->timers[i].output))
				{
					if (x8253->timers[i].reloadHi)
						x8253->timers[i].zero = x8253->timers[i].reload += x8253->timers[i].reloadHi;
					else
						x8253->timers[i].reload = 0;
				}
				else
				{
					if (x8253->timers[i].enable && (x8253->timers[i].mode.MODE != 3 || x8253->timers[i].reloadLo > 300))
						mix++;

					if (x8253->timers[i].reloadLo)
						x8253->timers[i].zero = x8253->timers[i].reload += x8253->timers[i].reloadLo;
					else
						x8253->timers[i].reload = 0;
				}

				if (x8253->rkmode && i == 2)
					change_gate(x8253, x8253->timers + 0, !x8253->timers[2].output, clk);
			}
			else if (!x8253->timers[i].output)
			{
				if ((i >= 3 || x8253->enabled) && x8253->timers[i].enable
					&& (x8253->timers[i].mode.MODE != 3 || x8253->timers[i].reloadLo > 300))
					mix++;
			}
		}

		[x8253->sound update:clk output:x8253->timers[4].output left:mix << 13 right:mix << 13];

	}
	while (clk != clock);
}

static void change_output(X8253 *sound, struct i8253_timer *timer, BOOL output, uint64_t clock)
{
	if (timer->output != output)
	{
		timer->reload = clock;
		update_timers(sound, clock);
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
		if (timer->zero)
			switch (timer->mode.MODE)
			{
				case 0:

					if (gate)
					{
						timer->zero = clock + (uint64_t) timer->count*timer->clk;

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
						timer->reload = timer->zero = clock + (uint64_t) timer->count*timer->clk;
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
	if (timer->zero)
		switch (timer->mode.MODE)
		{
			case 0:

				if (timer->gate)
				{
					if (timer->mode.BCD == 0 || timer->zero > clock)
						return (int64_t) (timer->zero - clock)/timer->clk;
					else
						return 10000 - (clock - timer->zero)/timer->clk%10000;
				}

				break;

			case 1:
			case 5:

				if (timer->mode.BCD == 0 || timer->zero > clock)
					return (int64_t) (timer->zero - clock)/timer->clk;
				else
					return 10000 - (clock - timer->zero)/timer->clk%10000;

			case 2:
			case 6:

				if (timer->gate)
				{
					if (timer->output)
						return (int64_t) (timer->zero - clock)/timer->clk + 1;
					else
						return timer->reloadHi/timer->clk + 1;
				}

				break;

			case 3:
			case 7:

				if (timer->gate)
				{
					if (timer->zero != clock)
						return ((int64_t) (timer->zero - clock)/timer->clk)*2;
					else if (timer->mode.BCD == 0)
						return (timer->reloadHi + timer->reloadLo)/timer->clk;
					else
						return ((timer->reloadHi + timer->reloadLo)/timer->clk)%10000;
				}

				break;

			case 4:

				if (timer->gate)
				{
					if (timer->zero > clock)
						return (timer->zero - clock)/timer->clk;
					else if (timer->mode.BCD == 0)
						return (int64_t) (timer->zero - clock)/timer->clk - 1;
					else
						return 9999 - (clock - timer->zero)/timer->clk%10000;
				}

				break;
		}

	return timer->count;
}

- (void)flush:(uint64_t)clock
{
	update_timers(self, clock);
}

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	update_timers(self, clock);

	if (enabled && (addr & 3) != 3)
	{
		struct i8253_timer *timer = timers + (addr & 3);

		uint16_t value;
		if (timer->bLatch)
		{
			value = timer->latch;
			timer->bLatch = timer->mode.RL == 3 && timer->bLow;
		}
		else
		{
			value = count(timer, clock);
		}

		if (timer->mode.BCD)
			value = ((value/1000%10) << 12) | ((value/100%10) << 8) | ((value/10%10) << 4) | (value%10);

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

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	update_timers(self, clock);

	if (enabled)
	{
		if ((addr & 3) == 3)
		{
			union i8253_mode mode = {data};
			if (mode.SC != 3)
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
							timer->count = ((timer->count/1000%10) << 12) | ((timer->count/100%10) << 8)
								| ((timer->count/10%10) << 4) | (timer->count%10);
					}
					else if (mode.BCD)
						timer->count = (timer->count >> 12)*1000 + ((timer->count & 0xF00) >> 8)*100
							+ ((timer->count & 0xF0) >> 4)*10 + (timer->count & 0xF);

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
					timer->zero = clock + (uint64_t) (timer->count + 3)*timer->clk;

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
					timer->count =
						(timer->count >> 12)*1000 + ((timer->count & 0xF00) >> 8)*100 + ((timer->count & 0xF0) >> 4)*10
							+ (timer->count & 0xF);

				switch (timer->mode.MODE)
				{
					case 0:

						change_output(self, timer, FALSE, clock);

						timer->zero = clock + (uint64_t) (timer->count ? timer->count + 3 : 0x10003)*timer->clk;

						if (timer->gate)
							timer->reload = timer->zero;

						break;

					case 1:

						timer->reloadLo = (uint64_t) (timer->count ? timer->count : 0x10000)*timer->clk;
						break;

					case 2:
					case 6:

						timer->reloadHi =
							(uint64_t) (timer->count ? timer->count - 1 : timer->mode.BCD ? 9999 : 0xFFFF)*timer->clk;
						timer->reloadLo = timer->clk;

						if (timer->zero == 0)
						{
							timer->zero = clock + timer->clk*3 + timer->reloadHi;

							if (timer->gate)
								timer->reload = timer->zero;
						}

						break;

					case 3:
					case 7:

						timer->reloadLo =
							(uint64_t) (timer->count > 1 ? timer->count >> 1 : timer->mode.BCD ? 5000 : 0x8000)
								*timer->clk;
						timer->reloadHi = timer->reloadLo + (timer->count & 1)*timer->clk;

						if (timer->zero == 0)
						{
							timer->zero = clock + timer->clk*3 + timer->reloadHi;

							if (timer->gate)
								timer->reload = timer->zero;
						}

						break;

					case 4:

						timer->zero = clock
							+ (uint64_t) ((timer->count ? timer->count : timer->mode.BCD ? 10000 : 0x10000) + 3)
								*timer->clk;
						timer->reloadLo = timer->clk;

						if (timer->gate)
							timer->reload = timer->zero;

						break;

					case 5:

						timer->reloadLo = (uint64_t) (timer->count ? timer->count : 0x10000)*timer->clk;

						break;

				}

				if (rkmode && timer->mode.SC == 1 && (timer->mode.MODE == 2 || timer->mode.MODE == 3))
				{
					timers[2].clk = (uint32_t) (timer->reloadHi + timer->reloadLo);
				}
			}
		}
	}
}

// Управление вход gate 2 для Микроши
- (void)setGate2:(BOOL)gate clock:(uint64_t)clock
{
	change_gate(self, timers + 2, gate, clock);
}

// Динамик на EI/DI для Радио-86РК/Орион-128
- (void)INTE:(BOOL)IF clock:(uint64_t)clock
{
	change_output(self, timers + 3, !IF, clock);
}

// Динамик на бите одного из порта
- (void)setBeeper:(BOOL)beeper clock:(uint64_t)clock
{
	change_output(self, timers + 3, !beeper, clock);
}

- (void)setOutput:(BOOL)output clock:(uint64_t)clock
{
	change_output(self, timers + 4, !output, clock);
}

// "Пищалка" для Партнер 01.01
- (void)setTone:(unsigned)tone clock:(uint64_t)clock
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

- (void)setChannel0:(BOOL)channel0 { timers[0].enable = channel0; }
- (void)setChannel1:(BOOL)channel1 { timers[1].enable = channel1; }
- (void)setChannel2:(BOOL)channel2 { timers[2].enable = channel2; }

- (BOOL)channel0 { return timers[0].enable; }
- (BOOL)channel1 { return timers[1].enable; }
- (BOOL)channel2 { return timers[2].enable; }

@synthesize rkmode;

- (id)init
{
	if (self = [super init])
	{
		enabled = TRUE;
		rkmode = FALSE;

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
		timers[4].output = 1;

		timers[3].enable = 1;
		timers[4].enable = 1;

	}

	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeBool:self.enabled forKey:@"enabled"];
	[coder encodeBool:self.rkmode forKey:@"rkmode"];

	[coder encodeObject:[NSData dataWithBytes:&timers length:sizeof(timers)]
				   forKey:[NSString stringWithUTF8String:@encode(struct i8253_timer)]];
}

- (id)initWithCoder:(NSCoder *)coder
{
	if (self = [super init])
	{
		self.enabled = [coder decodeBoolForKey:@"enabled"];
		self.rkmode = [coder decodeBoolForKey:@"rkmode"];

		NSData *data;

		if ((data = [coder decodeObjectForKey:[NSString stringWithUTF8String:@encode(struct i8253_timer)]]) == nil)
			return self = nil;

		[data getBytes:&timers];
	}

	return self;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(VI53:))
	{
		menuItem.state = self.enabled;
		menuItem.hidden = FALSE;
		return YES;
	}

	return [super validateMenuItem:menuItem];
}

- (IBAction)VI53:(id)sender
{
	self.enabled = !self.enabled;
}

#ifdef DEBUG
- (void)dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
