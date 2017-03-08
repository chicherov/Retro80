/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Специалист MX»

 *****/

#import "SpecialistMX.h"

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
            case 1:
            {
                menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;
				menuItem.title = [menuItem.title stringByAppendingFormat:@": 64K + %luK", (self.ram.length >> 10) - 64];

                menuItem.state = FALSE;
                break;
            }

            case 6464:

                menuItem.state = self.ram.length == 128 * 1024;
                break;

            case 64128: case 64256: case 64512:

                menuItem.state = self.ram.length == (64 + menuItem.tag - 64000) * 1024;
                break;

            default:

                menuItem.state = FALSE;
                menuItem.hidden = TRUE;
                return NO;
        }

        menuItem.hidden = FALSE;
        return YES;
	}

	if (menuItem.action == @selector(colorModule:))
	{
		menuItem.state = self.crt.isColor;
		return YES;
	}

	if (menuItem.action == @selector(ROMDisk:) && menuItem.tag == 0)
	{
		NSURL *url = [self.ext URL]; if ((menuItem.state = url != nil))
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
    NSUInteger length = self.ram.length;

    switch (menuItem.tag)
    {
        case 1:

            if (length == 128 * 1024)
                length = 576 * 1024;
            else
                length = 128 * 1024;

            break;

        case 6464:

            length = 128 * 1024;
            break;

        case 64128: case 64256: case 64512:

            length = (NSUInteger) (64 + menuItem.tag - 64000) * 1024;
            break;

        default:

            return;
    }

	if (self.ram.length != length) @synchronized(self.cpu)
	{
		[self.document registerUndoWithMenuItem:menuItem];

        self.ram.length = length;
		self.ram.offset = 0x10000;

		self.crt.screen = *self.ram.pMutableBytes + 0x9000;
		[self.cpu reset];
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
// Внешний ROM-диск
// -----------------------------------------------------------------------------

- (IBAction) ROMDisk:(NSMenuItem *)menuItem;
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.allowedFileTypes = @[@"rom", @"bin"];
	panel.canChooseDirectories = TRUE;
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
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:18000000 start:0x20000]) == nil)
		return FALSE;

	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"SpecialistMX_Commander" mask:0xFFFF]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x20000 mask:0xFFFF]) == nil)
		return FALSE;

    self.ram.offset = 0x10000;

	if (self.ext == nil && (self.ext = [[ROMDisk alloc] init]) == nil)
		return FALSE;

	self.ext.specialist = TRUE;

	if ([super createObjects] == FALSE)
		return FALSE;

	self.snd.channel0 = TRUE;
	self.snd.rkmode = TRUE;
	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	self.crt.screen = *self.ram.pMutableBytes + 0x9000;

    MEM *mem = [self.ram memoryAtOffest:0x0000];

	[self.cpu mapObject:mem			atPage:0 from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt	atPage:0 from:0x9000 to:0xBFFF RD:mem];
	[self.cpu mapObject:mem			atPage:0 from:0xC000 to:0xFFBF];

    [self.cpu mapObject:self.ram	atPage:1 from:0x0000 to:0xFFBF];

	[self.cpu mapObject:self.rom	atPage:2 from:0x0000 to:0xBFFF WR:nil];
	[self.cpu mapObject:mem			atPage:2 from:0xC000 to:0xFFBF];

	if (self.sys == nil && (self.sys = [[SpecialistMXSystem alloc] init]) == nil)
		return FALSE;

	for (uint8_t page = 0; page <= 2; page++)
	{
		[self.cpu mapObject:mem			atPage:page from:0xFFC0 to:0xFFDF];
		[self.cpu mapObject:self.kbd	atPage:page from:0xFFE0 to:0xFFE3];		// U7
		[self.cpu mapObject:self.ext	atPage:page from:0xFFE4 to:0xFFE7];		// U6
		[self.cpu mapObject:nil			atPage:page from:0xFFE8 to:0xFFEB];		// U5
		[self.cpu mapObject:self.snd	atPage:page from:0xFFEC to:0xFFEF];		// U4
		[self.cpu mapObject:self.sys	atPage:page from:0xFFF0 to:0xFFF3];		// U3
		[self.cpu mapObject:nil			atPage:page from:0xFFF4 to:0xFFF7];		// U2
		[self.cpu mapObject:self.sys	atPage:page from:0xFFF8 to:0xFFFB];		// U1
		[self.cpu mapObject:self.sys	atPage:page from:0xFFFC to:0xFFFF];		// U0
	}

	self.sys.cpu = self.cpu;
    self.sys.ram = self.ram;
	self.sys.crt = self.crt;
	self.kbd.snd = self.snd;
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

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(colorModule:))
	{
		menuItem.state = TRUE; return NO;
	}

	if (menuItem.action == @selector(floppy:))
	{
		if (menuItem.tag == 0)
		{
			menuItem.state = TRUE;
			return NO;
		}
		else
		{
			NSURL *url = [self.fdd getDisk:menuItem.tag]; if ((menuItem.state = url != nil))
				menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingFormat:@": %@", url.lastPathComponent];
			else
				menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingString:@":"];

			return menuItem.tag != self.fdd.selected || !self.fdd.busy;
		}
	}

	return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Модуль контроллера дисковода
// -----------------------------------------------------------------------------

