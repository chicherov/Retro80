#import "RKKeyboard.h"

// -----------------------------------------------------------------------------
// Клавиатура РК86 на 8255
// -----------------------------------------------------------------------------

@implementation RKKeyboard
{
	NSString *paste;
	NSUInteger pos;

	uint64_t pasteClock;
	NSUInteger pasteKey;
}

@synthesize qwerty;
@synthesize snd;

// -----------------------------------------------------------------------------
// flagsChanged
// -----------------------------------------------------------------------------

- (void) flagsChanged:(NSEvent*)theEvent
{
	if ((theEvent.modifierFlags & NSCommandKeyMask) == 0)
	{
		if (ignoreShift)
			modifierFlags = (theEvent.modifierFlags & ~NSShiftKeyMask) | (modifierFlags & NSShiftKeyMask);
		else
			modifierFlags = theEvent.modifierFlags;
	}
}

// -----------------------------------------------------------------------------
// keyDown
// -----------------------------------------------------------------------------

- (void) keyDown:(NSEvent*)theEvent
{
	if ((theEvent.modifierFlags & NSCommandKeyMask) == 0) @synchronized(self)
	{
		paste = nil;

		unsigned short keyCode = theEvent.keyCode + 1; if (qwerty)
		{
			if (theEvent.charactersIgnoringModifiers.length)
			{
				NSString *chr = upperCase ? theEvent.charactersIgnoringModifiers.uppercaseString : theEvent.charactersIgnoringModifiers;

				NSUInteger index = [chr1Map rangeOfString:chr].location;

				if (index != NSNotFound && index < 72)
				{
					if (chr2Map.length <= index || [chr2Map characterAtIndex:index] != [chr1Map characterAtIndex:index])
					{
						modifierFlags = theEvent.modifierFlags & ~NSShiftKeyMask; ignoreShift = TRUE;
					}
					else if (ignoreShift)
					{
						modifierFlags = (theEvent.modifierFlags & ~NSShiftKeyMask) | (modifierFlags & NSShiftKeyMask);
					}
					else
					{
						modifierFlags = theEvent.modifierFlags;
					}

					keyboard[index] = keyCode;
					return;
				}

				index = [chr2Map rangeOfString:chr].location;

				if (index != NSNotFound && index < 72)
				{
					modifierFlags = theEvent.modifierFlags | NSShiftKeyMask; ignoreShift = TRUE;
					keyboard[index] = keyCode;
					return;
				}
			}
		}

		else
		{
			NSUInteger index = [kbdmap indexOfObject:[NSNumber numberWithShort:keyCode - 1]];

			if (index != NSNotFound && index < 72)
			{
				modifierFlags = theEvent.modifierFlags;
				keyboard[index] = keyCode;
			}
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
		if ((theEvent.modifierFlags & NSCommandKeyMask) == 0) @synchronized(self)
		{
			unsigned short keyCode = theEvent.keyCode + 1; for (int i = 0; i < 72; i++)
			{
				if (keyboard[i] == keyCode)
				{
					ignoreShift = FALSE;
					keyboard[i] = 0;
				}
			}
		}
	}

	else
	{
		modifierFlags = theEvent.modifierFlags;
		memset(keyboard, 0, sizeof(keyboard));
		ignoreShift = FALSE;
	}
}

// -----------------------------------------------------------------------------
// paste
// -----------------------------------------------------------------------------

- (void) paste:(NSString *)string
{
	@synchronized(self)
	{
		paste = upperCase ? string.uppercaseString : string;
		pos = 0; pasteClock = 0; pasteKey = NSNotFound;
	}
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------

- (void) scan:(uint64_t)clock
{
	@synchronized(self)
	{
		if (pasteKey != NSNotFound && pasteKey < 72 && clock - pasteClock > 1000000)
		{
			modifierFlags &= !NSShiftKeyMask;
			keyboard[pasteKey] = FALSE;
			pasteKey = NSNotFound;
		}

		if (paste != nil && clock - pasteClock > 3000000)
		{
			if (pos == paste.length)
				paste = nil;

			else
			{
				NSString *chr = [paste substringWithRange:NSMakeRange(pos++, 1)];

				if ([chr isEqualToString:@"\n"])
					chr = @"\r";

				if ((pasteKey = [chr1Map rangeOfString:chr].location) != NSNotFound && pasteKey < 72)
				{
					modifierFlags &= !NSShiftKeyMask;
					keyboard[pasteKey] = TRUE;
				}

				else if ((pasteKey = [chr2Map rangeOfString:chr].location) != NSNotFound && pasteKey < 72)
				{
					modifierFlags |= NSShiftKeyMask;
					keyboard[pasteKey] = TRUE;
				}

				pasteClock = clock;
			}
		}
	}
}

// -----------------------------------------------------------------------------
// Порт A
// -----------------------------------------------------------------------------

- (uint8_t) A
{
	[self scan:current];

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
	[self scan:current];

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
	[self scan:current];

	uint8_t data = 0xFF & ~(RUSLAT | CTRL | SHIFT | TAPEI);

	if (!(modifierFlags & NSAlternateKeyMask))
		data |= RUSLAT;

	if (!(modifierFlags & NSControlKeyMask))
		data |= CTRL;

	if (!(modifierFlags & NSShiftKeyMask))
		data |= SHIFT;

	if (snd.sound.input)
		data |= TAPEI;

	return data;
}

- (void) setC:(uint8_t)data
{
	if (TAPEO)
		snd.sound.output = data & TAPEO ? TRUE : FALSE;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (void) keyboardInit
{
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

	chr1Map = @"XYZ[\\]^ PQRSTUVWHIJKLMNO@ABCDEFG89:;,-./01234567\t\x03\r\x7F\x1B";
	chr2Map = @"ЬЫЗШЭЩЧ ПЯРСТУЖВХИЙКЛМНОЮАБЦДЕФГ()*+<=>? !\"#$%&'\t\x03\r\x7F\x1B";
	upperCase = TRUE;

	RUSLAT = 0x80;
	SHIFT = 0x20;
	CTRL = 0x40;

	TAPEI = 0x10;
	TAPEO = 0x01;
}

- (id) init
{
	if (self = [super init])
	{
		[self keyboardInit];
		qwerty = TRUE;
	}

	return self;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	[encoder encodeBool:qwerty forKey:@"qwerty"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		qwerty = [decoder decodeBoolForKey:@"qwerty"];
		[self keyboardInit];
	}

	return self;
}

@end
