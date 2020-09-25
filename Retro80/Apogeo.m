/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Апогей БК-01»

 *****/

#import "Apogeo.h"
#import "RKSDCard.h"

@implementation Apogeo

+ (NSString *)title
{
	return @"Апогей БК-01";
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(colorModule:))
	{
		menuItem.hidden = menuItem.tag != 0;
		menuItem.state = self.colorScheme != 0;
		return menuItem.tag == 0;
	}

	return [super validateMenuItem:menuItem];
}

static uint32_t colors[] = {
	0xFFFFFFFF, 0xFFFFFF00, 0xFFFFFFFF, 0xFFFFFF00, 0xFF00FFFF, 0xFF00FF00, 0xFF00FFFF, 0xFF00FF00,
	0xFFFF00FF, 0xFFFF0000, 0xFFFF00FF, 0xFFFF0000, 0xFF0000FF, 0xFF000000, 0xFF0000FF, 0xFF000000
};

- (IBAction)colorModule:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		[self registerUndoWithMenuItem:menuItem];

		if ((self.colorScheme = !self.colorScheme))
			[self.crt setColors:colors attributesMask:0x3F shiftMask:0x3F];
		else
			[self.crt setColors:NULL attributesMask:0x33 shiftMask:0x22];
	}
}

- (BOOL)createObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Apogeo" mask:0x0FFF]) == nil)
		return NO;

	if ((self.ram = [[RAM alloc] initWithLength:0xEC00 mask:0xFFFF]) == nil)
		return NO;

	if ((self.ext = [[RKSDCard alloc] init]) == nil)
		return NO;

	if (![super createObjects])
		return NO;

	[self.crt selectFont:0x2000];

	self.snd.channel0 = YES;
	self.snd.channel1 = YES;
	self.snd.channel2 = YES;

	self.colorScheme = YES;
	return YES;
}

- (BOOL)mapObjects
{
	if (self.colorScheme)
		[self.crt setColors:colors attributesMask:0x3F shiftMask:0x3F];
	else
		[self.crt setColors:NULL attributesMask:0x33 shiftMask:0x22];

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
		self.outHook.snd = self.snd;

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
