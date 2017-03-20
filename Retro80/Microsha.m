/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Микроша»

 *****/

#import "Microsha.h"

@implementation Microsha

@synthesize fdd;

+ (NSString *)title
{
	return @"Микроша";
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(colorModule:))
	{
		menuItem.hidden = menuItem.tag != 0;
		menuItem.state = self.colorScheme != 0;
		return menuItem.tag == 0;
	}

	if (menuItem.action == @selector(extraMemory:))
	{
		menuItem.hidden = menuItem.tag != 0;
		menuItem.state = self.ram.length == 48*1024;
		return menuItem.tag == 0;
	}

	return [super validateMenuItem:menuItem];
}

static uint32_t colors[] = {
	0xFFFFFFFF, 0xFFFF00FF, 0xFFFFFFFF, 0xFFFF00FF, 0xFFFFFF00, 0xFFFF0000, 0xFFFFFF00, 0xFFFF0000,
	0xFF00FFFF, 0xFF0000FF, 0xFF00FFFF, 0xFF0000FF, 0xFF00FF00, 0xFF000000, 0xFF00FF00, 0xFF000000
};

- (IBAction)colorModule:(NSMenuItem *)menuItem
{
	[self registerUndoWithMenuItem:menuItem];

	if ((self.colorScheme = !self.colorScheme))
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

- (IBAction)extraMemory:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		[self registerUndoWithMenuItem:menuItem];
		self.ram.length ^= 0x4000;
	}
}

- (BOOL)createObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Microsha" mask:0x07FF]) == nil)
		return FALSE;

    if ((self.kbd = [[MicroshaKeyboard alloc] init]) == nil)
        return FALSE;

    if ((self.ext = [[MicroshaExt alloc] init]) == nil)
        return FALSE;

    if (![super createObjects])
        return FALSE;

    if (self.fdd == nil && (self.fdd = [[RKFloppy alloc] init]) == nil)
        return FALSE;

	uint8_t *ptr = [self.fdd BYTE:0xEDBF];

	if (ptr && *ptr == 0xC1)
		*ptr = 0xD1;

	self.fdd.enabled = FALSE;
    return TRUE;
}

- (BOOL)mapObjects
{
	if (self.colorScheme)
		[self.crt setColors:colors attributesMask:0x3F shiftMask:0x22];
	else
		[self.crt setColors:NULL attributesMask:0x22 shiftMask:0x22];

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

	[self.cpu mapObject:self.fdd from:0xE000 to:0xEFFF WR:nil];
	[self.cpu mapObject:self.fdd from:0xF000 to:0xF7FF];

	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF WR:self.dma];

	[self.cpu mapObject:self.inpHook from:0xFC0D to:0xFC0D WR:self.dma];
	[self.cpu mapObject:self.outHook from:0xFCAB to:0xFCAB WR:self.dma];
	[self.cpu mapObject:self.outHook from:0xF89A to:0xF89A WR:self.dma];

	if (![super mapObjects])
		return FALSE;

	self.ext.nextResponder = self.fdd;
	self.fdd.computer = self;

	return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:self.fdd forKey:@"fdd"];
}

- (BOOL)decodeWithCoder:(NSCoder *)coder
{
	if (![super decodeWithCoder:coder])
		return FALSE;

	if ((self.fdd = [coder decodeObjectForKey:@"fdd"]) == nil)
		return FALSE;

	return TRUE;
}

@end

// Второй интерфейс ВВ55 ПЭВМ «Микроша»

@implementation MicroshaExt

- (void)setB:(uint8_t)data
{
	[((Microsha *) self.computer).crt selectFont:data & 0x80 ? 0x2800 : 0x0C00];
}

- (uint8_t)A
{
	return 0x00;
}

- (uint8_t)B
{
	return 0x00;
}

- (uint8_t)C
{
	return 0x00;
}

@end

// Вывод байта на магнитофон

@implementation MicroshaF80C
{
	BOOL disable;
}

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if (self.cpu.M1 && (addr == 0xF89A || disable))
	{
		[self.mem RD:addr data:data CLK:clock];
		disable = addr == 0xF89A;
	}
	else
	{
		[super RD:addr data:data CLK:clock];
	}
}

@end
