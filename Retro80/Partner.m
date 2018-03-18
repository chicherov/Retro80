/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Партнер 01.01»

 *****/

#import "Partner.h"

@implementation Partner

+ (NSString *)title
{
	return @"Партнер 01.01";
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(colorModule:))
	{
		menuItem.hidden = menuItem.tag != 4;
		menuItem.state = self.colorScheme != 0;
		return menuItem.tag == 4 && (self.sys2.slot & 0x04) == 0;
	}

	return [super validateMenuItem:menuItem];
}

// Модуль цветной псевдографический "Партнер 01.61"
- (IBAction)colorModule:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		if ((self.sys2.slot & 0x04) == 0)
		{
			[self registerUndoWithMenuItem:menuItem];
			self.colorScheme = !self.colorScheme;

			self.snd.channel0 = self.colorScheme;
			self.snd.channel1 = self.colorScheme;
			self.snd.channel2 = self.colorScheme;

			self.sys2.mcpg = self.colorScheme;
		}
	}
}

- (instancetype)init
{
	return self = [super initWithQuartz:18000000];
}

- (BOOL)createObjects
{
	if ((self.cpu = [[X8080 alloc] init8080:0x00000]) == nil)
		return FALSE;

	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Partner" mask:0x1FFF]) == nil)
		return FALSE;

	if ((self.basic = [[ROM alloc] initWithContentsOfResource:@"Basic" mask:0x1FFF]) == nil)
		return FALSE;

	if ((self.ram = [[RAM alloc] initWithLength:0x10000 mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.kbd = [[PartnerKeyboard alloc] init]) == nil)
		return FALSE;

	if (![super createObjects])
		return FALSE;

	if ((self.sys2 = [[PartnerSystem2 alloc] init]) == nil)
		return FALSE;

	if ((self.mcpgbios = [[ROM alloc] initWithContentsOfResource:@"mcpg" mask:0x07FF]) == nil)
		return FALSE;

	if ((self.mcpgfont = [[RAM alloc] initWithLength:0x1000 mask:0x0FFF]) == nil)
		return FALSE;

	self.colorScheme = TRUE;

	self.snd.channel0 = TRUE;
	self.snd.channel1 = TRUE;
	self.snd.channel2 = TRUE;

	if ((self.fddbios = [[ROM alloc] initWithContentsOfResource:@"fdd" mask:0x07FF]) == nil)
		return FALSE;

	if ((self.fdd = [[VG93 alloc] initWithQuartz:self.quartz]) == nil)
		return FALSE;

	self.dma.tick = 12;
	return TRUE;
}

- (BOOL)mapObjects
{
	// Системный регистр 1 и окошки для внешних устройств

	if (self.sys1 == nil && (self.sys1 = [[PartnerSystem1 alloc] init]) == nil)
		return FALSE;

	if (self.win1 == nil && (self.win1 = [[PartnerExternal alloc] init]) == nil)
		return FALSE;

	if (self.win2 == nil && (self.win2 = [[PartnerExternal alloc] init]) == nil)
		return FALSE;

	// Магнитофон

	if (self.inpHook == nil)
	{
		self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
		self.inpHook.mem = self.rom;
		self.inpHook.snd = self.snd;

		self.inpHook.extension = @"rkp";
		self.inpHook.type = 1;
	}

	if (self.outHook == nil)
	{
		self.outHook = [[F80C alloc] initWithX8080:self.cpu];
		self.outHook.mem = self.rom;
		self.outHook.snd = self.snd;

		self.outHook.extension = @"rkp";
		self.outHook.type = 1;
	}

	for (uint8_t page = 0x0; page <= 10; page++)
	{
		// Область D800-DFFF всегда принадлежит системным контролерам

		[self.cpu mapObject:self.crt		atPage:page from:0xD800 to:0xD8FF];
		[self.cpu mapObject:self.kbd		atPage:page from:0xD900 to:0xD9FF];
		[self.cpu mapObject:self.sys1		atPage:page from:0xDA00 to:0xDAFF RD:nil];
		[self.cpu mapObject:self.dma		atPage:page from:0xDB00 to:0xDBFF];
		[self.cpu mapObject:self.sys2		atPage:page from:0xDC00 to:0xDFFF];

		// Страница 2 идет в виде базовой страницы

		[self.cpu mapObject:self.ram		atPage:page from:0x0000 to:0xD7FF];

		[self.cpu mapObject:self.win1		atPage:page from:0xE000 to:0xE7FF];
		[self.cpu mapObject:self.rom		atPage:page from:0xE800 to:0xFFFF WR:nil];

		[self.cpu mapObject:self.inpHook	atPage:page from:0xFBA2 to:0xFBA2 WR:nil];
		[self.cpu mapObject:self.outHook	atPage:page from:0xFC55 to:0xFC55 WR:nil];
	}

	// Страница 0, с адреса 0000 идут первые 2К монитора
	// Предназначена для старта по Reset

	[self.cpu mapObject:self.rom	atPage:0 from:0x0000 to:0x07FF WR:nil];

	// Страница 1, верхние 8К полностью занимает монитор
	// Предназначена для копирования ассемблера в память

	[self.cpu mapObject:self.rom	atPage:1 from:0xE000 to:0xE7FF WR:nil];

	// Страница 3, верхние 8К полностью занимает внешнее окошко 1

	[self.cpu mapObject:self.win1	atPage:3 from:0xE800 to:0xFFFF];

	// Страница 4, верхние 8К полностью занимает внешнее окошко 1
	// Кроме того, внешние окошко 2 подключается B800-BFFF

	[self.cpu mapObject:self.win1	atPage:4 from:0xE800 to:0xFFFF];
	[self.cpu mapObject:self.win2	atPage:4 from:0xB800 to:0xBFFF];

	// Страница 5, верхние 8К полностью занимает внешнее окошко 1
	// Кроме того, внешние окошко 2 подключается 8000-BFFF

	[self.cpu mapObject:self.win1	atPage:5 from:0xE800 to:0xFFFF];
	[self.cpu mapObject:self.win2	atPage:5 from:0x8000 to:0xBFFF];

	// Страница 6, ПЗУ Бейсика подключается по адресам A000-BFFF

	[self.cpu mapObject:self.basic	atPage:6 from:0xA000 to:0xBFFF WR:nil];

	// Страница 7, ОЗУ1 и ОЗУ2 меняются местами

	[self.cpu mapObject:[self.ram memoryAtOffest:0x8000 mask:0x7FFF] atPage:7 from:0x0000 to:0x7FFF];
	[self.cpu mapObject:[self.ram memoryAtOffest:0x0000 mask:0x7FFF] atPage:7 from:0x8000 to:0xD7FF];

	// Страница 8, ПЗУ Бейсика подключается по адресам A000-9FFF
	// Кроме того, внешние окошко 1 подключается 8000-BFFF

	[self.cpu mapObject:self.win2	atPage:8 from:0xC800 to:0xD7FF];
	[self.cpu mapObject:self.rom	atPage:8 from:0xC000 to:0xC7FF WR:nil];
	[self.cpu mapObject:self.basic	atPage:8 from:0xA000 to:0xBFFF WR:nil];
	[self.cpu mapObject:self.win1	atPage:8 from:0x8000 to:0x9FFF];

	// Страница 9

	[self.cpu mapObject:self.win1	atPage:9 from:0x8000 to:0x9FFF];
	[self.cpu mapObject:self.win2	atPage:9 from:0xC800 to:0xD7FF];

	// Странца 10

	[self.cpu mapObject:self.win1	atPage:10 from:0x4000 to:0x5FFF];
	[self.cpu mapObject:self.win2	atPage:10 from:0x8000 to:0xBFFF];
	[self.cpu mapObject:self.rom	atPage:10 from:0xC000 to:0xCFFF WR:nil];

	// КР580ВГ75

	static uint16_t fonts[16] = {
		0x0000, 0x1000, 0x0000, 0x1000,
		0x0400, 0x1400, 0x0400, 0x1400,
		0x0800, 0x1800, 0x0800, 0x1800,
		0x0C00, 0x1C00, 0x0C00, 0x1C00
	};

	[self.crt setColors:NULL attributesMask:0x3F shiftMask:0x0F];
	[self.crt setFonts:fonts];

	// Системный регистр 1

	self.sys1.partner = self;

	// Системный регистр 2

	self.sys2.partner = self;
	self.sys2.slot = self.sys2.slot;
	self.sys2.mcpg = self.sys2.mcpg;

	// Контроллер прерывания

	self.cpu.IRQ = self.crt;
	self.cpu.RST = 0xF7;

	// Контроллер НГМД

	self.dma.DMA0 = self.fdd;

	self.dma.DMA3 = self.sys1;
	self.cpu.FF = TRUE;

	if (![super mapObjects])
		return FALSE;

	self.kbd.nextResponder = self.fdd;
	self.fdd.computer = self;
	return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:self.basic forKey:@"basic"];
	[coder encodeObject:self.sys2 forKey:@"sys2"];

	[coder encodeObject:self.mcpgbios forKey:@"mcpgbios"];
	[coder encodeObject:self.mcpgfont forKey:@"mcpgfont"];

	[coder encodeObject:self.fddbios forKey:@"fddbios"];
	[coder encodeObject:self.fdd forKey:@"fdd"];
}

