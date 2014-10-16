/*******************************************************************************
 ПЭВМ «Апогей БК-01»
 ******************************************************************************/

#import "Apogeo.h"

@implementation Apogeo

+ (NSString *) title
{
	return @"Апогей БК-01";
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
	{
		[self.crt setColors:colors attributeMask:0xFF];
	}
	else
	{
		[self.crt setColors:NULL attributeMask:0xFF];
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

- (void) INTE:(BOOL)IF
{
	[self.crt setFontOffset:IF ? 0x2400 : 0x2000];
}

// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if ((self.ram = [[RAM alloc] initWithLength:0xEC00 mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.ext = [[ROMDisk alloc] init]) == nil)
		return FALSE;

	if (![super createObjects])
		return FALSE;

	self.snd.channel0 = TRUE;
	self.snd.channel1 = TRUE;
	self.snd.channel2 = TRUE;

	self.isColor = TRUE;

	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Apogeo" mask:0x0FFF]) == nil)
		return FALSE;

	[self.crt setColors:self.isColor ? colors : 0 attributeMask:0xFF];
	[self.crt setFontOffset:self.cpu.IF ? 0x2400 : 0x2000];

	[self.cpu mapObject:self.ram atPage:0x00 count:0xEC];
	[self.cpu mapObject:self.snd atPage:0xEC];
	[self.cpu mapObject:self.kbd atPage:0xED];
	[self.cpu mapObject:self.ext atPage:0xEE];
	[self.cpu mapObject:self.crt atPage:0xEF];
	[self.cpu mapObject:self.dma atPage:0xF0 count:0x08];
	[self.cpu mapObject:self.rom atPage:0xF0 count:0x10];

	self.cpu.INTE = self;

	[self.cpu mapHook:self.kbdHook = [[F81B alloc] initWithRKKeyboard:self.kbd] atAddress:0xF81B];

	[self.cpu mapHook:self.inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xF806];
	self.inpHook.readError = 0xFAAE;
	self.inpHook.extension = @"rka";
	self.inpHook.type = 1;

	[self.cpu mapHook:self.outHook = [[F80C alloc] init] atAddress:0xF80C];
	self.outHook.extension = @"rka";

	return TRUE;
}

@end
