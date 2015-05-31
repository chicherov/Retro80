/*******************************************************************************
 ПЭВМ «Орион 128»
 ******************************************************************************/

#import "Orion128.h"

@implementation Orion128

+ (NSString *) title
{
	return @"Орион 128";
}

+ (NSArray *) extensions
{
	return @[@"rko"];
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(ROMDisk:)) switch (menuItem.tag)
	{
		case 0:
		{
			menuItem.submenu = [[NSMenu alloc] init];
			[menuItem.submenu addItemWithTitle:menuItem.title action:@selector(ROMDisk:) keyEquivalent:@""].tag = 1;
			[menuItem.submenu addItem:[NSMenuItem separatorItem]];

			[menuItem.submenu addItemWithTitle:@"ORDOS 2.40" action:@selector(ROMDisk:) keyEquivalent:@""].tag = 2;
			[menuItem.submenu addItemWithTitle:@"ORDOS 4.03" action:@selector(ROMDisk:) keyEquivalent:@""].tag = 3;

			menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;
			menuItem.state = self.ext.URL != nil;
			return YES;
		}

		case 1:
		{
			if ((menuItem.state = self.ext.URL != nil && ![self.ext.URL.URLByDeletingLastPathComponent.path isEqualToString:[NSBundle mainBundle].resourcePath]))
				menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"][0]) stringByAppendingFormat:@": %@", self.ext.URL.lastPathComponent];
			else
				menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;

			return YES;
		}

		case 2:
		{
			menuItem.state = [self.ext.URL.lastPathComponent isEqualToString:@"ORDOS-2.40.rom"];
			return YES;
		}

		case 3:
		{
			menuItem.state = [self.ext.URL.lastPathComponent isEqualToString:@"ORDOS-4.03.rom"];
			return YES;
		}
	}

	if (menuItem.action == @selector(extraMemory:))
	{
		menuItem.state = self.ram.length != 0x20000;
		return TRUE;
	}

	if (menuItem.action == @selector(floppy:))
	{
		if (menuItem.tag == 0)
		{
			menuItem.state = self.isFloppy ; return YES;
		}

		else if (self.isFloppy)
		{
			NSURL *url = [self.fdd getDisk:menuItem.tag]; if ((menuItem.state = url != nil))
				menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingFormat:@": %@", url.lastPathComponent];
			else
				menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingString:@":"];

			return menuItem.tag != self.fdd.selected || !self.fdd.busy;
		}

		else
		{
			menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingString:@":"];
			menuItem.state = FALSE;
			return NO;
		}
	}

	return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Внешний ROM-диск
// -----------------------------------------------------------------------------

- (IBAction) ROMDisk:(NSMenuItem *)menuItem;
{
	switch (menuItem.tag)
	{
		case 0:
		case 1:
		{
			NSOpenPanel *panel = [NSOpenPanel openPanel];
			panel.allowedFileTypes = @[@"rom", @"bin"];
			panel.title = menuItem.title;
			panel.delegate = self.ext;

			if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
			{
				[self.document registerUndoWithMenuItem:menuItem];
				self.ext.URL = panel.URLs.firstObject;
			}
			else if (self.ext.URL != nil)
			{
				[self.document registerUndoWithMenuItem:menuItem];
				self.ext.URL = nil;
			}

			break;
		}

		case 2:

			[self.document registerUndoWithMenuItem:menuItem];
			self.ext.URL = [[NSBundle mainBundle] URLForResource:@"ORDOS-2.40" withExtension:@"rom"];
			break;
			
		case 3:

			[self.document registerUndoWithMenuItem:menuItem];
			self.ext.URL = [[NSBundle mainBundle] URLForResource:@"ORDOS-4.03" withExtension:@"rom"];
			break;
			
	}
}

// -----------------------------------------------------------------------------
// Модуль ОЗУ
// -----------------------------------------------------------------------------

