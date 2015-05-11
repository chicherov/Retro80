/*******************************************************************************
 ПЭВМ «Апогей БК-01»
 ******************************************************************************/

#import "Apogeo.h"

@implementation Apogeo

+ (NSString *) title
{
	return @"Апогей БК-01";
}

+ (NSArray *) extensions
{
	return @[@"rka"];
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
			menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"][0]) stringByAppendingFormat:@": %@", url.lastPathComponent];
		else
			menuItem.title = [menuItem.title componentsSeparatedByString:@":"][0];

		menuItem.submenu = nil;
		return YES;
	}

	return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Модуль цветности
// -----------------------------------------------------------------------------

static uint32_t colors[] =
{
	0xFFFFFFFF, 0xFFFFFF00, 0xFFFFFFFF, 0xFFFFFF00,
	0xFF00FFFF, 0xFF00FF00, 0xFF00FFFF, 0xFF00FF00,
	0xFFFF00FF, 0xFFFF0000, 0xFFFF00FF, 0xFFFF0000,
	0xFF0000FF, 0xFF000000, 0xFF0000FF, 0xFF000000
};

- (IBAction) colorModule:(NSMenuItem *)menuItem
{
	[self.document registerUndoWithMenuItem:menuItem];

	if ((self.isColor = !self.isColor))
		[self.crt setColors:colors attributesMask:0x3F shiftMask:0x00];
	else
		[self.crt setColors:NULL attributesMask:0x33 shiftMask:0x11];
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
// createObjects
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Apogeo" mask:0x0FFF]) == nil)
		return FALSE;

	if ((self.ram = [[RAM alloc] initWithLength:0xEC00 mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.ext = [[ROMDisk alloc] init]) == nil)
		return FALSE;

	if (![super createObjects])
		return FALSE;

	[self.crt selectFont:0x2000];

	self.snd.channel0 = TRUE;
	self.snd.channel1 = TRUE;
	self.snd.channel2 = TRUE;

	self.isColor = TRUE;

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
		[self.crt setColors:NULL attributesMask:0x33 shiftMask:0x11];

	self.cpu.INTE = self.crt;

	if (self.inpHook == nil)
	{
		self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
		self.inpHook.mem = self.rom;
		self.inpHook.snd = self.snd;

		self.inpHook.extension = @"rka";
		self.inpHook.type = 1;
	}

	if (self.outHook == nil)
	{
		self.outHook = [[F80C alloc] initWithX8080:self.cpu];
		self.outHook.mem = self.rom;

		self.outHook.extension = @"rka";
		self.outHook.type = 1;
	}

	[self.cpu mapObject:self.ram from:0x0000 to:0xEBFF];
	[self.cpu mapObject:self.snd from:0xEC00 to:0xECFF];
	[self.cpu mapObject:self.kbd from:0xED00 to:0xEDFF];
	[self.cpu mapObject:self.ext from:0xEE00 to:0xEEFF];
	[self.cpu mapObject:self.crt from:0xEF00 to:0xEFFF];

	[self.cpu mapObject:self.rom from:0xF000 to:0xF7FF WR:self.dma];
	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF WR:nil];

	[self.cpu mapObject:self.inpHook from:0xFB98 to:0xFB98 WR:nil];
	[self.cpu mapObject:self.outHook from:0xFC46 to:0xFC46 WR:nil];

	return [super mapObjects];
}

@end
