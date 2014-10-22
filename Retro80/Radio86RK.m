/*******************************************************************************
 ПЭВМ «Радио-86РК»
 ******************************************************************************/

#import "Radio86RK.h"

@implementation Radio86RK

+ (NSString *) title
{
	return @"Радио-86РК";
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

	if (menuItem.action == @selector(ROMDisk:))
	{
		menuItem.state = self.ext.url != nil;
		return YES;
	}

	if (menuItem.action == @selector(floppy:))
	{
		if (self.isFloppy)
		{
			menuItem.state = menuItem.tag == 0 || [self.floppy getDisk:menuItem.tag] != nil;
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
	0xFFFFFFFF, 0xFF00FFFF, 0xFFFFFFFF, 0xFF00FFFF, 0xFFFFFF00, 0xFF00FF00, 0xFFFFFF00, 0xFF00FF00,
	0xFFFF00FF, 0xFF0000FF, 0xFFFF00FF, 0xFF0000FF, 0xFFFF0000, 0xFF000000, 0xFFFF0000, 0xFF000000
};

- (IBAction) colorModule:(NSMenuItem *)menuItem
{
	[self.document registerUndoWithMenuItem:menuItem];

	if ((self.isColor = !self.isColor))
	{
		*(uint8_t *)[self.rom bytesAtAddress:0xFADC] = 0xD3;
		[self.crt setColors:colors attributesMask:0x3F];
	}
	else
	{
		*(uint8_t *)[self.rom bytesAtAddress:0xFADC] = 0x93;
		[self.crt setColors:NULL attributesMask:0x22];
	}
}

// -----------------------------------------------------------------------------
// Внешний ROM-диск
// -----------------------------------------------------------------------------

- (IBAction) ROMDisk:(NSMenuItem *)menuItem;
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.title = menuItem.title;
	panel.canChooseDirectories = TRUE;
	panel.allowedFileTypes = @[@"rom"];

	if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
	{
		[self.document registerUndoWithMenuItem:menuItem];
		self.ext.url = panel.URLs.firstObject;
	}
	else if (self.ext.url != nil)
	{
		[self.document registerUndoWithMenuItem:menuItem];
		self.ext.url = nil;
	}
}

// -----------------------------------------------------------------------------
// Модуль НГМД
// -----------------------------------------------------------------------------

- (IBAction) floppy:(NSMenuItem *)menuItem;
{
	if (menuItem.tag == 0)
	{
		[self.document registerUndoWithMenuItem:menuItem];

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
// В Радио-86РК на INTE сидит звук
// -----------------------------------------------------------------------------

- (void) INTE:(BOOL)IF
{
	self.snd.beeper = IF;
}

// -----------------------------------------------------------------------------
// createObjects
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if ((self.rom = [[Memory alloc] initWithContentsOfResource:@"Radio86RK" mask:0x07FF]) == nil)
		return FALSE;

	if ((self.ext = [[ROMDisk alloc] init]) == nil)
		return FALSE;

	if ((self.dos29 = [[Memory alloc] initWithContentsOfResource:@"dos29" mask:0x0FFF]) == nil)
		return FALSE;

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

	self.isFloppy = [decoder decodeBoolForKey:@"isFloppy"];

	return TRUE;
}

// -----------------------------------------------------------------------------
// mapObjects
// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	[self.crt selectFont:0x0C00];

	if (self.isColor)
	{
		*(uint8_t *)[self.rom bytesAtAddress:0xFADC] = 0xD3;
		[self.crt setColors:colors attributesMask:0x3F];
	}
	else
	{
		*(uint8_t *)[self.rom bytesAtAddress:0xFADC] = 0x93;
		[self.crt setColors:NULL attributesMask:0x22];
	}

	self.cpu.INTE = self;

	[self.cpu mapObject:self.ram from:0x0000 to:0x7FFF];
	[self.cpu mapObject:self.kbd from:0x8000 to:0x9FFF];
	[self.cpu mapObject:self.ext from:0xA000 to:0xBFFF];
	[self.cpu mapObject:self.crt from:0xC000 to:0xDFFF];
	[self.cpu mapObject:self.dma from:0xE000 to:0xFFFF WO:YES];
	[self.cpu mapObject:self.rom from:0xF000 to:0xFFFF RO:YES];

	[self.cpu mapObject:self.dos29 atPage:1 from:0xE000 to:0xEFFF RO:YES];
	[self.cpu mapObject:self.floppy atPage:1 from:0xF000 to:0xF7FF];

	if (self.isFloppy)
		[self.cpu selectPage:1 from:0xE000 to:0xF7FF];

	[self.cpu mapHook:self.kbdHook = [[F81B alloc] initWithRKKeyboard:self.kbd] atAddress:0xF81B];

	[self.cpu mapHook:self.inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xF806];
	self.inpHook.readError = 0xFAAE;
	self.inpHook.extension = @"rkr";
	self.inpHook.type = 1;

	[self.cpu mapHook:self.outHook = [[F80C alloc] init] atAddress:0xF80C];
	self.outHook.extension = @"rkr";

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

	[encoder encodeBool:self.isFloppy forKey:@"isFloppy"];
}

@end
