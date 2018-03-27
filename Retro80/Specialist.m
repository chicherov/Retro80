/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Специалист»

 *****/

#import "Specialist.h"
#import "SpecialistSDCard.h"

@implementation Specialist

@synthesize snd;
@synthesize crt;

@synthesize inpHook;
@synthesize outHook;

+ (NSString *)title
{
	return @"Специалист";
}

- (instancetype)init
{
	return self = [super initWithQuartz:18000000];
}

- (BOOL)createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] init8080:0xC000]) == nil)
		return FALSE;

	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Specialist1" mask:0x3FFF]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0xC000 mask:0xFFFF]) == nil)
		return FALSE;

	if (self.crt == nil && (self.crt = [[SpecialistScreen alloc] init]) == nil)
		return FALSE;

	if (self.snd == nil && (self.snd = [[X8253 alloc] init]) == nil)
		return FALSE;

	if (self.kbd == nil && (self.kbd = [[SpecialistKeyboard alloc] init]) == nil)
		return FALSE;

	if (self.ext == nil && (self.ext = [[X8255 alloc] init]) == nil)
		return FALSE;

	return TRUE;
}

- (BOOL)mapObjects
{
	self.nextResponder = self.kbd;
	self.kbd.computer = self;

	self.kbd.nextResponder = self.ext;
	self.ext.computer = self;

	self.crt.screen = self.ram.mutableBytes + 0x9000;

	if (self.inpHook == nil)
	{
		self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
		self.inpHook.mem = self.rom;
		self.inpHook.snd = self.snd;

		self.inpHook.extension = @"rks";
		self.inpHook.type = 3;
	}

	if (self.outHook == nil)
	{
		self.outHook = [[F80C alloc] initWithX8080:self.cpu];
		self.outHook.mem = self.rom;
		self.outHook.snd = self.snd;

		self.outHook.extension = @"rks";
		self.outHook.type = 3;
	}

	[self.cpu mapObject:self.ram from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt from:0x9000 to:0xBFFF RD:self.ram];
	[self.cpu mapObject:self.rom from:0xC000 to:0xEFFF WR:nil];
	[self.cpu mapObject:self.ext from:0xF000 to:0xF7FF];
	[self.cpu mapObject:self.kbd from:0xF800 to:0xFFFF];

	[self.cpu mapObject:self.inpHook from:0xC377 to:0xC377 WR:nil];
	[self.cpu mapObject:self.outHook from:0xC3D0 to:0xC3D0 WR:nil];

	return TRUE;
}

- (instancetype)initWithData:(NSData *)data
{
	if (self = [self init])
		self.inpHook.buffer = data;

	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:self.cpu forKey:@"cpu"];
	[coder encodeObject:self.rom forKey:@"rom"];
	[coder encodeObject:self.ram forKey:@"ram"];
	[coder encodeObject:self.crt forKey:@"crt"];
	[coder encodeObject:self.snd forKey:@"snd"];
	[coder encodeObject:self.kbd forKey:@"kbd"];
	[coder encodeObject:self.ext forKey:@"ext"];
}

- (BOOL)decodeWithCoder:(NSCoder *)coder
{
	if (![super decodeWithCoder:coder])
		return FALSE;

	if ((self.cpu = [coder decodeObjectForKey:@"cpu"]) == nil)
		return FALSE;

	if ((self.rom = [coder decodeObjectForKey:@"rom"]) == nil)
		return FALSE;

	if ((self.ram = [coder decodeObjectForKey:@"ram"]) == nil)
		return FALSE;

	if ((self.crt = [coder decodeObjectForKey:@"crt"]) == nil)
		return FALSE;

	if ((self.snd = [coder decodeObjectForKey:@"snd"]) == nil)
		return FALSE;

	if ((self.kbd = [coder decodeObjectForKey:@"kbd"]) == nil)
		return FALSE;

	if ((self.ext = [coder decodeObjectForKey:@"ext"]) == nil)
		return FALSE;

	return TRUE;
}

@end

// ПЭВМ «Специалист» с монитором 2

@implementation Specialist2

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(colorModule:))
	{
		switch (menuItem.tag)
		{
			case 1:

				menuItem.state = self.crt.isColor;
				menuItem.hidden = FALSE;
				return YES;

			case 5:

				menuItem.state = self.crt.isColor && self.kbd.colorScheme == 1;
				menuItem.hidden = FALSE;
				return YES;

			case 8:

				menuItem.state = self.crt.isColor && self.kbd.colorScheme == 2;
				menuItem.hidden = FALSE;
				return YES;

			default:

				menuItem.hidden = TRUE;
				menuItem.state = FALSE;
				return YES;
		}
	}

	return [super validateMenuItem:menuItem];
}

static uint8_t path[] = {
	0xFB, 0x3E, 0x82, 0x32, 0x03, 0xFF, 0xC3, 0x44, 0xC4, 0x00
};

- (IBAction)colorModule:(NSMenuItem *)menuItem
{
	[self registerUndoWithMenuItem:menuItem];

	switch (menuItem.tag)
	{
		case 1:

			self.crt.isColor = !self.crt.isColor;
			break;

		case 5:

			self.kbd.colorScheme = 1;
			self.crt.isColor = TRUE;
			break;

		case 8:

			self.kbd.colorScheme = 2;
			self.crt.isColor = TRUE;
			break;
	}

	uint8_t *ptr = self.rom.mutableBytes + 6;

	if (self.crt.isColor && self.kbd.colorScheme == 2)
	{
		if (memcmp(ptr, path + 1, 9) == 0)
			memcpy(ptr, path, 9);
	}
	else
	{
		if (memcmp(ptr, path, 9) == 0)
			memcpy(ptr, path + 1, 9);
	}
}

- (BOOL)createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Specialist2" mask:0x3FFF]) == nil)
		return NO;

	if (self.ext == nil && (self.ext = [[SpecialistSDCard alloc] init]) == nil)
		return NO;

	if (![super createObjects])
		return FALSE;

	uint8_t *ptr = self.rom.mutableBytes + 6;

	if (memcmp(ptr, path + 1, 9) == 0)
		memcpy(ptr, path, 9);

	self.kbd.colorScheme = 2;
	self.crt.isColor = TRUE;
	return TRUE;
}

@end

// ПЭВМ «Специалист» с монитором ПЭВМ «ЛИК»

@implementation SpecialistLik

- (BOOL)createObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Lik" mask:0x3FFF]) == nil)
		return NO;

	return [super createObjects];
}

@end

// ПЭВМ «Специалист» с монитором 2.7

@implementation Specialist27

- (instancetype)init
{
	return self = [super initWithQuartz:22500000];
}

- (BOOL)createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Specialist-2.7" mask:0x3FFF]) == nil)
		return NO;

	return [super createObjects];
}

- (BOOL)mapObjects
{
	if (![super mapObjects])
		return NO;

	self.crt.isColor = FALSE;

	[self.cpu mapObject:[self.rom memoryAtOffest:0 mask:0xFF] from:0xF800 to:0xF8FF];

	return YES;
}

@end

// ПЭВМ «Специалист» с монитором 3.3

@implementation Specialist33

- (BOOL)createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Specialist-3.3" mask:0x3FFF]) == nil)
		return NO;

	uint8_t *ptr = [self.rom BYTE:0xCEDF];

	if (ptr && *ptr == 0xE5)
		*ptr = 0xC9;

	return [super createObjects];
}

@end
