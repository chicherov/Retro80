/*******************************************************************************
 Микросхема трехканального таймера КР580ВИ53 (8253)
 ******************************************************************************/

#import "Sound.h"
#import "x8080.h"

@interface X8253 : NSObject <SoundController, ReadWrite, NSCoding>
{
	struct i8253_timer
	{
		struct i8253_timer *gate;
		struct i8253_timer *clk;

		BOOL channel;
		unsigned div;

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

		uint64_t started;
		uint64_t clock;

		uint64_t gated;
		uint64_t period;
		uint64_t active;

		uint16_t count;
		uint16_t latch;
		uint8_t load;

		BOOL bLatch;
		BOOL bRLow;
		BOOL bWLow;

	} timers[3];
}

@property BOOL channel0;
@property BOOL channel1;
@property BOOL channel2;

@property BOOL rkmode;

- (void) setGate2:(BOOL)gate
			clock:(uint64_t)clock;

@end
