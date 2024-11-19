/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Базовый вариант РК86 без ПЗУ и распределения памяти

 *****/

#import "RK86Base.h"

@implementation RK86Base

@synthesize crt;
@synthesize dma;
@synthesize snd;

@synthesize kbd;
@synthesize ext;

@synthesize colorScheme;

@synthesize inpHook;
@synthesize outHook;

- (BOOL)createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] init8080:0xF800]) == nil)
		return NO;

	self.cpu.HOLD = 0;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x8000 mask:0xFFFF]) == nil)
		return NO;

	if (self.crt == nil && (self.crt = [[X8275 alloc] init]) == nil)
		return NO;

	[self.crt selectFont:0x0C00];

	if (self.dma == nil && (self.dma = [[X8257 alloc] init]) == nil)
		return NO;

	if (self.snd == nil && (self.snd = [[X8253 alloc] init]) == nil)
		return NO;

	if (self.kbd == nil && (self.kbd = [[RKKeyboard alloc] init]) == nil)
		return NO;

	if (self.ext == nil && (self.ext = [[X8255 alloc] init]) == nil)
		return NO;

	return YES;
}

- (BOOL)mapObjects
{
	self.nextResponder = self.kbd;
	self.kbd.computer = self;

	self.kbd.nextResponder = self.ext;
	self.ext.computer = self;

	self.cpu.HLDA = self.dma;
	self.dma.HLDA = self.crt;
	self.dma.DMA2 = self.crt;
	self.dma.cpu = self.cpu;

	return YES;
}

- (instancetype)init
{
	return self = [super initWithQuartz:16000000];
}

- (instancetype)initWithData:(NSData *)data
{
	if (self = [self init])
	{
		[self.kbd pasteString:@"I\n"];
		self.inpHook.buffer = data;
	}

	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:self.cpu forKey:@"cpu"];
	[coder encodeObject:self.rom forKey:@"rom"];
	[coder encodeObject:self.ram forKey:@"ram"];
	[coder encodeObject:self.crt forKey:@"crt"];
	[coder encodeObject:self.dma forKey:@"dma"];
	[coder encodeObject:self.snd forKey:@"snd"];
	[coder encodeObject:self.kbd forKey:@"kbd"];
	[coder encodeObject:self.ext forKey:@"ext"];

	[coder encodeInt:self.colorScheme forKey:@"colors"];
}

- (BOOL)decodeWithCoder:(NSCoder *)coder
{
	if (![super decodeWithCoder:coder])
		return NO;

	if ((self.cpu = [coder decodeObjectForKey:@"cpu"]) == nil)
		return NO;

	if ((self.rom = [coder decodeObjectForKey:@"rom"]) == nil)
		return NO;

	if ((self.ram = [coder decodeObjectForKey:@"ram"]) == nil)
		return NO;

	if ((self.crt = [coder decodeObjectForKey:@"crt"]) == nil)
		return NO;

	if ((self.dma = [coder decodeObjectForKey:@"dma"]) == nil)
		return NO;

	if ((self.snd = [coder decodeObjectForKey:@"snd"]) == nil)
		return NO;

	if ((self.kbd = [coder decodeObjectForKey:@"kbd"]) == nil)
		return NO;

	if ((self.ext = [coder decodeObjectForKey:@"ext"]) == nil)
		return NO;

	self.colorScheme = [coder decodeIntForKey:@"colors"];
	return YES;
}

@end
