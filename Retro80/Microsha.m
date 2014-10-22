/*******************************************************************************
 ПЭВМ «Микроша»
 ******************************************************************************/

#import "Microsha.h"

// -----------------------------------------------------------------------------
// Первый интерфейс 8255, вариант клавиатуры РК86 для Микроши
// -----------------------------------------------------------------------------

@implementation MicroshaKeyboard

- (id) init
{
	if (self = [super init])
	{
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

		RUSLAT = 0x20;
		SHIFT = 0x80;
	}

	return self;
}

// -----------------------------------------------------------------------------

- (void) setC:(uint8_t)data
{
	self.snd.channel2 = (data & 0x06) == 0x06 ? TRUE : FALSE;
	self.snd.beeper = data & 0x02 ? TRUE : FALSE;

	[super setC:data];
}

@end

// -----------------------------------------------------------------------------
// Второй интерфейс 8255, управление знакогенератором
// -----------------------------------------------------------------------------

@implementation MicroshaExt

- (void) setB:(uint8_t)data
{
	[self.crt selectFont:data & 0x80 ? 0x2800 : 0x0C00];
}

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
// FCAB - Вывод байта на магнитофон (Микроша)
// -----------------------------------------------------------------------------

@implementation FCAB

- (int) execute:(X8080 *)cpu
{
	if (cpu.SP == 0x76CD && MEMR(cpu, 0x76CD, 0) == 0x9D && MEMR(cpu, 0x76CE, 0) == 0xF8)
		return 2;

	return [super execute:cpu];
}

@end

// -----------------------------------------------------------------------------
// ПЭВМ Микроша
// -----------------------------------------------------------------------------

@implementation Microsha

+ (NSString *) title
{
	return @"Микроша";
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
		menuItem.state = self.isExtRAM;
		return YES;
	}

	if (menuItem.action == @selector(floppy:))
	{
		if (self.isFloppy)
		{
			menuItem.state = menuItem.tag == 0 || [self.floppy getDisk:menuItem.tag];
			return menuItem.tag == 0 || menuItem.tag != [self.floppy selected];
		}
		else
		{
			menuItem.state = FALSE; return menuItem.tag == 0;
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
		*(uint8_t *)[self.rom bytesAtAddress:0xF842] = 0xD3;
		[self.crt setColors:colors attributesMask:0x3F];
	}
	else
	{
		*(uint8_t *)[self.rom bytesAtAddress:0xF842] = 0x93;
		[self.crt setColors:NULL attributesMask:0x22];
	}
}

// -----------------------------------------------------------------------------
// Модуль ОЗУ
// -----------------------------------------------------------------------------

- (IBAction) extraMemory:(NSMenuItem *)menuItem
{
	[self.document registerUndoWithMenuItem:menuItem];

	@synchronized(self.snd)
	{
		if ((self.isExtRAM = !self.isExtRAM))
		{
			[self.cpu selectPage:1 from:0x8000 to:0xBFFF];
		}
		else
		{
			[self.cpu selectPage:0 from:0x8000 to:0xBFFF];
		}
	}
}

// -----------------------------------------------------------------------------
// Модуль НГМД
// -----------------------------------------------------------------------------

- (IBAction) floppy:(NSMenuItem *)menuItem;
{
	[self.document registerUndoWithMenuItem:menuItem];

	if (menuItem.tag == 0)
	{
		@synchronized(self.snd)
		{
			if ((self.isFloppy = !self.isFloppy))
				[self.cpu selectPage:1 from:0xE000 to:0xF7FF];
			else
				[self.cpu selectPage:0 from:0xE000 to:0xF7FF];
		}
	}
	else
	{
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		panel.title = menuItem.title;

		panel.allowedFileTypes = @[@"rkdisk", @"rkd"];
		panel.canChooseDirectories = FALSE;

		if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
		{
			[self.document registerUndoWithMenuItem:menuItem];
			[self.floppy setDisk:menuItem.tag URL:panel.URLs.firstObject];
		}
		else if ([self.floppy getDisk:menuItem.tag] != nil)
		{
			[self.document registerUndoWithMenuItem:menuItem];
			[self.floppy setDisk:menuItem.tag URL:nil];
		}
	}
}

