/*******************************************************************************
 ПЭВМ «Радио-86РК»
 ******************************************************************************/

#import "Radio86RK.h"

@implementation Radio86RK

+ (NSString *) title
{
	return @"Радио-86РК";
}

+ (NSArray *) extensions
{
	return @[@"rkr", @"rk", @"gam", @"pki"];
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
		NSURL *url = [self.ext URL]; if ((menuItem.state = url != nil))
			menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingFormat:@": %@", url.lastPathComponent];
		else
			menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;

		menuItem.submenu = nil;
		return YES;
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
		self.ext.URL = panel.URLs.firstObject;
	}
	else if (self.ext.URL != nil)
	{
		[self.document registerUndoWithMenuItem:menuItem];
		self.ext.URL = nil;
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

		if (self.fdd == nil)
		{
			if ((self.fdd = [[Floppy alloc] init]) != nil)
			{
				if ((self.dos = [[ROM alloc] initWithContentsOfResource:@"dos29" mask:0x0FFF]) != nil)
				{
					[self.cpu mapObject:self.dos from:0xE000 to:0xEFFF WR:self.dma];
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
			[self.cpu mapObject:self.rom from:0xE000 to:0xF7FF WR:self.dma];

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
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Radio86RK" mask:0x07FF]) == nil)
		return FALSE;

	if (self.snd == nil && (self.snd = [[Radio86RK8253 alloc] init]) == nil)
		return FALSE;

	if (self.ext == nil && (self.ext = [[ROMDisk alloc] init]) == nil)
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
		[self.crt setColors:colors attributesMask:0x3F shiftMask:0x00];
	else
		[self.crt setColors:NULL attributesMask:0x22 shiftMask:0x00];

	self.cpu.INTE = self.snd;
	self.snd.ext = self.ext;

	if (self.inpHook == nil)
	{
		self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
		self.inpHook.mem = self.rom;
		self.inpHook.snd = self.snd;

		self.inpHook.extension = @"rkr";
		self.inpHook.type = 1;
	}

	if (self.outHook == nil)
	{
		self.outHook = [[F80C alloc] initWithX8080:self.cpu];
		self.outHook.mem = self.rom;
		self.outHook.snd = self.snd;

		self.outHook.extension = @"rkr";
		self.outHook.type = 1;
	}
	
	[self.cpu mapObject:self.ram from:0x0000 to:0x7FFF];
	[self.cpu mapObject:self.kbd from:0x8000 to:0x9FFF];
	[self.cpu mapObject:self.snd from:0xA000 to:0xBFFF RD:self.ext];
	[self.cpu mapObject:self.crt from:0xC000 to:0xDFFF];
	[self.cpu mapObject:self.rom from:0xE000 to:0xFFFF WR:self.dma];

	[self.cpu mapObject:self.inpHook from:0xFB98 to:0xFB98 WR:self.dma];
	[self.cpu mapObject:self.outHook from:0xFC46 to:0xFC46 WR:self.dma];

	if (self.fdd != nil)
	{
		[self.cpu mapObject:self.dos from:0xE000 to:0xEFFF WR:self.dma];
		[self.cpu mapObject:self.fdd from:0xF000 to:0xF7FF];
	}

	return [super mapObjects];
}

@end

// =============================================================================
// Radio86RK8253 - ВИ53 (только запись) повешен параллельно ВВ55
// =============================================================================

@implementation Radio86RK8253

@synthesize ext;

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	[super WR:addr data:data CLK:clock];
	[ext WR:addr data:data CLK:clock];
}

@end
