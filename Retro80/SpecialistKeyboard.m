/*******************************************************************************
 * Интерфейс клавиатуры ПЭВМ «Специалист»
 ******************************************************************************/

#import "SpecialistKeyboard.h"

@implementation SpecialistKeyboard

// -----------------------------------------------------------------------------
// Порт A
// -----------------------------------------------------------------------------

- (uint8_t) A
{
	[self scan:current];

	keyboard[60] = (modifierFlags & NSAlternateKeyMask) != 0;

	uint8_t data = 0xFF; for (int i = 0; i < 72; i++) if (keyboard[i])
	{
		if (i % 12 > 3 && ((mode.B ? 0xFF : B) & (0x80 >> (i / 12))) == 0)
			data &= (0x80 >> (i % 12 - 4)) ^ 0xFF;
	}

	return data;
}


// -----------------------------------------------------------------------------
// Порт B
// -----------------------------------------------------------------------------

- (uint8_t) B
{
	[self scan:current];

	keyboard[60] = (modifierFlags & NSAlternateKeyMask) != 0;

	uint8_t data = 0xFF; for (int i = 0; i < 72; i++) if (keyboard[i])
	{
		if (((((mode.L ? 0x0F : C & 0x0F) << 8) | (mode.A ? 0xFF : A)) & (0x800 >> (i % 12))) == 0)
			data &= (0x80 >> (i / 12)) ^ 0xFF;
	}

	if ((modifierFlags & NSShiftKeyMask))
		data &= ~0x02;

	if (self.snd.sound.input)
		data &= ~0x01;

	return data;
}

// -----------------------------------------------------------------------------
// Порт C
// -----------------------------------------------------------------------------

- (void) setC:(uint8_t)data
{
	self.snd.sound.output = data & 0x80;
	self.snd.sound.beeper = data & 0x20;

	if (self.crt)
	{
		if (self.four)
		{
			switch (data & 0xC0)
			{
				case 0x00:

					self.crt.color = 0x70;
					break;

				case 0x40:

					self.crt.color = 0x40;
					break;

				case 0x80:

					self.crt.color = 0x20;
					break;

				case 0xC0:

					self.crt.color = 0x10;
					break;
			}
		}
		else
		{
			self.crt.color = ~(((data >> 1) & 0x60) | (data & 0x10) | 0x8F);
		}
	}
}

// -----------------------------------------------------------------------------

- (uint8_t) C
{
	[self scan:current];

	keyboard[60] = (modifierFlags & NSAlternateKeyMask) != 0;

	uint8_t data = 0xFF; for (int i = 0; i < 72; i++) if (keyboard[i])
	{
		if (i % 12 < 4 && ((mode.B ? 0xFF : B) & (0x80 >> (i / 12))) == 0)
			data &= (0x08 >> (i % 12)) ^ 0xFF;
	}

	return data;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
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

	return self;
}

@end
