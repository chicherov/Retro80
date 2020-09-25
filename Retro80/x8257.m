/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Контроллер прямого доступа к памяти КР580ВТ57 (8257)

 *****/

#import "x8257.h"

@implementation X8257
{
	// -------------------------------------------------------------------------
	// Регистры i8257
	// -------------------------------------------------------------------------

	union i8257_mode
	{
		uint8_t byte; struct
		{
			unsigned dma0:1;	// Enable DMA CHANNEL 0
			unsigned dma1:1;	// Enable DMA CHANNEL 1
			unsigned dma2:1;	// Enable DMA CHANNEL 2
			unsigned dma3:1;	// Enable DMA CHANNEL 3

			unsigned r:1;		// Enable ROTATING PRIORITY
			unsigned e:1;		// Enable EXTENDED WRITE
			unsigned t:1;		// Enable TC STOP
			unsigned a:1;		// Enable AUTO LOAD
		};

	} mode;

	union i8257_status
	{
		uint8_t byte; struct
		{
			unsigned TC0:1;		// TC CHANNEL 0
			unsigned TC1:1;		// TC CHANNEL 0
			unsigned TC2:1;		// TC CHANNEL 0
			unsigned TC3:1;		// TC CHANNEL 0

			unsigned U:1;		// UPDATE
		};

	} status;

	union i8257_channel
	{
		uint8_t byte[2][2]; struct
		{
			unsigned address:16;
			unsigned   count:14;
			unsigned    type:2;
		};

		uint32_t value;

	} dma[4];

	unsigned channel;
	BOOL latch;

	// -------------------------------------------------------------------------
	// Внешние подключения
	// -------------------------------------------------------------------------

	unsigned (*CallHLDA) (id, SEL, uint64_t, unsigned);
	NSObject<HLDA> *HLDA;

	NSObject<DMA> *DMA[4];
	uint64_t* DRQ[4];
}

@synthesize tick;

@synthesize cpu;

// -----------------------------------------------------------------------------
// Внешние подключения
// -----------------------------------------------------------------------------

- (void) setHLDA:(NSObject<HLDA> *)object
{
	CallHLDA = (unsigned (*) (id, SEL, uint64_t, unsigned)) [HLDA = object methodForSelector:@selector(HLDA:clk:)];
}

- (void) setDMA0:(NSObject<DMA> *)object
{
	DRQ[0] = [DMA[0] = object DRQ];
}

- (void) setDMA1:(NSObject<DMA> *)object
{
	DRQ[1] = [DMA[1] = object DRQ];
}

- (void) setDMA2:(NSObject<DMA> *)object
{
	DRQ[2] = [DMA[2] = object DRQ];
}

- (void) setDMA3:(NSObject<DMA> *)object
{
	DRQ[3] = [DMA[3] = object DRQ];
}

// -----------------------------------------------------------------------------
// Чтение/запись регистров ВТ57
// -----------------------------------------------------------------------------

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if ((addr & 0x08) == 0)
	{
		*data = dma[(addr & 0x06) >> 1].byte[addr & 1][latch];
		latch = !latch;
	}
	else if ((addr & 0x0F) == 0x08)
	{
		*data = status.byte;
		status.byte &= 0xF0;
	}
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	if ((addr & 0x08) == 0)
	{
		dma[(addr & 0x06) >> 1].byte[addr & 1][latch] = data;

		if (addr & 0x04 && mode.a)
			dma[3].byte[addr & 1][latch] = data;

		latch = !latch;
	}

	else if ((addr & 0x0F) == 0x08)
	{
		mode.byte = data;

		if (mode.a == NO)
			status.U = NO;

		latch = NO;
	}
}

// -----------------------------------------------------------------------------
// Обработка сигнала HLDA
// -----------------------------------------------------------------------------

- (unsigned) HLDA:(uint64_t)clock clk:(unsigned)clk
{
	if (HLDA)
		CallHLDA(HLDA, @selector(HLDA:clk:), clock, clk);

	channel = mode.r ? (channel + 1) & 3 : 0;

	if (!(mode.byte & (1 << channel) && dma[channel].type && dma[channel].type != 3 && DRQ[channel] && *DRQ[channel] <= clock))
	{
		channel = (channel + 1) & 3; if (!(mode.byte & (1 << channel) && dma[channel].type && dma[channel].type != 3 && DRQ[channel] && *DRQ[channel] <= clock))
		{
			channel = (channel + 1) & 3; if (!(mode.byte & (1 << channel) && dma[channel].type && dma[channel].type != 3 && DRQ[channel] && *DRQ[channel] <= clock))
			{
				channel = (channel + 1) & 3; if (!(mode.byte & (1 << channel) && dma[channel].type && dma[channel].type != 3 && DRQ[channel] && *DRQ[channel] <= clock))
				{
					return 0;
				}
			}
		}
	}

	clk += tick - (clock + clk) % tick;

	do
	{
		if (channel == 2 && status.U)
		{
			dma[2].address = dma[3].address;
			dma[2].count = dma[3].count;
			status.U = NO;
		}

		if (dma[channel].type == 1)
		{
			uint8_t data = MEMR(cpu, dma[channel].address++, clock + clk + tick * 2, 0x00);
			[DMA[channel] WR:data clock:clock + clk + tick * 3];
		}

		else
		{
			uint8_t data = 0x00; [DMA[channel] RD:&data clock:clock + clk + tick * 2];
			MEMW(cpu, dma[channel].address++, data, clock + clk + tick * 3, 0x00);
		}

		if (dma[channel].count-- == 0)
		{
			status.byte |= 1 << channel;

			if (channel == 2 && mode.a)
				status.U = YES;

			else if (mode.t)
				mode.byte &= ~(1 << channel);
		}
		
		clk += tick * 4;

	} while (*DRQ[channel] == 0 /*<= clock + clk - 9*/);

	return clk + 9 - clk % 9;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		dma[0].value = 0xFFFF0000;
		dma[1].value = 0xFFFF0000;
		dma[2].value = 0xFFFF0000;
		dma[3].value = 0xFFFF0000;

		tick = 9;
	}

	return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:tick forKey:@"tick"];
	[encoder encodeInt:mode.byte forKey:@"mode"];
	[encoder encodeInt:status.byte forKey:@"status"];
	[encoder encodeBool:latch forKey:@"latch"];

	[encoder encodeInt32:dma[0].value forKey:@"dma0"];
	[encoder encodeInt32:dma[1].value forKey:@"dma1"];
	[encoder encodeInt32:dma[2].value forKey:@"dma2"];
	[encoder encodeInt32:dma[3].value forKey:@"dma3"];

}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super init])
	{
		tick = [decoder decodeIntForKey:@"tick"];
		mode.byte = [decoder decodeIntForKey:@"mode"];
		status.byte = [decoder decodeIntForKey:@"status"];
		latch = [decoder decodeBoolForKey:@"latch"];

		dma[0].value = [decoder decodeInt32ForKey:@"dma0"];
		dma[1].value = [decoder decodeInt32ForKey:@"dma1"];
		dma[2].value = [decoder decodeInt32ForKey:@"dma2"];
		dma[3].value = [decoder decodeInt32ForKey:@"dma3"];
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
