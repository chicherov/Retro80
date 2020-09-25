/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Интерфейс клавиатуры ПЭВМ «Специалист MX»

 *****/

#import "SpecialistMXKeyboard.h"

@implementation SpecialistMXKeyboard
{
	BOOL ramfos;
}

- (void)keyboardInit
{
    [super keyboardInit];

	if (ramfos)
	{
		kbdmap = @[
			@53,  @109, @122, @120, @99,  @118, @96,  @97,  @98,  @100, @101, @51,
			@10,  @18,  @19,  @20,  @21,  @23,  @22,  @26,  @28,  @25,  @29,  @27,
			@12,  @13,  @14,  @15,  @17,  @16,  @32,  @34,  @31,  @35,  @33,  @30,
			@0,   @1,   @2,   @3,   @5,   @4,   @38,  @40,  @37,  @41,  @39,  @42,
			@6,   @7,   @8,   @9,   @11,  @45,  @46,  @43,  @47,  @44,  @50,  @117,
			@999, @115, @126, @125, @999, @999, @49,  @123, @48,  @124, @76,  @36
		];

		chr1Map = @"\x1B\x7F;1234567890-jcukeng[]zh:fywaproldv\\.q^smitxb@,/_\0\0\0 \t\x03\r";
		chr2Map = @"\x1B\x7F+!\"#$%&'() =JCUKENG{}ZH*FYWAPROLDV|>Q~SMITXB`<?\0\0\0\0 \t\x03\r";

		upperCase = NO;
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(ramfos:))
	{
		menuItem.hidden = NO;
		menuItem.state = ramfos;
		return YES;
	}

	return [super validateMenuItem:menuItem];
}

- (IBAction)ramfos:(id)sender
{
	ramfos = !ramfos;
	[self keyboardInit];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
	[coder encodeBool:ramfos forKey:@"ramfos"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	ramfos = [coder decodeBoolForKey:@"ramfos"];
	return self = [super initWithCoder:coder];
}

- (instancetype)initRAMFOS
{
	ramfos = YES;
	return self = [super init];
}

@end
