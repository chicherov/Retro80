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
	keyboard[60] = (modifierFlags & NSAlternateKeyMask) != 0;

	uint8_t data = 0xFF; for (int i = 0; i < 72; i++) if (keyboard[i])
	{
		if (i % 12 > 3 && (B & (0x80 >> (i / 12))) == 0)
			data &= (0x80 >> (i % 12 - 4)) ^ 0xFF;
	}

	return data;
}


// -----------------------------------------------------------------------------
// Порт B
// -----------------------------------------------------------------------------

- (uint8_t) B
{
	keyboard[60] = (modifierFlags & NSAlternateKeyMask) != 0;

	uint8_t data = 0xFF; for (int i = 0; i < 72; i++) if (keyboard[i])
	{
		if (((((C & 0x0F) << 8) | A) & (0x800 >> (i % 12))) == 0)
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
		self.crt.color = ~(((data >> 1) & 0x60) | (data & 0x10) | 0x07);
}

// -----------------------------------------------------------------------------

- (uint8_t) C
{
	keyboard[60] = (modifierFlags & NSAlternateKeyMask) != 0;

	uint8_t data = 0xFF; for (int i = 0; i < 72; i++) if (keyboard[i])
	{
		if (i % 12 < 4 && (B & (0x80 >> (i / 12))) == 0)
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
	}

	return self;
}

@end