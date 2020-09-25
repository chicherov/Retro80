/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Клавиатура РК86 на 8255

 *****/

#import "RKKeyboard.h"
#import "Sound.h"

@implementation RKKeyboard
{
	NSString *paste;
	NSUInteger pos;

	uint64_t pasteClock;
	NSUInteger pasteKey;
}

@synthesize qwerty;

- (void)flagsChanged:(NSEvent *)theEvent
{
	if ((theEvent.modifierFlags & NSCommandKeyMask) == 0)
	{
		if (ignoreShift)
			modifierFlags = (theEvent.modifierFlags & ~NSShiftKeyMask) | (modifierFlags & NSShiftKeyMask);
		else
			modifierFlags = theEvent.modifierFlags;
	}
}

- (void)keyDown:(NSEvent *)theEvent
{
	if ((theEvent.modifierFlags & NSCommandKeyMask) != 0)
		return;

	@synchronized (self)
	{
		NSUInteger index;

		if (qwerty)
		{
			if (theEvent.charactersIgnoringModifiers.length)
			{
				NSString *chr = theEvent.charactersIgnoringModifiers;
				if (upperCase) chr = chr.uppercaseString;

				if ((index = [chr1Map rangeOfString:chr].location) != NSNotFound)
				{
					if (chr2Map.length <= index || [chr2Map characterAtIndex:index] != [chr1Map characterAtIndex:index])
					{
						modifierFlags = theEvent.modifierFlags & ~NSShiftKeyMask; ignoreShift = YES;
					}
					else if (ignoreShift)
					{
						modifierFlags = (theEvent.modifierFlags & ~NSShiftKeyMask) | (modifierFlags & NSShiftKeyMask);
					}
					else
					{
						modifierFlags = theEvent.modifierFlags;
					}

					if (index < 72)
					{
						keyboard[index] = theEvent.keyCode + 1; paste = nil;
					}
				}

				else if ((index = [chr2Map rangeOfString:chr].location) != NSNotFound)
				{
					modifierFlags = theEvent.modifierFlags | NSShiftKeyMask; ignoreShift = YES;

					if (index < 72)
					{
						keyboard[index] = theEvent.keyCode + 1; paste = nil;
					}
				}
			}
		}

		else if ((index = [kbdmap indexOfObject:@(theEvent.keyCode)]) != NSNotFound)
		{
			modifierFlags = theEvent.modifierFlags;

			if (index < 72)
			{
				keyboard[index] = theEvent.keyCode + 1; paste = nil;
			}
		}
	}
}

- (void) keyUp:(NSEvent*)theEvent
{
	if ((theEvent.modifierFlags & NSCommandKeyMask) != 0)
		return;

	@synchronized (self)
	{
		unsigned short keyCode = theEvent.keyCode + 1;

		if (keyCode)
		{
			for (int i = 0; i < 72; i++)
			{
				if (keyboard[i] == keyCode)
				{
					ignoreShift = NO;
					keyboard[i] = 0;
				}
			}
		}
		else
		{
			memset(keyboard, 0, sizeof(keyboard));
			ignoreShift = NO;
			modifierFlags = 0;
		}
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (sel_isEqual(menuItem.action, @selector(paste:)))
		return [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString] != nil;

	if (menuItem.action == @selector(qwerty:))
	{
		menuItem.state = qwerty;
		return YES;
	}

	return NO;
}

- (IBAction) qwerty:(id)sender
{
	qwerty = !qwerty;
}

- (IBAction) paste:(NSMenuItem *)menuItem
{
	[self.computer registerUndoWithMenuItem:menuItem];
	[self pasteString:[[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString]];
}

- (void)pasteString:(NSString *)string
{
	@synchronized (self)
	{
		paste = upperCase ? string.uppercaseString : string;
		pasteClock = self.computer.clock;
		pos = 0; pasteKey = NSNotFound;
	}
}

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	@synchronized (self)
	{
		if (pasteKey != NSNotFound && pasteKey < 72 && clock - pasteClock > 1000000)
		{
			modifierFlags &= ~NSShiftKeyMask;
			keyboard[pasteKey] = NO;
			pasteKey = NSNotFound;
		}

		if (paste != nil && clock - pasteClock > 3000000)
		{
			NSString *chr = [paste substringWithRange:NSMakeRange(pos, 1)];

			if ([chr isEqualToString:@"\n"])
				chr = @"\r";

			if ((pasteKey = [chr1Map rangeOfString:chr].location) != NSNotFound && pasteKey < 72)
			{
				modifierFlags &= ~NSShiftKeyMask;
				keyboard[pasteKey] = YES;
			}

			else if ((pasteKey = [chr2Map rangeOfString:chr].location) != NSNotFound && pasteKey < 72)
			{
				modifierFlags |= NSShiftKeyMask;
				keyboard[pasteKey] = YES;
			}

			if (++pos == paste.length)
				paste = nil;

			pasteClock = clock;
		}
	}

	[super RD:addr data:data CLK:clock];
}

- (uint8_t)A
{
	uint8_t data = 0xFF; for (int i = 0; i < 64; i++) if (keyboard[i])
	{
		if ((B & (0x01 << (i & 0x07))) == 0)
			data &= (0x80 >> (i >> 3)) ^ 0xFF;
	}

	return data;
}

- (uint8_t)B
{
	uint8_t data = 0xFF; for (int i = 0; i < 64; i++) if (keyboard[i])
	{
		if ((A & (0x80 >> (i >> 3))) == 0)
			data &= (0x01 << (i & 0x07)) ^ 0xFF;
	}

	return data;
}

- (uint8_t)C
{
	uint8_t data = 0xFF & ~(RUSLAT | CTRL | SHIFT | TAPEI);

	if (!(modifierFlags & NSAlternateKeyMask))
		data |= RUSLAT;

	if (!(modifierFlags & NSControlKeyMask))
		data |= CTRL;

	if (!(modifierFlags & NSShiftKeyMask))
		data |= SHIFT;

	if (TAPEI && [self.computer.sound input:self.computer.clock])
		data |= TAPEI;

	return data;
}

- (void)setC:(uint8_t)data
{
	if ((C ^ data) & TAPEO)
		[self.computer.snd setOutput:data & TAPEO clock:self.computer.clock];
}

- (void)keyboardInit
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
	upperCase = YES;

	RUSLAT = 0x80;
	SHIFT = 0x20;
	CTRL = 0x40;

	TAPEI = 0x10;
	TAPEO = 0x01;
}

- (instancetype)init
{
	if (self = [super init])
	{
		[self keyboardInit];
		qwerty = YES;
	}

	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
	[coder encodeBool:qwerty forKey:@"qwerty"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if (self = [super initWithCoder:coder])
	{
		qwerty = [coder decodeBoolForKey:@"qwerty"];
		[self keyboardInit];
	}

	return self;
}

@end
