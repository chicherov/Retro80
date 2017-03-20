/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Радио-86РК»

 *****/

#import "Radio86RK.h"

@implementation Radio86RK

@synthesize fdd;

+ (NSString *)title
{
	return @"Радио-86РК";
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(colorModule:))
	{
		switch (menuItem.tag)
		{
			case 1:

				menuItem.state = self.colorScheme != 0;
				menuItem.hidden = FALSE;
				return YES;

			case 2:

				menuItem.state = self.colorScheme == 1;
				menuItem.hidden = FALSE;
				return YES;
				
			case 3:

				menuItem.state = self.colorScheme == 2;
				menuItem.hidden = FALSE;
				return YES;
				
			default:

				menuItem.hidden = TRUE;
				menuItem.state = FALSE;
				return NO;
		}
	}

	return [super validateMenuItem:menuItem];
}

static uint32_t colors[2][16] = {
	{
		0xFFAAAAAA, 0xFF0000FF, 0xFFAAAAAA, 0xFF0000FF, 0xFF00FF00, 0xFF00FFFF, 0xFF00FF00, 0xFF00FFFF,
		0xFFFF0000, 0xFFFF00FF, 0xFFFF0000, 0xFFFF00FF, 0xFFFFFF00, 0xFFFFFFFF, 0xFFFFFF00, 0xFFFFFFFF
	},
	{
		0xFFFFFFFF, 0xFF00FFFF, 0xFFFFFFFF, 0xFF00FFFF, 0xFFFFFF00, 0xFF00FF00, 0xFFFFFF00, 0xFF00FF00,
		0xFFFF00FF, 0xFF0000FF, 0xFFFF00FF, 0xFF0000FF, 0xFFFF0000, 0xFF000000, 0xFFFF0000, 0xFF000000
	}
};

- (IBAction)colorModule:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		[self registerUndoWithMenuItem:menuItem];

		switch (menuItem.tag)
		{
			case 1:

				self.colorScheme = self.colorScheme != 0 ? 0 : 1;
				break;

			case 2:

				self.colorScheme = self.colorScheme == 1 ? 0 : 1;
				break;

			case 3:

				self.colorScheme = self.colorScheme == 2 ? 0 : 2;
				break;
		}

		if (self.colorScheme == 2)
		{
			if (self.rom.length > 0x2DC && self.rom.mutableBytes[0x2DC] == 0x93)
				self.rom.mutableBytes[0x2DC] = 0xD3;

			[self.crt setColors:colors[1] attributesMask:0x3F shiftMask:0x22];
		}
		else
		{
			if (self.rom.length > 0x2DC && self.rom.mutableBytes[0x2DC] == 0xD3)
				self.rom.mutableBytes[0x2DC] = 0x93;

			if (self.colorScheme)
				[self.crt setColors:colors[0] attributesMask:0x2F shiftMask:0x22];
			else
				[self.crt setColors:NULL attributesMask:0x22 shiftMask:0x22];
		}
	}
}

- (BOOL)createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Radio86RK" mask:0x07FF]) == nil)
		return FALSE;

	if (self.ext == nil && (self.ext = [[Radio86RKExt alloc] init]) == nil)
		return FALSE;

	if (![super createObjects])
		return FALSE;

	self.snd.channel0 = TRUE;
	self.snd.rkmode = TRUE;

	if (self.fdd == nil && (self.fdd = [[RKFloppy alloc] init]) == nil)
		return FALSE;

	self.colorScheme = 1;
	return TRUE;
}

- (BOOL)mapObjects
{
	if (self.colorScheme)
	{
		if (self.colorScheme == 2)
			[self.crt setColors:colors[1] attributesMask:0x3F shiftMask:0x22];
		else
			[self.crt setColors:colors[0] attributesMask:0x2F shiftMask:0x22];
	}
	else
	{
		[self.crt setColors:NULL attributesMask:0x22 shiftMask:0x22];
	}

	self.cpu.INTE = self.snd;

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
	[self.cpu mapObject:self.ext from:0xA000 to:0xBFFF];
	[self.cpu mapObject:self.crt from:0xC000 to:0xDFFF];

	[self.cpu mapObject:self.fdd from:0xE000 to:0xEFFF WR:self.dma];
	[self.cpu mapObject:self.fdd from:0xF000 to:0xF7FF];

	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF WR:self.dma];
	[self.cpu mapObject:self.inpHook from:0xFB98 to:0xFB98 WR:self.dma];
	[self.cpu mapObject:self.outHook from:0xFC46 to:0xFC46 WR:self.dma];

	if (![super mapObjects])
		return FALSE;

	self.ext.nextResponder = self.fdd;
	self.fdd.computer = self;

	self.fdd.nextResponder = self.snd;

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

// Таймер ВИ53 (только запись) повешен параллельно ВВ55

@implementation Radio86RKExt

- (void)WR:(uint16_t)wraddr data:(uint8_t)data CLK:(uint64_t)clock
{
	[((Radio86RK *) self.computer).snd WR:wraddr data:data CLK:clock];
	[super WR:wraddr data:data CLK:clock];
}

@end
