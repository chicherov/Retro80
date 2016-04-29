/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Микроша»

 *****/

#import "Microsha.h"

@implementation Microsha

+ (NSString *) title
{
	return @"Микроша";
}

+ (NSArray *) extensions
{
	return @[@"rkm"];
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(colorModule:))
	{
		menuItem.state = self.isColor;
		return YES;
	}

	if (menuItem.action == @selector(extraMemory:))
	{
		if (menuItem.tag == 0)
		{
			menuItem.state = self.ram.length == 0xC000;
			menuItem.submenu = nil;
			return YES;
		}
	}

	if (menuItem.action == @selector(floppy:))
	{
		if (menuItem.tag == 0)
		{
			menuItem.state = self.fdd != nil;
			return YES;
		}
		else
		{
			NSURL *url = [self.fdd getDisk:menuItem.tag]; if ((menuItem.state = url != nil))
				menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingFormat:@": %@", url.lastPathComponent];
			else
				menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingString:@":"];

			return self.fdd != nil && menuItem.tag != [self.fdd selected];
		}
	}

	return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Модуль цветности
// -----------------------------------------------------------------------------

static uint32_t colors[] =
{
	0xFFFFFFFF, 0xFFFF00FF, 0xFFFFFFFF, 0xFFFF00FF,
	0xFFFFFF00, 0xFFFF0000, 0xFFFFFF00, 0xFFFF0000,
	0xFF00FFFF, 0xFF0000FF, 0xFF00FFFF, 0xFF0000FF,
	0xFF00FF00, 0xFF000000, 0xFF00FF00, 0xFF000000
};

- (IBAction) colorModule:(NSMenuItem *)menuItem
{
	[self.document registerUndoWithMenuItem:menuItem];

	if ((self.isColor = !self.isColor))
	{
		if (self.rom.length > 0x42 && self.rom.mutableBytes[0x42] == 0x93)
			self.rom.mutableBytes[0x42] = 0xD3;

		[self.crt setColors:colors attributesMask:0x3F shiftMask:0x22];
	}
	else
	{
		if (self.rom.length > 0x42 && self.rom.mutableBytes[0x42] == 0xD3)
			self.rom.mutableBytes[0x42] = 0x93;

		[self.crt setColors:NULL attributesMask:0x22 shiftMask:0x22];
	}
}

// -----------------------------------------------------------------------------
// Модуль ОЗУ
// -----------------------------------------------------------------------------

- (IBAction) extraMemory:(NSMenuItem *)menuItem
{
	@synchronized(self.cpu)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		RAM *ram = [[RAM alloc] initWithLength:self.ram.length == 0x8000 ? 0xC000 : 0x8000 mask:0xFFFF];
		memcpy(ram.mutableBytes, self.ram.mutableBytes, 0x8000);
		[self.cpu mapObject:self.ram = ram from:0x0000 to:0xBFFF];
	}
}

// -----------------------------------------------------------------------------
// Модуль НГМД
// -----------------------------------------------------------------------------

- (IBAction) floppy:(NSMenuItem *)menuItem;
{
	if (menuItem.tag == 0) @synchronized(self.cpu)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		if (self.fdd == nil)
		{
			if ((self.fdd = [[Floppy alloc] init]) != nil)
			{
				if ((self.dos = [[ROM alloc] initWithContentsOfResource:@"dos29" mask:0x0FFF]) != nil)
				{
					if (self.dos.length > 0xDBF && self.dos.mutableBytes[0xDBF] == 0xC1)
						self.dos.mutableBytes[0xDBF] = 0xD1;

					[self.cpu mapObject:self.dos from:0xE000 to:0xEFFF WR:nil];
					[self.cpu mapObject:self.fdd from:0xF000 to:0xF7FF];
				}
				else
				{
					self.fdd = nil;
				}
			}
		}
		else
		{
			[self.cpu mapObject:nil from:0xE000 to:0xF7FF];

			self.fdd = nil;
			self.dos = nil;
		}
	}

	else if (self.fdd != nil)
	{
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		panel.allowedFileTypes = @[@"rkdisk"];
		panel.canChooseDirectories = FALSE;
		panel.title = menuItem.title;

		if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
		{
			[self.document registerUndoWithMenuItem:menuItem];
			[self.fdd setDisk:menuItem.tag URL:panel.URLs.firstObject];
		}
		else if ([self.fdd getDisk:menuItem.tag] != nil)
		{
			[self.document registerUndoWithMenuItem:menuItem];
			[self.fdd setDisk:menuItem.tag URL:nil];
		}
	}
}

