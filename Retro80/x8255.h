/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Микросхема параллельного интерфейса КР580ВВ55А (8255A)

 *****/

#import "Retro80.h"

@interface X8255 : NSResponder <RD, WR, RESET, NSCoding>
{
	union i8255_mode
	{
		uint8_t byte;

		struct
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

@property(nonatomic, assign) Retro80 *computer;

@property(nonatomic) uint8_t mode;
@property(nonatomic) uint8_t A;
@property(nonatomic) uint8_t B;
@property(nonatomic) uint8_t C;

@end
