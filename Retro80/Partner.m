#import "Partner.h"

// -----------------------------------------------------------------------------
// Системнный регистр 1 - выбор станицы адресного простарнства
// -----------------------------------------------------------------------------

@implementation PartnerSystem1
{
	uint8_t page;
}

@synthesize partner;

- (void) setPage:(uint8_t)data
{
	[partner.cpu selectPage:page = data & 0x0F from:0x0000 to:0xFFFF];
}

- (uint8_t) page
{
	return page;
}

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	return self.page << 4;
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	self.page = data >> 4;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInteger:page forKey:@"page"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super init])
	{
		page = [decoder decodeIntForKey:@"page"];
	}

	return self;
}

@end

// -----------------------------------------------------------------------------
// Системнный регистр 2 - выбор внешнего устройства
// -----------------------------------------------------------------------------

@implementation PartnerSystem2
{
	uint8_t slot;
	BOOL mcpg;
}

@synthesize partner;

- (void) setSlot:(uint8_t)data
{
	slot = data;

	if (slot & 0x04 && partner.isColor)
	{
		partner.win1.object = partner.mcpgbios;
		partner.win2.object = partner.mcpgfont;
	}

	else
	{
		partner.win1.object = nil;
		partner.win2.object = nil;
	}
}

- (uint8_t) slot
{
	return slot;
}

- (void) setMcpg:(BOOL)data
{
	mcpg = data; [partner.crt setMcpg:(mcpg ? [partner.mcpgfont bytesAtAddress:0] : NULL)];
}

- (BOOL) mcpg
{
	return mcpg;
}

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	if ((addr & 0x200) == 0)
	{
		if (slot & 0x04 && partner.isColor)
		{
			if ((addr & 0x100) == 0)
			{
				return self.mcpg ? 0x00 : 0xFF;
			}
			else
			{
				return [partner.snd RD:addr >> 2 CLK:clock status:status];
			}
		}

		NSLog(@"RD: %02X", addr);
		return status;
	}

	else if ((addr & 0x100) == 0)
	{
		return ~self.slot;
	}

	else
	{
		NSLog(@"RD: %02X", addr);
		return status;
	}
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	if ((addr & 0x200) == 0)
	{
		if (slot & 0x04 && partner.isColor)
		{
			if ((addr & 0x100) == 0)
			{
				self.mcpg = data == 0x00;
			}
			else
			{
				[partner.snd WR:addr >> 2 byte:data CLK:clock];
			}
		}

		else
		{
			NSLog(@"WR: %04X %02X", addr, data);
		}
	}

	else if ((addr & 0x100) == 0)
	{
		self.slot = ~(data | 0xF0);
	}

	else
	{
		NSLog(@"WR: %04X %02X", addr, data);
	}
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:slot forKey:@"slot"];
	[encoder encodeBool:mcpg forKey:@"mcpg"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super init])
	{
		slot = [decoder decodeIntForKey:@"slot"];
		mcpg = [decoder decodeBoolForKey:@"mcpg"];
	}

	return self;
}

@end

// -----------------------------------------------------------------------------
// Окно внешнего устройства
// -----------------------------------------------------------------------------

@implementation PartnerExternal

@synthesize object;

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	return object ? [object RD:addr CLK:clock status:status] : status;
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	[object WR:addr byte:data CLK:clock];
}

@end

// -----------------------------------------------------------------------------
// Вариант клавиатуры РК86 для Партнера
// -----------------------------------------------------------------------------

@implementation PartnerKeyboard

- (id) init
{
	if (self = [super init])
	{
		RUSLAT = 0x10;
		SHIFT = 0x20;
		CTRL = 0x40;

		TAPE = 0x80;
	}

	return self;
}

- (void) setC:(uint8_t)C
{
	if ((C ^ _C) & 0x02)
		self.snd.beeper = C & 0x02 ? 0 : 4000*9;

	[super setC:C];
}

@end

// -----------------------------------------------------------------------------
// ПЭВМ «Партнер 01.01»
// -----------------------------------------------------------------------------

