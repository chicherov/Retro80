#import "x8257.h"

@implementation X8257
{
	uint8_t latch;
}

// -----------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	return status;
}

// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	if ((addr & 0x08) == 0)
	{
		unsigned channel = (addr & 0x06) >> 1;

		dma[channel].byte[addr & 1][(latch >> channel) & 1] = data;
		latch ^= 0x01 << channel;

		if (channel == 2 && mode.a)
		{
			dma[3].byte[addr & 1][(latch >> 3) & 1] = data;
			latch ^= 0x08;
		}
	}

	else if ((addr & 0x0F) == 0x08)
	{
		mode.byte = data;
	}
}

// -----------------------------------------------------------------------------

BOOL i8257DMA2(X8257* dma, uint8_t *data)
{
	if (dma->mode.dma2 && dma->dma[2].type == 1)
	{
		*data = MEMR(dma->_cpu, dma->dma[2].address, 0xFF);

		dma->dma[2].address++; if (dma->dma[2].count-- == 0 && dma->mode.a)
		{
			dma->dma[2].address = dma->dma[3].address;
			dma->dma[2].count = dma->dma[3].count;
		}

		return TRUE;
	}

	*data = 0x00;
	return FALSE;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:mode.byte forKey:@"mode"];
	[encoder encodeInt:latch forKey:@"latch"];

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
		latch = [decoder decodeIntForKey:@"latch"];

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
