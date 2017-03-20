/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Интерфейс клавиатуры ПЭВМ «Специалист»

 *****/

#import "SpecialistKeyboard.h"
#import "Specialist.h"
#import "Sound.h"

@implementation SpecialistKeyboard

@synthesize colorScheme;

- (uint8_t)A
{
	keyboard[60] = (modifierFlags & NSAlternateKeyMask) != 0;

	uint8_t data = 0xFF; for (int i = 0; i < 72; i++)
	{
		if (keyboard[i])
		{
			if (i%12 > 3 && ((mode.B ? 0xFF : B) & (0x80 >> (i/12))) == 0)
				data &= (0x80 >> (i%12 - 4)) ^ 0xFF;
		}
	}

	return data;
}

- (uint8_t)B
{
	keyboard[60] = (modifierFlags & NSAlternateKeyMask) != 0;

	uint8_t data = 0xFF; for (int i = 0; i < 72; i++)
	{
		if (keyboard[i])
		{
			if (((((mode.L ? 0x0F : C & 0x0F) << 8) | (mode.A ? 0xFF : A)) & (0x800 >> (i%12))) == 0)
				data &= (0x80 >> (i/12)) ^ 0xFF;
		}
	}

	if ([self.computer.sound input:self.computer.clock])
		data &= ~0x01;

	if ((modifierFlags & NSShiftKeyMask))
		data &= ~0x02;

	return data;
}

- (uint8_t)C
{
	keyboard[60] = (modifierFlags & NSAlternateKeyMask) != 0;

	uint8_t data = 0xFF; for (int i = 0; i < 72; i++)
	{
		if (keyboard[i])
		{
			if (i%12 < 4 && ((mode.B ? 0xFF : B) & (0x80 >> (i/12))) == 0)
				data &= (0x08 >> (i%12)) ^ 0xFF;
		}
	}

	return data;
}

- (void)setC:(uint8_t)data
{
	Specialist *specialist = (Specialist *) self.computer;

	if ((C ^ data) & 0x80)
		[specialist.snd setOutput:data & 0x80 clock:self.computer.clock];

	if ((C ^ data) & 0x20)
		[specialist.snd setBeeper:data & 0x20 clock:self.computer.clock];

	switch (colorScheme)
	{
		case 1:

			switch (data & 0xC0)
			{
				case 0x00:

					specialist.crt.color = 0x70;
					break;

				case 0x40:

					specialist.crt.color = 0x40;
					break;

				case 0x80:

					specialist.crt.color = 0x20;
					break;

				case 0xC0:

					specialist.crt.color = 0x10;
					break;
			}

			break;

		case 2:

			specialist.crt.color = ~(((data >> 1) & 0x60) | (data & 0x10) | 0x8F);
	}
}

- (void)keyboardInit
{
	[super keyboardInit];

	kbdmap = @[
		@122, @120, @99,  @118, @96,  @97,  @98,  @100, @101, @109, @103, @117,
		@10,  @18,  @19,  @20,  @21,  @23,  @22,  @26,  @28,  @25,  @29,  @27,
		@12,  @13,  @14,  @15,  @17,  @16,  @32,  @34,  @31,  @35,  @33,  @30,
		@0,   @1,   @2,   @3,   @5,   @4,   @38,  @40,  @37,  @41,  @39,  @42,
		@6,   @7,   @8,   @9,   @11,  @45,  @46,  @43,  @47,  @44,  @50,  @51,
		@999, @115, @126, @125, @48,  @53,  @49,  @123, @111, @124, @76,  @36
	];

	chr1Map = @";1234567890=JCUKENG[]ZH:FYWAPROLDV\\.Q^SMITXB@,/_\0\t\x1B \x03\r";
	chr2Map = @"+!\"#$%&'()\0-ЙЦУКЕНГШЩЗХ*ФЫВАПРОЛДЖЭ>ЯЧСМИТЬБЮ<?\0\0\t\x1B \x03\r";
}

@end
