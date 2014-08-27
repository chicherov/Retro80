#import "Radio86RK.h"

@implementation Radio86RK

+ (NSString *) title
{
	return @"Радио-86РК";
}

// -----------------------------------------------------------------------------
// Управление компьютером
// -----------------------------------------------------------------------------

- (void) start
{
	[self.snd start];
}

- (void) reset
{
	@synchronized(self.snd)
	{
		if (!self.snd.isInput)
		{
			self.cpu.PC = 0xF800;
			self.cpu.IF = FALSE;
			return;
		}
	}

	[self.snd stop];
	[self.snd close];

	self.cpu.PC = 0xF800;
	self.cpu.IF = FALSE;

	[self.snd start];
}

- (void) stop
{
	[self.snd stop];
}

// -----------------------------------------------------------------------------
// В Радио-86РК на INTE сидит звук
// -----------------------------------------------------------------------------

- (void) INTE:(BOOL)IF
{
	self.snd.beeper = IF;
}

// -----------------------------------------------------------------------------
// createObjects - стандартные устройства РК86
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Radio86RK" mask:0x07FF]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x8000 mask:0x7FFF]) == nil)
		return FALSE;

	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:16000000]) == nil)
		return FALSE;

	if (self.crt == nil && (self.crt = [[X8275 alloc] init]) == nil)
		return FALSE;

	if (self.dma == nil && (self.dma = [[X8257 alloc] init]) == nil)
		return FALSE;

	if (self.snd == nil && (self.snd = [[X8253 alloc] init]) == nil)
		return FALSE;

	if (self.kbd == nil && (self.kbd = [[RKKeyboard alloc] init]) == nil)
		return FALSE;

	if (self.ext == nil && (self.ext = [[X8255 alloc] init]) == nil)
		return FALSE;

	return TRUE;
}

// -----------------------------------------------------------------------------
// mapObjects
// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	[self.crt setFontOffset:0x0C00];
	self.crt.attributesMask = 0xEF;
	self.crt.colors = NULL;

	[self.cpu mapObject:self.ram atPage:0x00 count:0x80];
	[self.cpu mapObject:self.kbd atPage:0x80 count:0x20];
	[self.cpu mapObject:self.ext atPage:0xA0 count:0x20];
	[self.cpu mapObject:self.crt atPage:0xC0 count:0x20];
	[self.cpu mapObject:self.dma atPage:0xE0 count:0x20];
	[self.cpu mapObject:self.rom atPage:0xF0 count:0x10];

	self.cpu.INTE = self;

	F81B *kbdHook; [self.cpu mapHook:kbdHook = [[F81B alloc] initWithRKKeyboard:self.kbd] atAddress:0xF81B];
	[self.crt addAdjustment:kbdHook];

	F806 *inpHook; [self.cpu mapHook:inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xF806];
	inpHook.extension = @"rkr";
	[self.crt addAdjustment:inpHook];

	F80C *outHook; [self.cpu mapHook:outHook = [[F80C alloc] init] atAddress:0xF80C];
	outHook.extension = @"rkr";
	[self.crt addAdjustment:outHook];

	return TRUE;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		if (![self createObjects])
			return self = nil;

		if (![self mapObjects])
			return self = nil;

		self.cpu.HOLD = self.crt;
		self.crt.dma  = self.dma;
		self.crt.kbd  = self.kbd;
		self.kbd.snd  = self.snd;
		self.dma.cpu  = self.cpu;
		self.snd.cpu  = self.cpu;

		self.cpu.PC = 0xF800;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:self.cpu forKey:@"cpu"];
	[encoder encodeObject:self.crt forKey:@"crt"];
	[encoder encodeObject:self.dma forKey:@"dma"];
	[encoder encodeObject:self.snd forKey:@"snd"];
	[encoder encodeObject:self.kbd forKey:@"kbd"];
	[encoder encodeObject:self.ext forKey:@"ext"];
	[encoder encodeObject:self.rom forKey:@"rom"];
	[encoder encodeObject:self.ram forKey:@"ram"];
}


- (id) initWithCoder:(NSCoder *)decoder
{
	if ((self.cpu = [decoder decodeObjectForKey:@"cpu"]) == nil)
		return self = nil;

	if ((self.crt = [decoder decodeObjectForKey:@"crt"]) == nil)
		return self = nil;

	if ((self.dma = [decoder decodeObjectForKey:@"dma"]) == nil)
		return self = nil;

	if ((self.snd = [decoder decodeObjectForKey:@"snd"]) == nil)
		return self = nil;

	if ((self.kbd = [decoder decodeObjectForKey:@"kbd"]) == nil)
		return self = nil;

	if ((self.ext = [decoder decodeObjectForKey:@"ext"]) == nil)
		return self = nil;

	if ((self.rom = [decoder decodeObjectForKey:@"rom"]) == nil)
		return self = nil;

	if ((self.ram = [decoder decodeObjectForKey:@"ram"]) == nil)
		return self = nil;

	self.cpu.HOLD = self.crt;
	self.crt.dma  = self.dma;
	self.crt.kbd  = self.kbd;
	self.kbd.snd  = self.snd;
	self.dma.cpu  = self.cpu;
	self.snd.cpu  = self.cpu;

	if (![self mapObjects])
		return self = nil;

	return self;
}

@end