// -----------------------------------------------------------------------------
// По сигналу RESET сбрасываем также контролерс НГМД
// -----------------------------------------------------------------------------

- (void) RESET
{
	[super RESET];
	[self.floppy RESET];
}

// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if ((self.rom = [[Memory alloc] initWithContentsOfResource:@"Microsha" mask:0x07FF]) == nil)
		return FALSE;

	if ((self.ram = [[Memory alloc] initWithLength:0xC000 mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.kbd = [[MicroshaKeyboard alloc] init]) == nil)
		return FALSE;

	if ((self.ext = [[MicroshaExt alloc] init]) == nil)
		return FALSE;

	if ((self.dos29 = [[Memory alloc] initWithContentsOfResource:@"dos29" mask:0x0FFF]) == nil)
		return FALSE;

	*(uint8_t *)[self.dos29 bytesAtAddress:0xEDBF] = 0xD1;
	
	if ((self.floppy = [[Floppy alloc] init]) == nil)
		return FALSE;

	if (![super createObjects])
		return FALSE;

	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) decodeObjects:(NSCoder *)decoder
{
	if (![super decodeObjects:decoder])
		return FALSE;

	if ((self.floppy = [decoder decodeObjectForKey:@"floppy"]) == nil)
		return FALSE;

	if ((self.dos29 = [decoder decodeObjectForKey:@"dos29"]) == nil)
		return FALSE;

	self.isExtRAM = [decoder decodeBoolForKey:@"isExtRAM"];
	self.isFloppy = [decoder decodeBoolForKey:@"isFloppy"];

	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	[self.ext.crt = self.crt selectFont:self.ext.B & 0x80 ? 0x2800 : 0x0C00];

	if (self.isColor)
	{
		*(uint8_t *)[self.rom bytesAtAddress:0xF842] = 0xD3;
		[self.crt setColors:colors attributesMask:0x3F];
	}
	else
	{
		*(uint8_t *)[self.rom bytesAtAddress:0xF842] = 0x93;
		[self.crt setColors:NULL attributesMask:0x22];
	}
	
	self.snd.channel2 = self.kbd.C & 0x04 ? TRUE : FALSE;
	
	[self.cpu mapObject:self.ram from:0x0000 to:0x7FFF];
	[self.cpu mapObject:self.kbd from:0xC000 to:0xC7FF];
	[self.cpu mapObject:self.ext from:0xC800 to:0xCFFF];
	[self.cpu mapObject:self.crt from:0xD000 to:0xD7FF];
	[self.cpu mapObject:self.snd from:0xD800 to:0xDFFF];
	[self.cpu mapObject:self.dma from:0xF800 to:0xFFFF WO:YES];
	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF RO:YES];

	[self.cpu mapObject:self.ram atPage:1 from:0x8000 to:0xBFFF];

	if (self.isExtRAM)
		[self.cpu selectPage:1 from:0x8000 to:0xBFFF];

	[self.cpu mapObject:self.dos29 atPage:1 from:0xE000 to:0xEFFF RO:YES];
	[self.cpu mapObject:self.floppy atPage:1 from:0xF000 to:0xF7FF];

	if (self.isFloppy)
		[self.cpu selectPage:1 from:0xE000 to:0xF7FF];

	[self.cpu mapHook:self.kbdHook = [[F81B alloc] initWithRKKeyboard:self.kbd] atAddress:0xFEEA];

	[self.cpu mapHook:self.inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xF806];
	self.inpHook.extension = @"rkm";
	self.inpHook.readError = 0xF8C7;
	self.inpHook.type = 2;

	[self.cpu mapHook:self.outHook = [[FCAB alloc] init] atAddress:0xFCAB];
	self.outHook.extension = @"rkm";

	return [super mapObjects];
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];

	[encoder encodeObject:self.floppy forKey:@"floppy"];
	[encoder encodeObject:self.dos29 forKey:@"dos29"];

	[encoder encodeBool:self.isExtRAM forKey:@"isExtRAM"];
	[encoder encodeBool:self.isFloppy forKey:@"isFloppy"];
}

@end
