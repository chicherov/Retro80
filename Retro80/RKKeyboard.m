#import "RKKeyboard.h"

// -----------------------------------------------------------------------------
// Клавиатура РК86 на 8255
// -----------------------------------------------------------------------------

@implementation RKKeyboard
{
	NSTimeInterval keyboard[64];
	NSDictionary *keyCode;

	NSTimeInterval _down;
	BOOL _ruslat;
	uint8_t _key;

	NSData *clipboard;
	NSUInteger length;
	const char *paste;

	unsigned count;
}

// -----------------------------------------------------------------------------
// flagsChanged
// -----------------------------------------------------------------------------

- (void) flagsChanged:(NSEvent*)theEvent
{
	if (RUSLAT >= 0x10 ? _mode.H : _mode.L)
	{
		NSUInteger flags = [theEvent modifierFlags];

		_ruslat = (flags & NSAlternateKeyMask) != 0;

		_C &= ~(RUSLAT | CTRL | SHIFT);

		if (!(flags & (RUSLAT >= 0x10 ? NSAlternateKeyMask : NSAlphaShiftKeyMask)))
			_C |= RUSLAT;

		if (!(flags & NSControlKeyMask))
			_C |= CTRL;

		if (!(flags & NSShiftKeyMask))
			_C |= SHIFT;
	}
}

// -----------------------------------------------------------------------------
// keyDown
// -----------------------------------------------------------------------------

- (void) keyDown:(NSEvent*)theEvent
{
	if ((theEvent.modifierFlags & NSCommandKeyMask) == 0)
	{
		NSUInteger key = [kbdmap indexOfObject:[NSNumber numberWithShort:theEvent.keyCode]];

		if (key != NSNotFound && key < 64)
			keyboard[key] = theEvent.timestamp;

		NSNumber* ch = [keyCode objectForKey:[NSNumber numberWithShort:theEvent.keyCode]];

		if (ch != nil)
		{
			_down = theEvent.timestamp;
			_key = [ch charValue];
		}

		else
		{
			const char* ptr = [theEvent.characters.uppercaseString cStringUsingEncoding:(NSStringEncoding) 0x80000A02];

			if (ptr && *(uint8_t *)ptr <= 0x7F | *(uint8_t *)ptr >= 0xE0)
			{
				_key = *(uint8_t *)ptr & 0x7F;
				_down = theEvent.timestamp;
			}
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
	NSUInteger key = [kbdmap indexOfObject:[NSNumber numberWithShort:[theEvent keyCode]]];

	if (key != NSNotFound && key < 64)
		keyboard[key] = 0;

	_down = 0;
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
			if (_key == 0xFF)
			{
				if ((_key = *paste & 0x7F) == '\n')
					_key = 0x0D;

				paste++; length--;
				return _key;
			}

			if ((_key = *paste & 0x7F) == '\n')
				_key = 0x0D;

			if (++count < 23)
				return _key;

			if (count > 30)
			{
				paste++; length--;
				count = 0;
			}

			return 0xFF;
		}
	}

	return _ruslat ? 0xFE : _down > [NSProcessInfo processInfo].systemUptime - 0.7 ? _key : 0xFF;
}

- (void) setKey:(uint8_t)key
{
	_key = key;
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
	if (_mode.A == 1 && _mode.B == 0)
	{
		_A = 0xFF; for (int i = 0; i < 64; i++) if (keyboard[i])
		{
			if (keyboard[i] > [NSProcessInfo processInfo].systemUptime - 0.7)
			{
				if ((_B & (0x01 << (i & 0x07))) == 0)
					_A &= (0x80 >> (i >> 3)) ^ 0xFF;
			}
			else
			{
				keyboard[i] = 0;
			}
		}
	}

	return _A;
}

// -----------------------------------------------------------------------------
// Порт B
// -----------------------------------------------------------------------------

- (uint8_t) B
{
	if (_mode.A == 0 && _mode.B == 1)
	{
		_B = 0xFF; for (int i = 0; i < 64; i++) if (keyboard[i])
		{
			if (keyboard[i] > [NSProcessInfo processInfo].systemUptime - 0.7)
			{
				if ((_A & (0x80 >> (i >> 3))) == 0)
					_B &= (0x01 << (i & 0x07)) ^ 0xFF;
			}
			else
			{
				keyboard[i] = 0;
			}
		}
	}

	return _B;
}

// -----------------------------------------------------------------------------
// Порт C
// -----------------------------------------------------------------------------

- (uint8_t) C
{
	return _snd ? _C = (_C & 0xEF) | (_snd.input ? 0x00 : 0x10) : _C;
}

- (void) setC:(uint8_t)C
{
	if (_snd && (C ^ _C) & 0x01)
		_snd.output = C & 0x01 ? TRUE : FALSE;

	_C = C;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		keyCode = @{@115: @0x0C, @117: @0x1F, @122: @0x00, @120: @0x01,
					@99:  @0x02, @118: @0x03, @96:  @0x04, @76:  @0x0A,
					@123: @0x08, @126: @0x19, @124: @0x18, @125: @0x1A
					};

		kbdmap = @[@7,   @16,  @6,   @33,  @42,  @30,  @39,  @49,
				   @35,  @12,  @15,  @1,   @17,  @32,  @9,   @13,
				   @4,   @34,  @38,  @40,  @37,  @46,  @45,  @31,
				   @41,  @0,   @11,  @8,   @2,   @14,  @3,   @5,
				   @28,  @25,  @24,  @50,  @43,  @27,  @47,  @44,
				   @29,  @18,  @19,  @20,  @21,  @23,  @22,  @26,
				   @48,  @76,  @36,  @51,  @123, @126, @124, @125,
				   @115, @117, @53,  @122, @120, @99,  @118, @96,
				   ];

		RUSLAT = 0x80;
		SHIFT = 0x20;
		CTRL = 0x40;
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

- (id) initWithRKKeyboard:(RKKeyboard *)kbd
{
	if (self = [super init])
	{
		keyboard = kbd;
	}

	return self;
}

- (int) execute:(X8080 *)cpu
{
	if (_enabled)
	{
		if (count--)
			return 0;

		uint8_t key = keyboard.key;

		if (key == 0xFE)
		{
			count = 10;
			return 0;
		}

		if (key != 0xFF)
		{
			cpu.A = key;
			count = 450;
		}
		else
		{
			cpu.A = 0xFF;
			count = 35;
		}

		if (keyboard.isPaste)
			count = 1;

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
	uint8_t _key;
}

- (id) initWithRKKeyboard:(RKKeyboard *)kbd
{
	if (self = [super init])
	{
		keyboard = kbd;
		_key = 0xFF;
	}

	return self;
}

- (int) execute:(X8080 *)cpu
{
	if (_enabled)
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

- (void) setKey:(uint8_t)key
{
	_key = key;
}

- (uint8_t) key
{
	if (_key >= 0xFE)
		_key = keyboard.key;

	keyboard.key = 0xFF;
	return _key;
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
