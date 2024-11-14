/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Интерфейс клавиатуры ПЭВМ «Микро-80»

 *****/

#import "Micro80Keyboard.h"

@implementation Micro80Keyboard

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	[super RD:addr ^ 3 data:data CLK:clock];
}

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	[super WR:addr ^ 3 data:data CLK:clock];
}

- (uint8_t)B
{
	return [super B] & 0x7F;
}

- (uint8_t)C
{
	uint8_t data = 0xFF & ~(RUSLAT | CTRL | SHIFT);

	if (!(modifierFlags & NSEventModifierFlagCapsLock))
		data |= RUSLAT;

	if (!(modifierFlags & NSEventModifierFlagControl))
		data |= CTRL;

	if (!(modifierFlags & NSEventModifierFlagShift))
		data |= SHIFT;

	else if (self.qwerty)
	{
		for (int i = 8; i < 48; i++)
		{
			if (i != 40 && i != 41 && keyboard[i])
			{
				data &= ~RUSLAT;
				data |= SHIFT;
				break;
			}
		}
	}

	return data;
}

- (void)keyboardInit
{
	[super keyboardInit];

	kbdmap = @[
		// 18 08    19    1A    0D    1F    0C    ?
		@124, @123, @126, @125, @36,  @117, @115, @-1,
		// 5A 5B    5C    5D    5E    5F    20    ?
		@35,  @34,  @39,  @31,  @7,   @51,  @49,  @-1,
		// 53 54    55    56    57    58    59    ?
		@8,   @45,  @14,  @41,  @2,   @46,  @1,   @-1,
		// 4C 4D    4E    4F    50    51    52    ?
		@40,  @9,   @16,  @38,  @5,   @6,   @4,   @-1,
		// 45 46    47    48    49    4A    4B    ?
		@17,  @0,   @32,  @33,  @11,  @12,  @15,  @-1,
		// 2E 2F    40    41    42    43    44    ?
		@42,  @50,  @47,  @3,   @43,  @13,  @37,  @-1,
		// 37 38    39    3A    3B    2C    2D    ?
		@26,  @28,  @25,  @30,  @10,  @44,  @27,  @-1,
		// 30 31    32    33    34    35    36    ?
		@29,  @18,  @19,  @20,  @21,  @23,  @22,  @-1
	];

	chr1Map = @"\r\0Z[\\]^_ \0STUVWXY\0LMNOPQR\0EFGHIJK\0./@ABCD\0""789:;,-\0""0123456\0";
	chr2Map = @"\r\0ЗШЭЩЧ\0 \0СТУЖВЬЫ\0ЛМНОПЯР\0ЕФГХИЙК\0>?ЮАБЦД\0'()*+<=\0""0!\"#$%&\0";

	RUSLAT = 0x01;
	SHIFT = 0x04;
	CTRL = 0x02;

	TAPEO = 0;
	TAPEI = 0;
}

@end
