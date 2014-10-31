/*******************************************************************************
 Контроллер прямого доступа к памяти КР580ВТ57 (8257)
 ******************************************************************************/

#import "x8257.h"

@implementation X8257
{
	BOOL latch;
}

// -----------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)data
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
		unsigned channel = (addr & 0x06) >> 1;

		dma[channel].byte[addr & 1][latch] = data;

		if (channel == 2 && mode.a)
			dma[3].byte[addr & 1][latch] = data;

		latch = !latch;
	}

	else if ((addr & 0x0F) == 0x08)
	{
		mode.byte = data;

		if (mode.a  == FALSE)
			status.U = FALSE;

		latch = FALSE;
	}
}

// -----------------------------------------------------------------------------

BOOL i8257DMA2(X8257* dma, uint8_t *data)
{
	if (dma->mode.dma2 && dma->dma[2].type == 1)
	{
		if (dma->status.U)
		{
			dma->dma[2].address = dma->dma[3].address;
			dma->dma[2].count = dma->dma[3].count;
			dma->status.U = FALSE;
		}

		*data = MEMR(dma->_cpu, dma->dma[2].address++, 0x00);

		if (dma->dma[2].count-- == 0)
		{
			dma->status.TC2 = TRUE;

			if (dma->mode.a)
				dma->status.U = TRUE;

			else if (dma->mode.t)
				dma->mode.dma2 = FALSE;
		}

		return TRUE;
	}

	*data = 0x00;
	return FALSE;
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
