/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Контроллер прямого доступа к памяти КР580ВТ57 (8257)

 *****/

#import "x8080.h"

// -----------------------------------------------------------------------------

@protocol DMA <NSObject>

- (void) RD:(uint8_t *)data clock:(uint64_t)clock;
- (void) WR:(uint8_t)data clock:(uint64_t)clock;

- (uint64_t *) DRQ;

@end

// -----------------------------------------------------------------------------

@interface X8257 : NSObject<RD, WR, HLDA, NSCoding>
{
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

	} dma[4];
}

@property (weak) X8080* cpu;

- (void) setHLDA:(NSObject<HLDA> *)object;

- (void) setDMA0:(NSObject<DMA> *)DMA;
- (void) setDMA1:(NSObject<DMA> *)DMA;
- (void) setDMA2:(NSObject<DMA> *)DMA;
- (void) setDMA3:(NSObject<DMA> *)DMA;

@end