- (IBAction) extraMemory:(NSMenuItem *)menuItem
{
	RAM *ram = [[RAM alloc] initWithLength:self.ram.length == 0x20000 ? 0x40000 : 0x20000 mask:0xFFFF];

	if (ram) @synchronized(self.snd.sound)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		memcpy(ram.mutableBytes, self.ram.mutableBytes, 0x20000);
		self.ram = ram; [self mapObjects];
		[self.cpu reset];
	}
}

// -----------------------------------------------------------------------------
// Модуль контроллера дисковода
// -----------------------------------------------------------------------------

- (IBAction) floppy:(NSMenuItem *)menuItem
{
	if (menuItem.tag)
	{
		if (self.isFloppy)
		{
			NSOpenPanel *panel = [NSOpenPanel openPanel];
			panel.allowedFileTypes = @[@"odi", @"cpm"];
			panel.title = menuItem.title;

			if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
			{
				@synchronized(self.snd.sound)
				{
					[self.document registerUndoWithMenuItem:menuItem];
					[self.fdd setDisk:menuItem.tag URL:panel.URLs.firstObject];
				}
			}

			else if ([self.fdd getDisk:menuItem.tag] != nil)
			{
				@synchronized(self.snd.sound)
				{
					[self.document registerUndoWithMenuItem:menuItem];
					[self.fdd setDisk:menuItem.tag URL:nil];
				}
			}
		}
	}

	else @synchronized(self.snd.sound)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		if ((self.isFloppy = !self.isFloppy))
			self.isFloppy = (self.fdd = [[Orion128Floppy alloc] initWithQuartz:self.cpu.quartz]) != nil;
		else
			self.fdd = nil;

		[self mapObjects];
	}
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:22500000 start:0xF800]) == nil)
		return FALSE;

	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-1" mask:0x07FF]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x20000 mask:0xFFFF]) == nil)
		return FALSE;

	if (self.crt == nil && (self.crt = [[Orion128Screen alloc] init]) == nil)
		return FALSE;

	if (self.kbd == nil && (self.kbd = [[RKKeyboard alloc] init]) == nil)
		return FALSE;

	if (self.ext == nil && (self.ext = [[ROMDisk alloc] init]) == nil)
		return FALSE;

	if (self.isFloppy)
	{
		if (self.fdd == nil && (self.fdd = [[Orion128Floppy alloc] initWithQuartz:self.cpu.quartz]) == nil)
			return FALSE;
	}

	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	self.cpu.FF = TRUE;
	
	self.crt.memory = self.ram.mutableBytes;

	if (self.sys == nil && (self.sys = [[Orion128System alloc] init]) == nil)
		return FALSE;

	self.sys.crt = self.crt;
	self.sys.cpu = self.cpu;

	if (self.snd == nil)
	{
		self.cpu.INTE = self.sys;
		self.snd = self.sys;
	}

	self.kbd.snd = self.snd;

	if (self.inpHook == nil)
	{
		self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
		self.inpHook.mem = self.rom;
		self.inpHook.snd = self.snd;

		self.inpHook.extension = @"rko";
		self.inpHook.type = 1;
	}

	if (self.outHook == nil)
	{
		self.outHook = [[F80C alloc] initWithX8080:self.cpu];
		self.outHook.mem = self.rom;
		self.outHook.snd = self.snd;

		self.outHook.extension = @"rko";
		self.outHook.type = 1;
	}

	uint16_t F806 = (self.rom.mutableBytes[0x08] << 8) | self.rom.mutableBytes[0x07];
	uint16_t F80C = (self.rom.mutableBytes[0x0E] << 8) | self.rom.mutableBytes[0x0D];

	for (uint8_t page = 0; page < 4; page++)
	{
		MEM *mem = [self.ram memoryAtOffest:page << 16 length:0x10000 mask:0xFFFF];
		[self.cpu mapObject:mem atPage:page from:0x0000 to:0xEFFF];

		[self.cpu mapObject:self.ram atPage:page from:0xF000 to:0xF3FF];
		[self.cpu mapObject:self.kbd atPage:page from:0xF400 to:0xF4FF];
		[self.cpu mapObject:self.ext atPage:page from:0xF500 to:0xF5FF];

		if (self.isFloppy)
			[self.cpu mapObject:self.fdd atPage:page from:0xF700 to:0xF72F];

		[self.cpu mapObject:self.rom atPage:page from:0xF800 to:0xFAFF WR:self.sys];
		[self.cpu mapObject:self.rom atPage:page from:0xFB00 to:0xFFFF WR:nil];

		[self.cpu mapObject:self.inpHook atPage:page from:F806 to:F806 WR:F806 < 0xFB00 ? self.sys : nil];
		[self.cpu mapObject:self.outHook atPage:page from:F80C to:F80C WR:F80C < 0xFB00 ? self.sys : nil];
	}

	return TRUE;
}

