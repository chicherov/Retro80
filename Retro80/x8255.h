/*******************************************************************************
 Микросхема параллельного интерфейса КР580ВВ55А (8255A)
 ******************************************************************************/

#import "x8080.h"

@interface X8255 : NSObject<RD, WR, RESET, NSCoding>
{
	uint64_t current;

	union i8255_mode
	{
		uint8_t byte; struct
		{
			unsigned L:1;	// Port C 0-3: 0-output, 1-input
			unsigned B:1;	// Port B: 0-output, 1-input
			unsigned GB:1;	// Group B mode (0-1)

			unsigned H:1;	// Port C 4-7: 0-output, 1-input
			unsigned A:1;	// Port A: 0-output, 1-input
			unsigned GA:2;	// Group A mode
		};
		
	} mode;

	uint8_t A;
	uint8_t B;
	uint8_t C;
}

@property uint8_t mode;
@property uint8_t A;
@property uint8_t B;
@property uint8_t C;

@end