@implementation Partner

+ (NSString *) title
{
	return @"Партнер 01.01";
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(colorModule:))
	{
		menuItem.state = self.isColor;
		return (self.sys2.slot & 0x04) == 0;
	}

	return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// МОДУЛЬ ЦВЕТНОЙ ПСЕВДОГРАФИЧЕСКИЙ "ПАРТНЕР 01.61"
// -----------------------------------------------------------------------------

- (IBAction) colorModule:(NSMenuItem *)menuItem
{
	@synchronized(self.snd)
	{
		if ((self.sys2.slot & 0x04) == 0)
		{
			[self.document registerUndoWithMenuItem:menuItem];
			self.isColor = !self.isColor;

			self.snd.channel0 = self.isColor;
			self.snd.channel1 = self.isColor;
			self.snd.channel2 = self.isColor;

			self.sys2.mcpg = self.isColor;
		}
	}
}

// -----------------------------------------------------------------------------
// createObjects
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if ((self.cpu = [[X8080 alloc] initWithQuartz:18000000]) == nil)
		return FALSE;

	if ((self.kbd = [[PartnerKeyboard alloc] init]) == nil)
		return FALSE;

	if ((self.rom = [[Memory alloc] initWithContentsOfResource:@"Partner" mask:0x1FFF]) == nil)
		return FALSE;

	if ((self.basic = [[Memory alloc] initWithContentsOfResource:@"Basic" mask:0x1FFF]) == nil)
		return FALSE;

	if ((self.ram2 = [[Memory alloc] initWithLength:0x8000 mask:0x7FFF]) == nil)
		return FALSE;

	if ((self.sys1 = [[PartnerSystem1 alloc] init]) == nil)
		return FALSE;

	if ((self.sys2 = [[PartnerSystem2 alloc] init]) == nil)
		return FALSE;

	if ((self.mcpgbios = [[Memory alloc] initWithContentsOfResource:@"mcpg" mask:0x07FF]) == nil)
		return FALSE;

	if ((self.mcpgfont = [[Memory alloc] initWithLength:0x1000 mask:0x0FFF]) == nil)
		return FALSE;

	if (![super createObjects])
		return FALSE;

	self.isColor = TRUE;
	return TRUE;
}

// -----------------------------------------------------------------------------
// decodeObjects
// -----------------------------------------------------------------------------

- (BOOL) decodeObjects:(NSCoder *)decoder
{
	if (![super decodeObjects:decoder])
		return FALSE;

	if ((self.basic = [decoder decodeObjectForKey:@"basic"]) == nil)
		return FALSE;

	if ((self.ram2 = [decoder decodeObjectForKey:@"ram2"]) == nil)
		return FALSE;

	if ((self.sys1 = [decoder decodeObjectForKey:@"sys1"]) == nil)
		return FALSE;

	if ((self.sys2 = [decoder decodeObjectForKey:@"sys2"]) == nil)
		return FALSE;

	if ((self.mcpgbios = [decoder decodeObjectForKey:@"mcpgbios"]) == nil)
		return FALSE;

	if ((self.mcpgfont = [decoder decodeObjectForKey:@"mcpgfont"]) == nil)
		return FALSE;

	return TRUE;
}

// -----------------------------------------------------------------------------
// encodeWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];

	[encoder encodeObject:self.basic forKey:@"basic"];
	[encoder encodeObject:self.ram2 forKey:@"ram2"];
	[encoder encodeObject:self.sys1 forKey:@"sys1"];
	[encoder encodeObject:self.sys2 forKey:@"sys2"];

	[encoder encodeObject:self.mcpgbios forKey:@"mcpgbios"];
	[encoder encodeObject:self.mcpgfont forKey:@"mcpgfont"];
}