- (IBAction) floppy:(NSMenuItem *)menuItem
{
	if (menuItem.tag >= 1 && menuItem.tag <= 2)
	{
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		panel.allowedFileTypes = @[@"odi", @"kdi", @"cpm"];
		panel.title = menuItem.title;

		if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
		{
			@synchronized(self.cpu)
			{
				[self.document registerUndoWithMenuItem:menuItem];
				[self.fdd setDisk:menuItem.tag URL:panel.URLs.firstObject];
			}
		}
		else if ([self.fdd getDisk:menuItem.tag] != nil)
		{
			@synchronized(self.cpu)
			{
				[self.document registerUndoWithMenuItem:menuItem];
				[self.fdd setDisk:menuItem.tag URL:nil];
			}
		}
	}
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

	if (self.fdd == nil && (self.fdd = [[VG93 alloc] initWithQuartz:self.cpu.quartz]) == nil)
		return FALSE;

	self.crt.isColor = TRUE;
	return TRUE;
}

- (BOOL) mapObjects
{
	if (![super mapObjects])
		return FALSE;

	for (uint8_t page = 0; page <= 9; page++)
		[self.cpu mapObject:self.fdd	atPage:page from:0xFFE8 to:0xFFEB];		// U5

	self.cpu.HLDA = self.fdd;
	self.sys.fdd = self.fdd;

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

// -----------------------------------------------------------------------------

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	if (self = [self initWithType:0])
	{
		unsigned addr; if ([url.pathExtension.lowercaseString isEqualToString:@"mon"])
		{
			NSScanner *scanner = [NSScanner scannerWithString:url.lastPathComponent.stringByDeletingPathExtension];
			scanner.scanLocation = 3; if (![scanner scanHexInt:&addr] || addr + data.length > 0xFFBF)
				return self = nil;

			memcpy(*self.ram.pMutableBytes + addr, data.bytes, data.length);
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

                memcpy(*self.ram.pMutableBytes + addr, bios.bytes, bios.length);

				self.cpu.PC = addr;
				self.cpu.PAGE = 0;
			}

			[self.cpu execute:self.cpu.quartz];
			self.crt.color = 0x70;

			if (![[NSScanner scannerWithString:cpu[0]] scanHexInt:&addr] || addr + data.length > 0xFFBF)
				return self = nil;

			memcpy(*self.ram.pMutableBytes + addr, data.bytes, data.length);

			if (![[NSScanner scannerWithString:cpu[2]] scanHexInt:&addr] || addr + data.length > 0xFFBF)
				return self = nil;

			self.cpu.PC = addr;
		}

		self.cpu.PAGE = 0;
	}
	
	return self;
}

@end

// =============================================================================
// ПЭВМ "Специалист MX2"
// =============================================================================

@implementation SpecialistMX2

- (BOOL) mapObjects
{
	if (self.sys == nil && (self.sys = [[SpecialistMX2System alloc] init]) == nil)
		return FALSE;

	if (![super mapObjects])
		return FALSE;

	if (self.rom.length <= 0x8000)
		return FALSE;

    MEM *mem = [self.ram memoryAtOffest:0x0000];

	[self.cpu mapObject:[self.rom memoryAtOffest:0x8000 mask:0x7FFF]
                 atPage:2 from:0x0000 to:0x7FFF WR:nil];

	[self.cpu mapObject:mem			atPage:2 from:0x8000 to:0x8FFF];
	[self.cpu mapObject:self.crt	atPage:2 from:0x9000 to:0xBFFF RD:mem];

	[self.cpu mapObject:self.rom	atPage:4 from:0x0000 to:0x7FFF WR:nil];
	[self.cpu mapObject:mem			atPage:5 from:0x0000 to:0x7FFF];

	for (uint8_t page = 4; page <= 5; page++)
	{
		[self.cpu mapObject:mem      atPage:page from:0x8000 to:0x8FFF];
		[self.cpu mapObject:self.crt atPage:page from:0x9000 to:0xBFFF RD:mem];
		[self.cpu mapObject:mem      atPage:page from:0xC000 to:0xEFFF];

		for (uint16_t addr = 0xF000; addr < 0xF800; addr += 32)
		{
			[self.cpu mapObject:self.kbd	atPage:page from:addr + 0x00 to:addr + 0x03];		// U7
			[self.cpu mapObject:self.ext	atPage:page from:addr + 0x04 to:addr + 0x07];		// U6
			[self.cpu mapObject:self.fdd	atPage:page from:addr + 0x08 to:addr + 0x0B];		// U5
			[self.cpu mapObject:self.snd	atPage:page from:addr + 0x0C to:addr + 0x0F];		// U4
			[self.cpu mapObject:self.sys	atPage:page from:addr + 0x10 to:addr + 0x13];		// U3
			[self.cpu mapObject:nil			atPage:page from:addr + 0x14 to:addr + 0x17];		// U2
			[self.cpu mapObject:self.sys	atPage:page from:addr + 0x18 to:addr + 0x1B];		// U1
			[self.cpu mapObject:self.sys	atPage:page from:addr + 0x1C to:addr + 0x1F];		// U0
		}

		[self.cpu mapObject:self.kbd atPage:page from:0xF800 to:0xFFFF];
	}

	if ((self.cpu.PAGE & ~1) == 4)
		self.kbd.crt = self.crt;
	else
		self.kbd.crt = nil;

	self.sys.kbd = self.kbd;

	return TRUE;
}

- (BOOL) createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"SpecialistMX2" mask:0x7FFF]) == nil)
		return FALSE;

	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:18000000 start:0x40000]) == nil)
		return FALSE;

	if (![super createObjects])
		return FALSE;

	self.ext.flashDisk = TRUE;
	return TRUE;
}

@end
