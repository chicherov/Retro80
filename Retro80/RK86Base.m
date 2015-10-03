/*******************************************************************************
 Базовый вариант РК86 без ПЗУ и распределения памяти
 ******************************************************************************/

#import "RK86Base.h"

@implementation RK86Base

// -----------------------------------------------------------------------------
// createObjects - стандартные устройства РК86
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:16000000 start:0xF800]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x8000 mask:0xFFFF]) == nil)
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
	self.cpu.HLDA = self.dma;
	self.dma.HLDA = self.crt;
	self.dma.DMA2 = self.crt;
	self.dma.cpu  = self.cpu;

	self.kbd.snd  = self.snd;

	return TRUE;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	if (self = [self initWithType:0])
	{
		NSString *pathExtension = url.pathExtension.lowercaseString;

		self.inpHook.pos = ([pathExtension isEqualToString:@"gam"] || [pathExtension isEqualToString:@"pki"]) && data.length && *(uint8_t *)data.bytes == 0xE6;

		self.inpHook.buffer = data;
		[self.kbd paste:@"I\n"];
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/decodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];

	[encoder encodeObject:self.cpu forKey:@"cpu"];
	[encoder encodeObject:self.rom forKey:@"rom"];
	[encoder encodeObject:self.ram forKey:@"ram"];
	[encoder encodeObject:self.crt forKey:@"crt"];
	[encoder encodeObject:self.dma forKey:@"dma"];
	[encoder encodeObject:self.snd forKey:@"snd"];
	[encoder encodeObject:self.kbd forKey:@"kbd"];
	[encoder encodeObject:self.ext forKey:@"ext"];

	[encoder encodeBool:self.isColor forKey:@"isColor"];
}

// -----------------------------------------------------------------------------

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
	if (![super decodeWithCoder:decoder])
		return FALSE;

	if ((self.cpu = [decoder decodeObjectForKey:@"cpu"]) == nil)
		return FALSE;

	if ((self.rom = [decoder decodeObjectForKey:@"rom"]) == nil)
		return FALSE;

	if ((self.ram = [decoder decodeObjectForKey:@"ram"]) == nil)
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

	self.isColor = [decoder decodeBoolForKey:@"isColor"];
	return TRUE;
}

@end
