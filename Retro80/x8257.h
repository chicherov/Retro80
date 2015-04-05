/*******************************************************************************
 Контроллер прямого доступа к памяти КР580ВТ57 (8257)
 ******************************************************************************/

#import "x8080.h"

@interface X8257 : NSObject<RD, WR, NSCoding>
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

BOOL i8257DMA2(X8257* dma, uint8_t *data);

@end
