/*******************************************************************************
 ПЭВМ «Специалист MX»
 ******************************************************************************/

#import "SpecialistMX.h"

// =============================================================================
// Интерфейс клавиатуры ПЭВМ "Специалист MX"
// =============================================================================

@implementation SpecialistMXKeyboard

- (id) init
{
	if (self = [super init])
	{
		kbdmap = @[
				   @53,  @109, @122, @120, @99,  @118, @96,  @97,  @98,  @100, @101, @51,
				   @10,  @18,  @19,  @20,  @21,  @23,  @22,  @26,  @28,  @25,  @29,  @27,
				   @12,  @13,  @14,  @15,  @17,  @16,  @32,  @34,  @31,  @35,  @33,  @30,
				   @0,   @1,   @2,   @3,   @5,   @4,   @38,  @40,  @37,  @41,  @39,  @42,
				   @6,   @7,   @8,   @9,   @11,  @45,  @46,  @43,  @47,  @44,  @50,  @117,
				   @999, @115, @126, @125, @999, @999, @49,  @123, @48,  @124, @76,  @36
				   ];

		chr1Map = @"\x1B\x7F;1234567890-jcukeng[]zh:fywaproldv\\.q^smitxb@,/_\0\0\0 \t\x03\r";
		chr2Map = @"\x1B\x7F+!\"#$%&'() =JCUKENG{}ZH*FYWAPROLDV|>Q~SMITXB`<?\0\0\0\0 \t\x03\r";
		upperCase = FALSE;

	}

	return self;
}

@end

// =============================================================================
// Системный регистр ПЭВМ "Специалист MX"
// =============================================================================

@implementation SpecialistMXSystem

@synthesize cpu;
@synthesize crt;
@synthesize fdd;

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	switch (addr)
	{
		case 0xFFF8:

			*data = crt.color;
			break;
	}
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	switch (addr)
	{
		case 0xFFF0:	// D3.1 (pF0 - захват)

			fdd.HOLD = TRUE;
			break;

		case 0xFFF1:	// D3.2	(pF1 - мотор)

			break;
			
		case 0xFFF2:	// D4.2	(pF2 - сторона)

			fdd.head = data & 1;
			break;

		case 0xFFF3:	// D4.1	(pF3 - дисковод)

			fdd.selected = (data & 1) + 1;
			break;

		case 0xFFF8:	// Регистр цвета
		case 0xFFF9:
		case 0xFFFA:
		case 0xFFFB:

			crt.color = data;
			break;

		case 0xFFFC:	// Выбрать RAM

			cpu.PAGE = 0;
			break;

		case 0xFFFD:	// Выбрать RAM-диск

			cpu.PAGE = 1 + (data & 7);
			break;

		case 0xFFFE:	// Выбрать ROM-диск
		case 0xFFFF:

			cpu.PAGE = 9;
			break;
	}
}

- (void) RESET
{
	fdd.selected = 1;
}

@end

// =============================================================================
// ПЭВМ "Специалист MX" с MXOS (Commander)
// =============================================================================

@implementation SpecialistMX_Commander

+ (NSString *) title
{
	return @"Специалист MX";
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(extraMemory:))
	{
		switch (menuItem.tag)
		{
			case 0:

				menuItem.submenu = [[NSMenu alloc] init];
				[menuItem.submenu addItemWithTitle:@"128K" action:@selector(extraMemory:) keyEquivalent:@""].tag = 1;
				[menuItem.submenu addItemWithTitle:@"256K" action:@selector(extraMemory:) keyEquivalent:@""].tag = 2;
				[menuItem.submenu addItemWithTitle:@"512K" action:@selector(extraMemory:) keyEquivalent:@""].tag = 3;

				menuItem.state = self.ram.length != 0x20000;
				break;

			case 1:
				menuItem.state = self.ram.length == 0x30000;
				break;

			case 2:
				menuItem.state = self.ram.length == 0x50000;
				break;

			case 3:
				menuItem.state = self.ram.length == 0x90000;
				break;
		}

		return YES;
	}

	if (menuItem.action == @selector(colorModule:))
	{
		menuItem.state = self.crt.isColor;
		return YES;
	}

	if (menuItem.action == @selector(floppy:))
	{
		if (menuItem.tag == 0)
		{
			menuItem.state = TRUE; return NO;
		}
		else
		{
			NSURL *url = [self.fdd getDisk:menuItem.tag]; if ((menuItem.state = url != nil))
				menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"][0]) stringByAppendingFormat:@": %@", url.lastPathComponent];
			else
				menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"][0]) stringByAppendingString:@":"];

			return menuItem.tag != self.fdd.selected || !self.fdd.busy;
		}
	}

	if (menuItem.action == @selector(ROMDisk:))
	{
		NSURL *url = [self.ext url]; if ((menuItem.state = url != nil))
			menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"][0]) stringByAppendingFormat:@": %@", url.lastPathComponent];
		else
			menuItem.title = [menuItem.title componentsSeparatedByString:@":"][0];

		menuItem.submenu = nil;
		return YES;
	}

	return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Модуль ОЗУ