- (BOOL)decodeWithCoder:(NSCoder *)coder
{
	if (![super decodeWithCoder:coder])
		return FALSE;

	if ((self.basic = [coder decodeObjectForKey:@"basic"]) == nil)
		return FALSE;

	if ((self.sys2 = [coder decodeObjectForKey:@"sys2"]) == nil)
		return FALSE;

	if ((self.mcpgbios = [coder decodeObjectForKey:@"mcpgbios"]) == nil)
		return FALSE;

	if ((self.mcpgfont = [coder decodeObjectForKey:@"mcpgfont"]) == nil)
		return FALSE;

	if ((self.fddbios = [coder decodeObjectForKey:@"fddbios"]) == nil)
		return FALSE;

	if ((self.fdd = [coder decodeObjectForKey:@"fdd"]) == nil)
		return FALSE;

	return TRUE;
}

- (instancetype)initWithData:(NSData *)data
{
	if (self = [self init])
	{
		[self.kbd pasteString:@"\x7F\x7FI\n"];
		self.inpHook.buffer = data;
	}

	return self;
}

@end

/*****
 Системнный регистр 1 - выбор станицы адресного простарнства
 *****/

@implementation PartnerSystem1
{
	uint64_t DRQ;
}

@synthesize partner;

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	partner.cpu.PAGE = data >> 4;
}

