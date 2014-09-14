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
		if (self.floppy)
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
		[self.crt setColors:colors attributeMask:0xFF];
	}
	else
	{
		*(uint8_t *)[self.rom bytesAtAddress:0xFADC] = 0x93;
		[self.crt setColors:NULL attributeMask:0x22];
	}
}

// -----------------------------------------------------------------------------
// Внешний ROM-диск
// -----------------------------------------------------------------------------

- (IBAction) ROMDisk:(NSMenuItem *)menuItem;
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.title = menuItem.title;
	panel.canChooseDirectories = FALSE;
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
			if (self.floppy == nil)
			{
				self.floppy = [[Floppy alloc] init];

				[self.cpu mapObject:self.dma atPage:0xE0 count:0x20];

				[self.cpu mapObject:self.floppy atPage:0xF0 count:0x08];
				[self.cpu mapObject:self.dos29 atPage:0xE0 count:0x10];
				[self.cpu mapObject:self.rom atPage:0xF8 count:0x08];
			}
			else
			{
				[self.cpu mapObject:self.dma atPage:0xE0 count:0x20];
				[self.cpu mapObject:self.rom atPage:0xF0 count:0x10];

				self.floppy = nil;
			}
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
	if ((self.ext = [[ROMDisk alloc] init]) == nil)
		return FALSE;

	if (![super createObjects])
		return FALSE;

	return TRUE;
}

// -----------------------------------------------------------------------------
// mapObjects
// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Radio86RK" mask:0x07FF]) == nil)
		return FALSE;

	if ((self.dos29 = [[ROM alloc] initWithContentsOfResource:@"dos29" mask:0x0FFF]) == nil)
		return FALSE;

	[self.crt setFontOffset:0x0C00];

	if (self.isColor)
	{
		*(uint8_t *)[self.rom bytesAtAddress:0xFADC] = 0xD3;
		[self.crt setColors:colors attributeMask:0xFF];
	}
	else
	{
		*(uint8_t *)[self.rom bytesAtAddress:0xFADC] = 0x93;
		[self.crt setColors:NULL attributeMask:0x22];
	}

	[self.cpu mapObject:self.ram atPage:0x00 count:0x80];
	[self.cpu mapObject:self.kbd atPage:0x80 count:0x20];
	[self.cpu mapObject:self.ext atPage:0xA0 count:0x20];
	[self.cpu mapObject:self.crt atPage:0xC0 count:0x20];
	[self.cpu mapObject:self.dma atPage:0xE0 count:0x20];
	[self.cpu mapObject:self.rom atPage:0xF0 count:0x10];

	self.cpu.INTE = self;

	[self.cpu mapHook:self.kbdHook = [[F81B alloc] initWithRKKeyboard:self.kbd] atAddress:0xF81B];

	[self.cpu mapHook:self.inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xF806];
	self.inpHook.readError = 0xFAAE;
	self.inpHook.extension = @"rkr";

	[self.cpu mapHook:self.outHook = [[F80C alloc] init] atAddress:0xF80C];
	self.outHook.extension = @"rkr";

	return TRUE;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	[encoder encodeObject:self.floppy forKey:@"floppy"];
}


- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		if ((self.floppy = [decoder decodeObjectForKey:@"floppy"]) != nil)
		{
			[self.cpu mapObject:self.dma atPage:0xE0 count:0x20];

			[self.cpu mapObject:self.floppy atPage:0xF0 count:0x08];
			[self.cpu mapObject:self.dos29 atPage:0xE0 count:0x10];
			[self.cpu mapObject:self.rom atPage:0xF8 count:0x08];
		}
	}

	return self;
}

@end
