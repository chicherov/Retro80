/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Клавиатура ПЭВМ «Микроша»

 *****/

#import "Microsha.h"

@implementation MicroshaKeyboard

- (void)keyboardInit
{
    [super keyboardInit];

    kbdmap = @[
               // 58 59    5A    5B    5C    5D    5E    5F
               @46,  @1,   @35,  @34,  @39,  @31,  @7,   @24,
               // 50 51    52    53    54    55    56    57
               @5,   @6,   @4,   @8,   @45,  @14,  @41,  @2,
               // 48 49    4A    4B    4C    4D    4E    4F
               @33,  @11,  @12,  @15,  @40,  @9,   @16,  @38,
               // 40 41    42    43    44    45    46    47
               @47,  @3,   @43,  @13,  @37,  @17,  @0,   @32,
               // 38 39    3A    3B    2C    2D    2E    2F
               @28,  @25,  @30,  @10,  @44,  @27,  @42,  @50,
               // 30 31    32    33    34    35    36    37
               @29,  @18,  @19,  @20,  @21,  @23,  @22,  @26,
               // 19 1A    0C    00    01     02   03    04
               @126, @125, @115, @122, @120,  @99, @118, @96,
               // 20 1B    09    0A    0D    1F    08    18
               @49,  @53,  @48,  @76,  @36,  @117, @123, @124
               ];

	chr1Map = @"XYZ[\\]^_PQRSTUVWHIJKLMNO@ABCDEFG89:;,-./01234567 \x1B\t\x03\r";
	chr2Map = @"ЬЫЗШЭЩЧ\x7FПЯРСТУЖВХИЙКЛМНОЮАБЦДЕФГ()*+<=>? !\"#$%&' \x1B\t\x03\r";

	RUSLAT = 0x20;
	SHIFT = 0x80;
}

// ---------------------------------------------------------------------------------------------------------------------

- (void)setC:(uint8_t)data
{
	Microsha *microsha = (Microsha *)self.computer;
	uint64_t clock = microsha.clock;
	X8253 *snd = microsha.snd;

	[snd setBeeper:data & 0x02 clock:clock];
	[snd setGate2:data & 0x04 clock:clock];
	snd.channel2 = data & 0x02;

	[super setC:data];
}

@end
