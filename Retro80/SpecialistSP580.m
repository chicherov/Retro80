/*******************************************************************************
 Модификация ПЭВМ «Специалист» с монитором от SP580
 ******************************************************************************/

#import "SpecialistSP580.h"

@implementation SpecialistSP580

- (BOOL) createObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"SpecialistSP580" mask:0x0FFF]) == nil)
		return FALSE;

	if ((self.ram = [[RAM alloc] initWithLength:0x10000 mask:0xFFFF]) == nil)
		return FALSE;

	if ([super createObjects] == FALSE)
		return FALSE;

	self.snd.channel0 = TRUE;
	self.snd.rkmode = TRUE;
	return TRUE;
}

- (BOOL) mapObjects
{
	self.crt.screen = self.ram.mutableBytes + 0x9000;

	[self.cpu mapObject:self.ram from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt from:0x9000 to:0xBFFF RD:self.ram];
	[self.cpu mapObject:self.rom from:0xC000 to:0xC7FF WR:nil];
	[self.cpu mapObject:self.ram from:0xC800 to:0xDFFF];
	[self.cpu mapObject:self.snd from:0xE000 to:0xE7FF];
	[self.cpu mapObject:self.ext from:0xE800 to:0xEFFF];
	[self.cpu mapObject:self.kbd from:0xF000 to:0xF7FF];
	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF WR:nil];

	[self.cpu addObjectToRESET:self.kbd];
	[self.cpu addObjectToRESET:self.ext];

	self.kbdHook = [[F81B alloc] initWithRKKeyboard:self.kbd];
	[self.cpu mapHook:(F81B *)self.kbdHook atAddress:0xF81B];

	self.kbd.crt = self.crt;
	self.kbd.snd = self.snd;
	return TRUE;
}

@end