// -----------------------------------------------------------------------------
// mapObjects
// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	static uint16_t fonts[16] =
	{
		0x0000, 0x1000, 0x0000, 0x1000,
		0x0400, 0x1400, 0x0400, 0x1400,
		0x0800, 0x1800, 0x0800, 0x1800,
		0x0C00, 0x1C00, 0x0C00, 0x1C00
	};
	
	[self.crt setColors:NULL attributesMask:0x3F];
	[self.crt setFonts:fonts];

	self.snd.channel0 = self.isColor;
	self.snd.channel1 = self.isColor;
	self.snd.channel2 = self.isColor;

	// Окошки для внешних устройств

	self.win1 = [[PartnerExternal alloc] init];
	self.win2 = [[PartnerExternal alloc] init];

	// Область D800-DFFF всегда принадлежит системным контролерам

	[self.cpu mapObject:self.crt	from:0xD800 to:0xD8FF];
	[self.cpu mapObject:self.kbd	from:0xD900 to:0xD9FF];
	[self.cpu mapObject:self.sys1	from:0xDA00 to:0xDAFF];
	[self.cpu mapObject:self.dma	from:0xDB00 to:0xDBFF];
	[self.cpu mapObject:self.sys2	from:0xDC00 to:0xDFFF];

	self.sys1.partner = self;
	self.sys1.page = self.sys1.page;

	self.sys2.partner = self;
	self.sys2.slot = self.sys2.slot;
	self.sys2.mcpg = self.sys2.mcpg;

	// Страница 2 идет в виде базовой страницы

	[self.cpu mapObject:self.ram	from:0x0000 to:0x7FFF];
	[self.cpu mapObject:self.ram2	from:0x8000 to:0xD7FF];

	[self.cpu mapObject:self.win1	from:0xE000 to:0xE7FF];
	[self.cpu mapObject:self.rom	from:0xE800 to:0xFFFF];

	// Страница 0, с адреса 0000 идут первые 2К монитора
	// Предназначена для старта по Reset

	[self.cpu mapObject:self.rom	atPage:0 from:0x0000 to:0x07FF];

	// Страница 1, верхние 8К полностью занимает монитор
	// Предназначена для копирования ассемблера в память

	[self.cpu mapObject:self.rom	atPage:1 from:0xE000 to:0xE7FF];

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

	[self.cpu mapObject:self.basic	atPage:6 from:0xA000 to:0xBFFF];
	
	// Страница 7, ОЗУ1 и ОЗУ2 меняются местами

	[self.cpu mapObject:self.ram2	atPage:7 from:0x0000 to:0x7FFF];
	[self.cpu mapObject:self.ram	atPage:7 from:0x8000 to:0xD7FF];

	// Страница 8, ПЗУ Бейсика подключается по адресам A000-9FFF
	// Кроме того, внешние окошко 1 подключается 8000-BFFF

	[self.cpu mapObject:self.win2	atPage:8 from:0xC800 to:0xD7FF];
	[self.cpu mapObject:self.rom	atPage:8 from:0xC000 to:0xC7FF];
	[self.cpu mapObject:self.basic	atPage:8 from:0xA000 to:0xBFFF];
	[self.cpu mapObject:self.win1	atPage:8 from:0x8000 to:0x9FFF];

	// Страница 9

	[self.cpu mapObject:self.win1	atPage:9 from:0x8000 to:0x9FFF];
	[self.cpu mapObject:self.win2	atPage:9 from:0xC800 to:0xD7FF];

	// Странца 10

	[self.cpu mapObject:self.win1	atPage:10 from:0x4000 to:0x5FFF];
	[self.cpu mapObject:self.win2	atPage:10 from:0x8000 to:0xBFFF];
	[self.cpu mapObject:self.rom	atPage:10 from:0xC000 to:0xCFFF];

	[self.cpu mapHook:self.kbdHook = [[F81B alloc] initWithRKKeyboard:self.kbd] atAddress:0xF81B];

	[self.cpu mapHook:self.inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xF806];
	self.inpHook.readError = 0xFA18;
	self.inpHook.extension = @"rkp";
	self.inpHook.type = 1;

	[self.cpu mapHook:self.outHook = [[F80C alloc] init] atAddress:0xF80C];
	self.outHook.extension = @"rkp";

	return [super mapObjects];
}

@end
