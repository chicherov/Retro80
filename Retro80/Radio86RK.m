/*******************************************************************************
 ПЭВМ «Радио-86РК»
 ******************************************************************************/

#import "Radio86RK.h"

@implementation Radio86RK

+ (NSString *) title
{
	return @"Радио-86РК";
}

+ (NSString *) ext
{
	return @"rkr";
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
		menuItem.state = self.ext.length != 0;
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
	0xFFFFFFFF, 0xFF00FFFF, 0xFFFFFFFF, 0xFF00FFFF, 0xFFFFFF00, 0xFF00FF00, 0xFFFFFF00, 0xFF00FF00,
	0xFFFF00FF, 0xFF0000FF, 0xFFFF00FF, 0xFF0000FF, 0xFFFF0000, 0xFF000000, 0xFFFF0000, 0xFF000000
};

- (IBAction) colorModule:(NSMenuItem *)menuItem
{
	[self.document registerUndoWithMenuItem:menuItem];

	if ((self.isColor = !self.isColor))
	{
		if (self.rom.length > 0x2DC && self.rom.mutableBytes[0x2DC] == 0x93)
			self.rom.mutableBytes[0x2DC] = 0xD3;

		[self.crt setColors:colors attributesMask:0x3F shiftMask:0x00];
	}
	else
	{
		if (self.rom.length > 0x2DC && self.rom.mutableBytes[0x2DC] == 0xD3)
			self.rom.mutableBytes[0x2DC] = 0x93;

		[self.crt setColors:NULL attributesMask:0x22 shiftMask:0x00];
	}
}

// -----------------------------------------------------------------------------
// Внешний ROM-диск
// -----------------------------------------------------------------------------

- (IBAction) ROMDisk:(NSMenuItem *)menuItem;
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.allowedFileTypes = @[@"rom", @"bin"];
	panel.canChooseDirectories = TRUE;
	panel.title = menuItem.title;
	panel.delegate = self.ext;

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
	if (menuItem.tag == 0) @synchronized(self.snd.sound)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		if ((self.isFloppy = !self.isFloppy))
		{
			if (self.dos29 != nil || (self.dos29 = [[ROM alloc] initWithContentsOfResource:@"dos29" mask:0x0FFF]) != nil)
			{
				if (self.floppy == nil && (self.floppy = [[Floppy alloc] init]) != nil)
					[self.cpu addObjectToRESET:self.floppy];

				if (self.floppy)
				{
					[self.cpu mapObject:self.dos29 from:0xE000 to:0xEFFF WR:nil];
					[self.cpu mapObject:self.floppy from:0xF000 to:0xF7FF];
				}
			}

		}
		else
		{
			[self.cpu mapObject:self.rom from:0xE000 to:0xF7FF WR:self.dma];
		}
	}
	else if (menuItem.tag && self.isFloppy)
	{
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		panel.allowedFileTypes = @[@"rkdisk"];
		panel.canChooseDirectories = FALSE;
		panel.title = menuItem.title;

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
	self.snd.sound.beeper = IF;
}

// -----------------------------------------------------------------------------
// createObjects/encodeWithCoder/decodeWithCoder
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Radio86RK" mask:0x07FF]) == nil)
		return FALSE;

	if ((self.ext = [[ROMDisk alloc] init]) == nil)
		return FALSE;

	if ((self.snd = [[Radio86RK8253 alloc] init]) == nil)
		return FALSE;

	if (![super createObjects])
		return FALSE;

	[self.crt selectFont:0x0C00];

	self.snd.channel0 = TRUE;
	self.snd.rkmode = TRUE;
	return TRUE;
}

// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];

	[encoder encodeBool:self.isFloppy forKey:@"isFloppy"]; if (self.isFloppy)
	{
		[encoder encodeObject:self.floppy forKey:@"floppy"];
		[encoder encodeObject:self.dos29 forKey:@"dos29"];
	}
}

// -----------------------------------------------------------------------------

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
	if (![super decodeWithCoder:decoder])
		return FALSE;

	if ((self.isFloppy = [decoder decodeBoolForKey:@"isFloppy"]))
	{
		if ((self.floppy = [decoder decodeObjectForKey:@"floppy"]) == nil)
			return FALSE;

		if ((self.dos29 = [decoder decodeObjectForKey:@"dos29"]) == nil)
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
		[self.crt setColors:colors attributesMask:0x3F shiftMask:0x00];
	else
		[self.crt setColors:NULL attributesMask:0x22 shiftMask:0x00];

	self.cpu.INTE = self;

	self.snd.ext = self.ext;

	[self.cpu mapObject:self.ram from:0x0000 to:0x7FFF];
	[self.cpu mapObject:self.kbd from:0x8000 to:0x9FFF];
	[self.cpu mapObject:self.snd from:0xA000 to:0xBFFF RD:self.ext];
	[self.cpu mapObject:self.crt from:0xC000 to:0xDFFF];
	[self.cpu mapObject:self.rom from:0xE000 to:0xFFFF WR:self.dma];

	if (self.isFloppy)
	{
		[self.cpu mapObject:self.dos29 from:0xE000 to:0xEFFF WR:nil];
		[self.cpu mapObject:self.floppy from:0xF000 to:0xF7FF];
		[self.cpu addObjectToRESET:self.floppy];
	}

	[self.cpu mapHook:self.kbdHook = [[F81B alloc] initWithRKKeyboard:self.kbd] atAddress:0xF81B];

	[self.cpu mapHook:self.inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xF806];
	self.inpHook.extension = @"rkr";
	self.inpHook.type = 1;

	[self.cpu mapHook:self.outHook = [[F80C alloc] init] atAddress:0xF80C];
	self.outHook.extension = @"rkr";
	self.outHook.type = 1;

	return [super mapObjects];
}

@end

// =============================================================================
//
// =============================================================================

@implementation Radio86RK8253

@synthesize ext;

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	[super WR:addr byte:data CLK:clock];
	[ext WR:addr byte:data CLK:clock];
}

@end
