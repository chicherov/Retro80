/*******************************************************************************
 Контроллер прямого доступа к памяти КР580ВТ57 (8257)
 ******************************************************************************/

#import "x8257.h"

@implementation X8257
{
	BOOL latch;

	unsigned (*CallHLDA) (id, SEL, uint64_t);
	NSObject<HLDA> *HLDA;

	NSObject<DMA> *DMA[4];
	uint64_t* DRQ[4];

	unsigned channel;
}

@synthesize cpu;

// -----------------------------------------------------------------------------

- (void) setHLDA:(NSObject<HLDA> *)object
{
	CallHLDA = (unsigned (*) (id, SEL, uint64_t)) [HLDA = object methodForSelector:@selector(HLDA:)];
}

// -----------------------------------------------------------------------------

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

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock data:(uint8_t)data
{
	if ((addr & 0x08) == 0)
	{
		data = dma[(addr & 0x06) >> 1].byte[addr & 1][latch];
		latch = !latch;
	}
	else if ((addr & 0x0F) == 0x08)
	{
		data = status.byte;
		status.byte &= 0xF0;
	}

	return data;
}

// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
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

#ifdef DEBUG
		if (mode.dma0)
			NSLog(@"Enable DMA CHANNEL 0: %d: %04X/%d", dma[0].type, dma[0].address, dma[0].count+1);
#endif

		if (mode.a  == FALSE)
			status.U = FALSE;

		latch = FALSE;
	}
}

// -----------------------------------------------------------------------------

- (unsigned) HLDA:(uint64_t)clock
{
	if (HLDA)
		CallHLDA(HLDA, @selector(HLDA:), clock);

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

	unsigned clk = 18;

	do
	{
		if (channel == 2 && status.U)
		{
			dma[2].address = dma[3].address;
			dma[2].count = dma[3].count;
			status.U = FALSE;
		}

		if (dma[channel].type == 1)
		{
			uint8_t data = MEMR(cpu, dma[channel].address++, clock + clk + 9, 0x00);
			[DMA[channel] WR:data clock:clock + clk + 18];
		}

		else
		{
			uint8_t data = 0x00; [DMA[channel] RD:&data clock:clock + clk + 9];
			MEMW(cpu, dma[channel].address++, data, clock + clk + 18);
		}

		if (dma[channel].count-- == 0)
		{
			status.byte |= 1 << channel;

			if (channel == 2 && mode.a)
				status.U = TRUE;

			else if (mode.t)
				mode.byte &= ~(1 << channel);
		}
		
		clk += 36;

	} while (*DRQ[channel] <= clock + clk);

	return clk;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		*(uint32_t*)dma[0].byte = 0xFFFF0000;
		*(uint32_t*)dma[1].byte = 0xFFFF0000;
		*(uint32_t*)dma[2].byte = 0xFFFF0000;
		*(uint32_t*)dma[3].byte = 0xFFFF0000;
	}

	return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:mode.byte forKey:@"mode"];
	[encoder encodeInt:status.byte forKey:@"status"];
	[encoder encodeBool:latch forKey:@"latch"];

	[encoder encodeInt32:*(uint32_t*)dma[0].byte forKey:@"dma0"];
	[encoder encodeInt32:*(uint32_t*)dma[1].byte forKey:@"dma1"];
	[encoder encodeInt32:*(uint32_t*)dma[2].byte forKey:@"dma2"];
	[encoder encodeInt32:*(uint32_t*)dma[3].byte forKey:@"dma3"];

}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super init])
	{
		mode.byte = [decoder decodeIntForKey:@"mode"];
		status.byte = [decoder decodeIntForKey:@"status"];
		latch = [decoder decodeBoolForKey:@"latch"];

		*(uint32_t*)dma[0].byte = [decoder decodeInt32ForKey:@"dma0"];
		*(uint32_t*)dma[1].byte = [decoder decodeInt32ForKey:@"dma1"];
		*(uint32_t*)dma[2].byte = [decoder decodeInt32ForKey:@"dma2"];
		*(uint32_t*)dma[3].byte = [decoder decodeInt32ForKey:@"dma3"];
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
