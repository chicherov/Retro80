#import "Apogeo.h"

@implementation Apogeo

+ (NSString *) title
{
	return @"Апогей БК-01Ц";
}

// -----------------------------------------------------------------------------

- (void) INTE:(BOOL)IF
{
	[self.crt setFontOffset:IF ? 0x2400 : 0x2000];
}

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

	self.snd.channel0 = TRUE;
	self.snd.channel1 = TRUE;
	self.snd.channel2 = TRUE;

	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	[self.cpu mapObject:self.ram atPage:0x00 count:0xEC];
	[self.cpu mapObject:self.snd atPage:0xEC];
	[self.cpu mapObject:self.kbd atPage:0xED];
	[self.cpu mapObject:self.ext atPage:0xEE];
	[self.cpu mapObject:self.crt atPage:0xEF];
	[self.cpu mapObject:self.dma atPage:0xF0 count:0x08];
	[self.cpu mapObject:self.rom atPage:0xF0 count:0x10];

	[self.crt setFontOffset:self.cpu.IF ? 0x2400 : 0x2000];

	static uint32_t colors[] =
	{
		0xFFFFFFFF, 0xFFFFFF00, 0xFFFFFFFF, 0xFFFFFF00, 0xFF00FFFF, 0xFF00FF00, 0xFF00FFFF, 0xFF00FF00,
		0xFFFF00FF, 0xFFFF0000, 0xFFFF00FF, 0xFFFF0000, 0xFF0000FF, 0xFF000000, 0xFF0000FF, 0xFF000000
	};

	self.crt.attributesMask = 0xFF;
	self.crt.colors = colors;

	self.cpu.INTE = self;

	F81B *kbdHook; [self.cpu mapHook:kbdHook = [[F81B alloc] initWithRKKeyboard:self.kbd] atAddress:0xF81B];
	[self.crt addAdjustment:kbdHook];

	F806 *inpHook; [self.cpu mapHook:inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xF806];
	inpHook.readError = 0xFAAE;
	inpHook.extension = @"rka";
	[self.crt addAdjustment:inpHook];

	F80C *outHook; [self.cpu mapHook:outHook = [[F80C alloc] init] atAddress:0xF80C];
	outHook.extension = @"rka";
	[self.crt addAdjustment:outHook];

	return TRUE;
}

@end
