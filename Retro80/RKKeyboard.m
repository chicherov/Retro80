#import "RKKeyboard.h"

// -----------------------------------------------------------------------------
// Клавиатура РК86 на 8255
// -----------------------------------------------------------------------------

@implementation RKKeyboard
{
	NSDictionary *kbdCode;

	uint8_t key;

	NSData *clipboard;
	const char *paste;
	NSUInteger length;

	unsigned count;
}

@synthesize snd;

// -----------------------------------------------------------------------------
// flagsChanged
// -----------------------------------------------------------------------------

- (void) flagsChanged:(NSEvent*)theEvent
{
	modifierFlags = [theEvent modifierFlags];
}

// -----------------------------------------------------------------------------
// keyDown
// -----------------------------------------------------------------------------

- (void) keyDown:(NSEvent*)theEvent
{
	if (((modifierFlags = theEvent.modifierFlags) & NSCommandKeyMask) == 0)
	{
		NSNumber *keyCode = [NSNumber numberWithShort:theEvent.keyCode];

		NSUInteger index = [kbdmap indexOfObject:keyCode];

		if (index != NSNotFound && index < 72)
			keyboard[index] = TRUE;

		NSNumber* fkey = [kbdCode objectForKey:keyCode];

		if (fkey != nil)
		{
			if (index != NSNotFound)
				key = [fkey charValue];
		}

		else
		{
			const uint8_t *ptr = (const uint8_t *)[theEvent.characters.uppercaseString cStringUsingEncoding:(NSStringEncoding) 0x80000A02];

			if (ptr && (*ptr <= 0x5F || *ptr >= 0xE0))
				key = *ptr & 0x7F;
		}

		@synchronized(self)
		{
			length = 0;
		}
	}
}

// -----------------------------------------------------------------------------
// keyUp
// -----------------------------------------------------------------------------

- (void) keyUp:(NSEvent*)theEvent
{
	if (theEvent)
	{
		NSUInteger index = [kbdmap indexOfObject:[NSNumber numberWithShort:[theEvent keyCode]]];

		if (index != NSNotFound && index < 72)
			keyboard[index] = FALSE;
	}
	else
	{
		for (int i = 0; i < 72; i++)
			keyboard[i] = FALSE;
	}

	key = 0xFF;
}

// -----------------------------------------------------------------------------
// paste
// -----------------------------------------------------------------------------

- (void) paste:(NSString *)string
{
	@synchronized(self)
	{
		clipboard = [[string uppercaseString] dataUsingEncoding:(NSStringEncoding) 0x80000A02];
		paste = clipboard.bytes; length = clipboard.length; count = 0;
	}
}

// -----------------------------------------------------------------------------
// Текущая нажатая клавиша для хука
// -----------------------------------------------------------------------------

- (uint8_t) key
{
	@synchronized(self)
	{
		if (length)
		{
			if ((key = *paste & 0x7F) == '\n')
				key = 0x0D;

			if (++count < 51)
				return key;

			if (count < 60)
				return 0xFF;

			count = 0; length--; paste++;
			return key = 0xFF;
		}
	}

	if ((modifierFlags & (RUSLAT >= 0x10 ? NSAlternateKeyMask : NSAlphaShiftKeyMask)))
		return 0xFE;

	return key;
}

- (void) setKey:(uint8_t)data
{
	key = data;
}

- (BOOL) isPaste
{
	return length != 0;
}

// -----------------------------------------------------------------------------
// Порт A
// -----------------------------------------------------------------------------

- (uint8_t) A
{
	uint8_t data = 0xFF; for (int i = 0; i < 64; i++) if (keyboard[i])
	{
		if ((B & (0x01 << (i & 0x07))) == 0)
			data &= (0x80 >> (i >> 3)) ^ 0xFF;
	}

	return data;
}

// -----------------------------------------------------------------------------
// Порт B
// -----------------------------------------------------------------------------

- (uint8_t) B
{
	uint8_t data = 0xFF; for (int i = 0; i < 64; i++) if (keyboard[i])
	{
		if ((A & (0x80 >> (i >> 3))) == 0)
			data &= (0x01 << (i & 0x07)) ^ 0xFF;
	}

	return data;
}

// -----------------------------------------------------------------------------
// Порт C
// -----------------------------------------------------------------------------