// -----------------------------------------------------------------------------
// createObjects/encodeWithCoder/decodeWithCoder
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Microsha" mask:0x07FF]) == nil)
		return FALSE;

	if ((self.kbd = [[MicroshaKeyboard alloc] init]) == nil)
		return FALSE;

	if ((self.ext = [[MicroshaExt alloc] init]) == nil)
		return FALSE;

	if (![super createObjects])
		return FALSE;

	[self.crt selectFont:0x0C00];

	return TRUE;
}

// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];

	if (self.fdd != nil)
	{
		[encoder encodeObject:self.fdd forKey:@"fdd"];
		[encoder encodeObject:self.dos forKey:@"dos"];
	}
}

// -----------------------------------------------------------------------------

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
	if (![super decodeWithCoder:decoder])
		return FALSE;

	if ((self.fdd = [decoder decodeObjectForKey:@"fdd"]) != nil)
	{
		if ((self.dos = [decoder decodeObjectForKey:@"dos"]) == nil)
			return FALSE;
	}

	return TRUE;
}

// -----------------------------------------------------------------------------
// mapObjects
// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	if (self.isColor)
		[self.crt setColors:colors attributesMask:0x3F shiftMask:0x22];
	else
		[self.crt setColors:NULL attributesMask:0x22 shiftMask:0x22];

	self.ext.crt = self.crt;

	if (self.inpHook == nil)
	{
		self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
		self.inpHook.mem = self.rom;
		self.inpHook.snd = self.snd;

		self.inpHook.extension = @"rkm";
		self.inpHook.type = 2;
	}

	if (self.outHook == nil)
	{
		self.outHook = [[MicroshaF80C alloc] initWithX8080:self.cpu];
		self.outHook.mem = self.rom;
		self.outHook.snd = self.snd;

		self.outHook.extension = @"rkm";
		self.outHook.type = 2;
	}

	[self.cpu mapObject:self.ram from:0x0000 to:0xBFFF];
	[self.cpu mapObject:self.kbd from:0xC000 to:0xC7FF];
	[self.cpu mapObject:self.ext from:0xC800 to:0xCFFF];
	[self.cpu mapObject:self.crt from:0xD000 to:0xD7FF];
	[self.cpu mapObject:self.snd from:0xD800 to:0xDFFF];
	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF WR:self.dma];

	[self.cpu mapObject:self.inpHook from:0xFC0D to:0xFC0D WR:self.dma];
	[self.cpu mapObject:self.outHook from:0xFCAB to:0xFCAB WR:self.dma];
	[self.cpu mapObject:self.outHook from:0xF89A to:0xF89A WR:self.dma];

	if (self.fdd != nil)
	{
		[self.cpu mapObject:self.dos from:0xE000 to:0xEFFF WR:nil];
		[self.cpu mapObject:self.fdd from:0xF000 to:0xF7FF];
	}

	return [super mapObjects];
}

@end

// -----------------------------------------------------------------------------
// Первый интерфейс ВВ55, вариант клавиатуры РК86 для Микроши
// -----------------------------------------------------------------------------

@implementation MicroshaKeyboard

- (void) keyboardInit
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

// -----------------------------------------------------------------------------

- (void) setC:(uint8_t)data
{
	[self.snd setBeeper:self.snd.channel2 = data & 0x02 clock:current];
	[self.snd setGate2:data & 0x04 clock:current];

	[super setC:data];
}

@end

// -----------------------------------------------------------------------------
// Второй интерфейс ВВ55, управление знакогенератором
// -----------------------------------------------------------------------------

@implementation MicroshaExt

@synthesize crt;

- (void) setB:(uint8_t)data
{
	[crt selectFont:data & 0x80 ? 0x2800 : 0x0C00];
}

// -----------------------------------------------------------------------------

- (uint8_t) A
{
	return 0x00;
}

- (uint8_t) B
{
	return 0x00;
}

- (uint8_t) C
{
	return 0x00;
}

@end

// -----------------------------------------------------------------------------
// Вывод байта на магнитофон (Микроша)
// -----------------------------------------------------------------------------

@implementation MicroshaF80C
{
	BOOL disable;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if (self.cpu.M1 && (addr == 0xF89A || disable))
	{
		disable = addr == 0xF89A; [self.mem RD:addr data:data CLK:clock];
	}

	else
	{
		[super RD:addr data:data CLK:clock];
	}
}

@end
