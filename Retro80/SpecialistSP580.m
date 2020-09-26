/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Модификация ПЭВМ «Специалист» с монитором от SP580

 *****/

#import "SpecialistSP580.h"
#import "ROMDisk.h"

@implementation SpecialistSP580

- (BOOL)createObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"SpecialistSP580" mask:0x0FFF]) == nil)
		return NO;

	if ((self.ram = [[RAM alloc] initWithLength:0x10000 mask:0xFFFF]) == nil)
		return NO;

	if ((self.kbd = [[SpecialistSP580Keyboard alloc] init]) == nil)
		return NO;

	if ((self.ext = [[ROMDisk alloc] init]) == nil)
		return NO;

	if ([super createObjects] == NO)
		return NO;

	self.snd.channel0 = YES;
	self.snd.rkmode = YES;
	return YES;
}

- (BOOL)mapObjects
{
	self.nextResponder = self.kbd;
	self.kbd.computer = self;

	self.kbd.nextResponder = self.ext;
	self.ext.computer = self;

	self.crt.screen = self.ram.mutableBytes + 0x9000;

	[self.cpu mapObject:self.ram from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt from:0x9000 to:0xBFFF RD:self.ram];
	[self.cpu mapObject:self.rom from:0xC000 to:0xC7FF WR:nil];
	[self.cpu mapObject:self.ram from:0xC800 to:0xDFFF];
	[self.cpu mapObject:self.snd from:0xE000 to:0xE7FF];
	[self.cpu mapObject:self.ext from:0xE800 to:0xEFFF];
	[self.cpu mapObject:self.kbd from:0xF000 to:0xF7FF];
	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF WR:nil];

	return YES;
}

@end

// Интерфейс клавиатуры ПЭВМ «Специалист» с монитором от SP580
@implementation SpecialistSP580Keyboard

- (void)keyboardInit
{
	[super keyboardInit];

	kbdmap = @[
		   @53,  @48,  @122, @120, @99,  @118, @96,  @97,  @98,  @109, @103, @117,
		   @10,  @18,  @19,  @20,  @21,  @23,  @22,  @26,  @28,  @25,  @29,  @27,
		   @12,  @13,  @14,  @15,  @17,  @16,  @32,  @34,  @31,  @35,  @33,  @30,
		   @0,   @1,   @2,   @3,   @5,   @4,   @38,  @40,  @37,  @41,  @39,  @42,
		   @6,   @7,   @8,   @9,   @11,  @45,  @46,  @43,  @47,  @44,  @50,  @51,
		   @999, @115, @126, @125, @48,  @53,  @49,  @123, @111, @124, @76,  @36
		   ];

	chr1Map = @"\x1B\t+1234567890-JCUKENG[]ZH:FYWAPROLDV\\.Q^SMITXB@,/_\0\0\0 \x03\r";
	chr2Map = @"\x1B\t;!\"#$%&'()\0=ЙЦУКЕНГШЩЗХ*ФЫВАПРОЛДЖЭ>ЯЧСМИТЬБЮ<?\0\0\0\0 \x03\r";
}

@end