- (uint8_t) C
{
	uint8_t data = 0xFF & ~(RUSLAT | CTRL | SHIFT | TAPEI);

	if (!(modifierFlags & (RUSLAT >= 0x10 ? NSAlternateKeyMask : NSAlphaShiftKeyMask)))
		data |= RUSLAT;

	if (!(modifierFlags & NSControlKeyMask))
		data |= CTRL;

	if (!(modifierFlags & NSShiftKeyMask))
		data |= SHIFT;

	if (TAPEI && snd.sound.input)
		data |= TAPEI;

	return data;
}

- (void) setC:(uint8_t)data
{
	if (TAPEO)
		snd.sound.output = data & TAPEO ? TRUE : FALSE;

}

// -----------------------------------------------------------------------------
// RESET
// -----------------------------------------------------------------------------

- (void) RESET
{
	for (int i = 0; i < 72; i++)
		keyboard[i] = FALSE;

	modifierFlags = 0;
	key = 0xFF;

	[super RESET];
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		kbdCode = @{
					@123: @0x08, @124: @0x18, @126: @0x19, @125: @0x1A, @115: @0x0C,
					@36:  @0x0D, @76:  @0x0A, @53:  @0x1B, @48:  @0x09, @117: @0x1F,
					@122: @0x00, @120: @0x01, @99:  @0x02, @118: @0x03, @96:  @0x04,
					@51:  @0x7F
					};

		kbdmap = @[
				   // 58 59    5A    5B    5C    5D    5E    20
				   @46,  @1,   @35,  @34,  @39,  @31,  @7,   @49,
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
				   // 09 0A    0D    7F    08    19    18    1A
				   @48,  @76,  @36,  @51,  @123, @126, @124, @125,
				   // 0C 1F    1B    00    01    02    03    04
				   @115, @117, @53,  @122, @120, @99,  @118, @96
				   ];

		RUSLAT = 0x80;
		SHIFT = 0x20;
		CTRL = 0x40;

		TAPEI = 0x10;
		TAPEO = 0x01;
	}
	
	return self;
}

@end

// -----------------------------------------------------------------------------
// F81B - Ввод символа с клавиатуры без ожидания
// -----------------------------------------------------------------------------

@implementation F81B
{
	RKKeyboard* keyboard;
	unsigned count;
}

@synthesize enabled;

- (id) initWithRKKeyboard:(RKKeyboard *)kbd
{
	if (self = [super init])
		keyboard = kbd;

	return self;
}

- (int) execute:(X8080 *)cpu
{
	if (enabled)
	{
		if (count--)
			return 0;

		uint8_t key = keyboard.key;

		if (key == 0xFE)
		{
			count = 1;
			return 0;
		}

		count = keyboard.isPaste ? 1 : key == 0xFF ? 35 : 450;

		cpu.A = key;
		return 1;
	}

	return 2;
}

@end

// -----------------------------------------------------------------------------
// F812 - Опрос состояния клавиатуры
// -----------------------------------------------------------------------------

@implementation F812
{
	RKKeyboard* keyboard;
	unsigned count;
	uint8_t key;
}

@synthesize enabled;

- (id) initWithRKKeyboard:(RKKeyboard *)kbd
{
	if (self = [super init])
	{
		keyboard = kbd;
		key = 0xFF;
	}

	return self;
}

- (int) execute:(X8080 *)cpu
{
	if (enabled)
	{
		if (count--)
			return 0;

		if (self.key != 0xFF)
		{
			cpu.AF = 0xFF86;
			count = 10;
		}
		else
		{
			cpu.AF = 0x0046;
			count = 80;
		}

		return 1;
	}

	return 2;
}

- (void) setKey:(uint8_t)data
{
	while (keyboard.isPaste && key == keyboard.key);
	keyboard.key = key = data;
}

- (uint8_t) key
{
	key = keyboard.key;
	return key;
}

@end

// -----------------------------------------------------------------------------
// F803 - Ввод символа с клавиатуры с ожиданием ввода
// -----------------------------------------------------------------------------

@implementation F803
{
	F812 *keyboard;
}

- (id) initWithF812:(F812 *)kbd
{
	if (self = [super init])
	{
		keyboard = kbd;
	}

	return self;
}

- (int) execute:(X8080 *)cpu
{
	if (keyboard && keyboard.enabled)
	{
		uint8_t key = keyboard.key;

		if (key >= 0xFE)
			return 0;

		keyboard.key = 0xFF;
		cpu.A = key;
		return 1;
	}

	return 2;
}

@end