// -----------------------------------------------------------------------------

- (IBAction) extraMemory:(NSMenuItem *)menuItem
{
	unsigned size = menuItem.tag == 0 && self.ram.length == 0x20000 ? 0x30000 : 0x10000 + (1 << (menuItem.tag + 16));

	if (self.ram.length != size) @synchronized(self.snd.sound)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		RAM *ram = [[RAM alloc] initWithLength:size mask:0xFFFF];
		memcpy(ram.mutableBytes, self.ram.mutableBytes, size < self.ram.length ? size : self.ram.length);
		self.ram = ram; [self mapObjects]; self.cpu.RESET = TRUE;
	}
}

// -----------------------------------------------------------------------------
// Модуль цветности
// -----------------------------------------------------------------------------

- (IBAction) colorModule:(NSMenuItem *)menuItem
{
	[self.document registerUndoWithMenuItem:menuItem];
	self.crt.isColor = !self.crt.isColor;
}

// -----------------------------------------------------------------------------
// Модуль контроллера дисковода
// -----------------------------------------------------------------------------

- (IBAction) floppy:(NSMenuItem *)menuItem
{
	if (menuItem.tag)
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

// -----------------------------------------------------------------------------
// Внешний ROM-диск
// -----------------------------------------------------------------------------

- (IBAction) ROMDisk:(NSMenuItem *)menuItem;
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.allowedFileTypes = @[@"rom", @"bin"];
	panel.canChooseDirectories = FALSE;
	panel.title = menuItem.title;
	panel.delegate = self.ext;

	if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
	{
		[self.document registerUndoWithMenuItem:menuItem];
		self.ext.url = panel.URLs.firstObject;
	}
	else if (self.ext.url != nil)
	{
		[self.document registerUndoWithMenuItem:menuItem];
		self.ext.url = nil;
	}
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:18000000 start:0x90000]) == nil)
		return FALSE;

	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"SpecialistMX_Commander" mask:0xFFFF]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x20000 mask:0xFFFF]) == nil)
		return FALSE;

	if (self.ext == nil && (self.ext = [[ROMDisk alloc] init]) == nil)
		return FALSE;

	if ([super createObjects] == FALSE)
		return FALSE;

	if (self.fdd == nil && (self.fdd = [[VG93 alloc] initWithQuartz:self.cpu.quartz]) == nil)
		return FALSE;

	self.snd.channel0 = TRUE;
	self.snd.rkmode = TRUE;
	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	if ((self.sys = [[SpecialistMXSystem alloc] init]) == nil)
		return FALSE;

	self.crt.screen = self.ram.mutableBytes + 0x9000;

	[self.cpu mapObject:self.ram atPage:0 from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt atPage:0 from:0x9000 to:0xBFFF RD:self.ram];
	[self.cpu mapObject:self.ram atPage:0 from:0xC000 to:0xFFBF];

	[self.cpu mapObject:self.rom atPage:9 from:0x0000 to:0xBFFF WR:nil];
	[self.cpu mapObject:self.ram atPage:9 from:0xC000 to:0xFFBF];

	if (self.ram.length != 0x20000)
	{
		[self.cpu mapObject:[self.ram memoryAtOffest:0x10000 length:0x10000 mask:0xFFFF] atPage:1 from:0x0000 to:0xFFBF];
		[self.cpu mapObject:[self.ram memoryAtOffest:0x20000 length:0x10000 mask:0xFFFF] atPage:2 from:0x0000 to:0xFFBF];
		[self.cpu mapObject:[self.ram memoryAtOffest:0x30000 length:0x10000 mask:0xFFFF] atPage:3 from:0x0000 to:0xFFBF];
		[self.cpu mapObject:[self.ram memoryAtOffest:0x40000 length:0x10000 mask:0xFFFF] atPage:4 from:0x0000 to:0xFFBF];
		[self.cpu mapObject:[self.ram memoryAtOffest:0x50000 length:0x10000 mask:0xFFFF] atPage:5 from:0x0000 to:0xFFBF];
		[self.cpu mapObject:[self.ram memoryAtOffest:0x60000 length:0x10000 mask:0xFFFF] atPage:6 from:0x0000 to:0xFFBF];
		[self.cpu mapObject:[self.ram memoryAtOffest:0x70000 length:0x10000 mask:0xFFFF] atPage:7 from:0x0000 to:0xFFBF];
		[self.cpu mapObject:[self.ram memoryAtOffest:0x80000 length:0x10000 mask:0xFFFF] atPage:8 from:0x0000 to:0xFFBF];
	}
	else
	{
		MEM* mem = [self.ram memoryAtOffest:0x10000 length:0x10000 mask:0xFFFF];

		for (uint8_t page = 1; page <= 8; page++)
			[self.cpu mapObject:mem atPage:page from:0x0000 to:0xFFBF];
	}

	for (uint8_t page = 0; page <= 9; page++)
	{
		[self.cpu mapObject:self.ram	atPage:page from:0xFFC0 to:0xFFDF];
		[self.cpu mapObject:self.kbd	atPage:page from:0xFFE0 to:0xFFE3];		// U7
		[self.cpu mapObject:self.ext	atPage:page from:0xFFE4 to:0xFFE7];		// U6
		[self.cpu mapObject:self.fdd	atPage:page from:0xFFE8 to:0xFFEB];		// U5
		[self.cpu mapObject:self.snd	atPage:page from:0xFFEC to:0xFFEF];		// U4
		[self.cpu mapObject:self.sys	atPage:page from:0xFFF0 to:0xFFF3];		// U3
		[self.cpu mapObject:nil			atPage:page from:0xFFF4 to:0xFFF7];		// U2
		[self.cpu mapObject:self.sys	atPage:page from:0xFFF8 to:0xFFFB];		// U1
		[self.cpu mapObject:self.sys	atPage:page from:0xFFFC to:0xFFFF];		// U0
	}

	self.sys.cpu = self.cpu;
	self.sys.crt = self.crt;
	self.sys.fdd = self.fdd;

	self.cpu.HLDA = self.fdd;
	self.kbd.snd = self.snd;
	return TRUE;
}

// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	[encoder encodeObject:self.fdd forKey:@"fdd"];
}

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
	if (![super decodeWithCoder:decoder])
		return FALSE;

	if ((self.fdd = [decoder decodeObjectForKey:@"fdd"]) == nil)
		return FALSE;

	return TRUE;
}

@end

// =============================================================================
// ПЭВМ "Специалист MX" с RAMFOS
// =============================================================================

@implementation SpecialistMX_RAMFOS

+ (NSArray *) extensions
{
	return @[@"mon", @"cpu", @"i80"];
}

// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"SpecialistMX_RAMFOS" mask:0xFFFF]) == nil)
		return FALSE;

	if (self.kbd == nil && (self.kbd = [[SpecialistMXKeyboard alloc] init]) == nil)
		return FALSE;

	if ([super createObjects] == FALSE)
		return FALSE;

	self.crt.isColor = TRUE;
	return TRUE;
}

// -----------------------------------------------------------------------------

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	if (self = [self init])
	{
		unsigned addr; if ([url.pathExtension.lowercaseString isEqualToString:@"mon"])
		{
			NSScanner *scanner = [NSScanner scannerWithString:url.lastPathComponent.stringByDeletingPathExtension];
			scanner.scanLocation = 3; if (![scanner scanHexInt:&addr] || addr + data.length > 0xFFBF)
				return self = nil;

			memcpy(self.ram.mutableBytes + addr, data.bytes, data.length);
			self.crt.color = 0x70;
			self.cpu.PC = addr;
		}

		else
		{
			NSArray *cpu = nil; if ([url.pathExtension.lowercaseString isEqualToString:@"cpu"])
			{
				cpu = [[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding]
					   componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]];

				data = [NSData dataWithContentsOfURL:[url.URLByDeletingPathExtension URLByAppendingPathExtension:@"i80"]];
			}
			else
			{
				cpu = [[NSString stringWithContentsOfURL:[url.URLByDeletingPathExtension URLByAppendingPathExtension:@"cpu"] encoding:NSASCIIStringEncoding error:nil]
					   componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]];
			}

			if (cpu.count < 3 || data == nil)
				return self = nil;

			if (cpu.count > 4 && ((NSString *)cpu[4]).length && ![((NSString *)cpu[4]).lowercaseString isEqualToString:@"spmx.rom"])
			{
				NSData *bios; if ((bios = [NSData dataWithContentsOfURL:[url.URLByDeletingLastPathComponent URLByAppendingPathComponent:cpu[4]]]) == nil)
					return self = nil;

				NSScanner *scanner = [NSScanner scannerWithString:((NSString *)cpu[4]).stringByDeletingPathExtension];
				scanner.scanLocation = 3; if (![scanner scanHexInt:&addr] || addr + bios.length > 0xFFBF)
					return self = nil;

				memcpy(self.ram.mutableBytes + addr, bios.bytes, bios.length);

				self.cpu.RESET = FALSE;
				self.cpu.PC = addr;
				self.cpu.PAGE = 0;
			}

			[self.cpu execute:self.cpu.quartz];
			self.crt.color = 0x70;

			if (![[NSScanner scannerWithString:cpu[0]] scanHexInt:&addr] || addr + data.length > 0xFFBF)
				return self = nil;

			memcpy(self.ram.mutableBytes + addr, data.bytes, data.length);

			if (![[NSScanner scannerWithString:cpu[2]] scanHexInt:&addr] || addr + data.length > 0xFFBF)
				return self = nil;

			self.cpu.PC = addr;
		}

		self.cpu.RESET = FALSE;
		self.cpu.PAGE = 0;
	}
	
	return self;
}


@end

