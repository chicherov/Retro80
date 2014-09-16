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

// -----------------------------------------------------------------------------
// createObjects - стандартные устройства РК86
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
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
	return FALSE;
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

		self.cpu.HLDA = self.crt;
		self.crt.dma  = self.dma;
		self.dma.cpu  = self.cpu;

		self.kbd.snd  = self.snd;
		self.snd.cpu  = self.cpu;

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

	[encoder encodeBool:self.isColor forKey:@"isColor"];

	[encoder encodeBool:self.kbdHook.enabled forKey:@"kbdHook"];
	[encoder encodeBool:self.inpHook.enabled forKey:@"inpHook"];
	[encoder encodeBool:self.outHook.enabled forKey:@"outHook"];
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

	if ((self.ram = [decoder decodeObjectForKey:@"ram"]) == nil)
		return self = nil;

	self.isColor = [decoder decodeBoolForKey:@"isColor"];

	self.cpu.HLDA = self.crt;
	self.crt.dma  = self.dma;
	self.dma.cpu  = self.cpu;

	self.kbd.snd  = self.snd;
	self.snd.cpu  = self.cpu;

	if (![self mapObjects])
		return self = nil;

	self.kbdHook.enabled = [decoder decodeBoolForKey:@"kbdHook"];
	self.inpHook.enabled = [decoder decodeBoolForKey:@"inpHook"];
	self.outHook.enabled = [decoder decodeBoolForKey:@"outHook"];

	return self;
}

@end