- (void)RD:(uint8_t *)data clock:(uint64_t)clock
{
}

- (void)WR:(uint8_t)data clock:(uint64_t)clock
{
	DRQ = clock + 192;
}

- (uint64_t *)DRQ
{
	return &DRQ;
}

@end

/*****
 Системнный регистр 2 и внешние устройства
 *****/

@implementation PartnerSystem2
{
	uint8_t slot;
	BOOL mcpg;
}

@synthesize partner;

- (void)setSlot:(uint8_t)data
{
	if (data & 0x02 && partner.fdd.enabled)
	{
		partner.win1.object = partner.fddbios;
		partner.win2.object = nil;
		slot = 0x02;
	}

	else if (data & 0x04 && partner.colorScheme)
	{
		partner.win1.object = partner.mcpgbios;
		partner.win2.object = partner.mcpgfont;
		slot = 0x04;
	}

	else
	{
		partner.win1.object = nil;
		partner.win2.object = nil;
		slot = 0x00;
	}
}

- (uint8_t)slot
{
	return slot;
}

- (void)setMcpg:(BOOL)data
{
	[partner.crt setMcpg:((mcpg = data) && partner.colorScheme ? partner.mcpgfont.mutableBytes : NULL)];
}

- (BOOL)mcpg
{
	return mcpg;
}

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if ((addr & 0x200) == 0)
	{
		if (slot & 0x02 && partner.fdd.enabled && (addr & 0x100) == 0)
			[partner.fdd RD:addr data:data CLK:clock];

		else if (slot & 0x04 && partner.colorScheme && addr & 0x100)
			[partner.snd RD:addr >> 2 data:data CLK:clock];
	}
}

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	if ((addr & 0x200) == 0)
	{
		if (slot & 0x02 && partner.fdd.enabled)
		{
			if (addr & 0x100)
			{
				partner.fdd.selected = data & 0x40 ? 1 : data & 0x08 ? 2 : 0;
				partner.fdd.head = (data & 0x80) != 0;
			}
			else
			{
				[partner.fdd WR:addr data:data CLK:clock];
			}
		}

		else if (slot & 0x04 && partner.colorScheme)
		{
			if (addr & 0x100)
				[partner.snd WR:addr >> 2 data:data CLK:clock];
			else
				self.mcpg = data != 0xFF;
		}
	}

	else if ((addr & 0x100) == 0)
	{
		self.slot = ~(data | 0xF0);
	}
}

- (void)RESET:(uint64_t)clock
{
	[partner.fdd RESET:clock];
	self.mcpg = FALSE;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt:slot forKey:@"slot"];
	[coder encodeBool:mcpg forKey:@"mcpg"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if (self = [super init])
	{
		slot = [coder decodeIntForKey:@"slot"];
		mcpg = [coder decodeBoolForKey:@"mcpg"];
	}

	return self;
}

@end

/*****
 Окно внешнего устройства
 *****/

@implementation PartnerExternal

@synthesize object;

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	[object RD:addr data:data CLK:clock];
}

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	if ([object conformsToProtocol:@protocol(WR)])
		[(NSObject<WR> *) object WR:addr data:data CLK:clock];
}

- (uint8_t *)BYTE:(uint16_t)addr
{
	return [object BYTE:addr];
}

@end

/*****
 Вариант клавиатуры РК86 для Партнера
 *****/

@implementation PartnerKeyboard

- (void)keyboardInit
{
	[super keyboardInit];

	RUSLAT = 0x10;
	TAPEI = 0x80;
}

- (void)setC:(uint8_t)data
{
	[[(Partner *) self.computer snd] setTone:data & 0x02 ? 0 : 4000*9 clock:self.computer.clock];
	[super setC:data];
}

@end
