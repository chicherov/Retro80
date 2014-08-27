#import "Sound.h"
#import "x8080.h"

@interface X8253 : Sound <ReadWrite, NSCoding>
{
	struct i8253_timer
	{
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
		uint64_t CLK;

		uint8_t load;

		BOOL bLatch;
		BOOL bRLow;
		BOOL bWLow;

	} timer[3];
}

@property BOOL channel0;
@property BOOL channel1;
@property BOOL channel2;

@end