// -----------------------------------------------------------------------------

- (id) initWithType:(NSInteger)type
{
	if (self = [super init])
	{
		switch (type)
		{
			case 1:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-1" mask:0x07FF]) == nil)
					return self = nil;

				break;

			case 2:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-2" mask:0x07FF]) == nil)
					return self = nil;

				break;

			case 3:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Orion128-3" mask:0x07FF]) == nil)
					return self = nil;

				if ((self.ram = [[RAM alloc] initWithLength:0x40000 mask:0xFFFF]) == nil)
					return self = nil;

				self.isFloppy = TRUE;
				break;
		}

		if (![self createObjects])
			return self = nil;

		if (![self mapObjects])
			return self = nil;

		self.inpHook.enabled = TRUE;
		self.outHook.enabled = TRUE;
	}

	return self;
}

// -----------------------------------------------------------------------------

- (id) init
{
	return self = [self initWithType:0];
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
	[encoder encodeObject:self.kbd forKey:@"kbd"];
	[encoder encodeObject:self.ext forKey:@"ext"];

	[encoder encodeBool:self.isFloppy forKey:@"isFloppy"];

	if (self.isFloppy)
		[encoder encodeObject:self.fdd forKey:@"fdd"];

	[encoder encodeBool:self.inpHook.enabled forKey:@"inpHook"];
	[encoder encodeBool:self.outHook.enabled forKey:@"outHook"];
}

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
	if ((self.cpu = [decoder decodeObjectForKey:@"cpu"]) == nil)
		return FALSE;

	if ((self.rom = [decoder decodeObjectForKey:@"rom"]) == nil)
		return FALSE;

	if ((self.ram = [decoder decodeObjectForKey:@"ram"]) == nil)
		return FALSE;

	if ((self.crt = [decoder decodeObjectForKey:@"crt"]) == nil)
		return FALSE;

	if ((self.kbd = [decoder decodeObjectForKey:@"kbd"]) == nil)
		return FALSE;

	if ((self.ext = [decoder decodeObjectForKey:@"ext"]) == nil)
		return FALSE;

	if ((self.isFloppy = [decoder decodeBoolForKey:@"isFloppy"]))
	{
		if ((self.fdd = [decoder decodeObjectForKey:@"fdd"]) == nil)
			return FALSE;
	}

	return TRUE;
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		if (![self decodeWithCoder:decoder])
			return self = nil;

		if (![self mapObjects])
			return self = nil;

		self.inpHook.enabled = [decoder decodeBoolForKey:@"inpHook"];
		self.outHook.enabled = [decoder decodeBoolForKey:@"outHook"];
	}

	return self;
}

@end

// =============================================================================
// Системный регистр ПЭВМ "Орион 128"
// =============================================================================

@implementation Orion128System

@synthesize sound;

@synthesize crt;
@synthesize cpu;

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	switch (addr & 0xFF00)
	{
		case 0xF800:

			crt.color = data;
			break;

		case 0xF900:

			cpu.PAGE = data & 3;
			break;

		case 0xFA00:

			crt.page = (~data & 3);
			break;
	}
}

- (void) INTE:(BOOL)IF clock:(uint64_t)clock
{
	sound.beeper = IF;
}

// -----------------------------------------------------------------------------
// DEBUG: dealloc
// -----------------------------------------------------------------------------

#ifdef DEBUG
- (void) dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
