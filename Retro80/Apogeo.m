/*******************************************************************************
 ПЭВМ «Апогей БК-01»
 ******************************************************************************/

#import "Apogeo.h"

@implementation Apogeo

+ (NSString *) title
{
	return @"Апогей БК-01";
}

+ (NSString *) ext
{
	return @"rka";
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
// В Апогей БК-01 на INTE сидит переключение знакогенератора
// -----------------------------------------------------------------------------

- (void) INTE:(BOOL)IF
{
	[self.crt selectFont:IF ? 0x2400 : 0x2000];
}

// -----------------------------------------------------------------------------
// createObjects
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if ((self.rom = [[Memory alloc] initWithContentsOfResource:@"Apogeo" mask:0x0FFF]) == nil)
		return FALSE;

	if ((self.ram = [[Memory alloc] initWithLength:0xEC00 mask:0xFFFF]) == nil)
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

	self.cpu.INTE = self;

	[self.cpu mapObject:self.ram from:0x0000 to:0xEBFF];
	[self.cpu mapObject:self.snd from:0xEC00 to:0xECFF];
	[self.cpu mapObject:self.kbd from:0xED00 to:0xEDFF];
	[self.cpu mapObject:self.ext from:0xEE00 to:0xEEFF];
	[self.cpu mapObject:self.crt from:0xEF00 to:0xEFFF];
	[self.cpu mapObject:self.dma from:0xF000 to:0xF7FF WO:YES];
	[self.cpu mapObject:self.rom from:0xF000 to:0xFFFF RO:YES];

	[self.cpu mapHook:self.kbdHook = [[F81B alloc] initWithRKKeyboard:self.kbd] atAddress:0xF81B];

	[self.cpu mapHook:self.inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xF806];
	self.inpHook.readError = 0xFAAE;
	self.inpHook.extension = @"rka";
	self.inpHook.type = 1;

	[self.cpu mapHook:self.outHook = [[F80C alloc] init] atAddress:0xF80C];
	self.outHook.extension = @"rka";
	self.outHook.type = 1;

	return [super mapObjects];
}

@end
