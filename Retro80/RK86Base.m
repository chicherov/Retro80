/*******************************************************************************
 Базовый вариант РК86 без ПЗУ и распределения памяти
 ******************************************************************************/

#import "RK86Base.h"

@implementation RK86Base

// -----------------------------------------------------------------------------
// Управление компьютером
// -----------------------------------------------------------------------------

- (void) reset
{
	@synchronized(self.snd)
	{
		if (!self.snd.isInput)
		{
			[self RESET];
			return;
		}
	}

	[self.snd stop];
	[self.snd close];

	[self RESET];

	[self.snd start];
}

- (void) RESET
{
	[self.kbd RESET];
	[self.ext RESET];

	self.cpu.PC = 0xF800;
	self.cpu.IF = FALSE;
}

// -----------------------------------------------------------------------------
// createObjects - стандартные устройства РК86
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.ram == nil && (self.ram = [[Memory alloc] initWithLength:0x8000 mask:0x7FFF]) == nil)
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
// decodeObjects
// -----------------------------------------------------------------------------

- (BOOL) decodeObjects:(NSCoder *)decoder
{
	if ((self.cpu = [decoder decodeObjectForKey:@"cpu"]) == nil)
		return FALSE;

	if ((self.crt = [decoder decodeObjectForKey:@"crt"]) == nil)
		return FALSE;

	if ((self.dma = [decoder decodeObjectForKey:@"dma"]) == nil)
		return FALSE;

	if ((self.snd = [decoder decodeObjectForKey:@"snd"]) == nil)
		return FALSE;

	if ((self.kbd = [decoder decodeObjectForKey:@"kbd"]) == nil)
		return FALSE;

	if ((self.ext = [decoder decodeObjectForKey:@"ext"]) == nil)
		return FALSE;

	if ((self.ram = [decoder decodeObjectForKey:@"ram"]) == nil)
		return FALSE;

	if ((self.rom = [decoder decodeObjectForKey:@"rom"]) == nil)
		return FALSE;

	self.isColor = [decoder decodeBoolForKey:@"isColor"];

	return TRUE;
}

// -----------------------------------------------------------------------------
// mapObjects
// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	self.cpu.HLDA = self.crt;
	self.crt.dma  = self.dma;
	self.dma.cpu  = self.cpu;

	self.kbd.snd  = self.snd;
	self.snd.cpu  = self.cpu;
	
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

		self.cpu.PC = 0xF800;

		self.kbdHook.enabled = TRUE;
		self.inpHook.enabled = TRUE;
		self.outHook.enabled = TRUE;

#ifdef DEBUG
		self.outHook.enabled = FALSE;
#endif
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
	[encoder encodeObject:self.ram forKey:@"ram"];
	[encoder encodeObject:self.rom forKey:@"rom"];

	[encoder encodeBool:self.isColor forKey:@"isColor"];

	[encoder encodeBool:self.kbdHook.enabled forKey:@"kbdHook"];
	[encoder encodeBool:self.inpHook.enabled forKey:@"inpHook"];
	[encoder encodeBool:self.outHook.enabled forKey:@"outHook"];
}


- (id) initWithCoder:(NSCoder *)decoder
{
	if (![self decodeObjects:decoder])
		return self = nil;

	if (![self mapObjects])
		return self = nil;

	self.kbdHook.enabled = [decoder decodeBoolForKey:@"kbdHook"];
	self.inpHook.enabled = [decoder decodeBoolForKey:@"inpHook"];
	self.outHook.enabled = [decoder decodeBoolForKey:@"outHook"];

	return self;
}

@end
