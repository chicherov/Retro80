/*******************************************************************************
 ПЭВМ «Специалист»
 ******************************************************************************/

#import "Specialist.h"
#import "SpecialistSP580.h"
#import "SpecialistMX.h"

@implementation Specialist

+ (NSString *) title
{
	return @"Специалист";
}

+ (NSArray *) extensions
{
	return [@[@"rks"] arrayByAddingObjectsFromArray:[SpecialistMX extensions]];
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(ROMDisk:) && [self.ext isKindOfClass:[ROMDisk class]])
	{
		switch (menuItem.tag)
		{
			case 0:
			{

				menuItem.submenu = [[NSMenu alloc] init];
				[menuItem.submenu addItemWithTitle:@"SD STARTER ROM" action:@selector(ROMDisk:) keyEquivalent:@""].tag = 1;
				[menuItem.submenu addItemWithTitle:@"TAPE EMULATOR" action:@selector(ROMDisk:) keyEquivalent:@""].tag = 2;

				NSURL *url = [(ROMDisk*)self.ext url]; if ((menuItem.state = url != nil))
					menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"][0]) stringByAppendingFormat:@": %@", url.lastPathComponent];
				else
					menuItem.title = [menuItem.title componentsSeparatedByString:@":"][0];

				return YES;
			}

			case 1:
				menuItem.state = self.rom.length == 8192;
				return YES;

			case 2:
				menuItem.state = [(ROMDisk*)self.ext tapeEmulator];
				return [(ROMDisk*)self.ext length] != 0 && self.rom.length != 8192 && self.inpHook.enabled;
		}
	}

	if (menuItem.action == @selector(colorModule:))
	{
		menuItem.state = self.crt.isColor;
		return self.kbd.crt != nil;
	}

	return [super validateMenuItem:menuItem];
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
	if ([self.ext isKindOfClass:[ROMDisk class]])
	{
		ROMDisk *romdisk = (ROMDisk *)self.ext;
		switch (menuItem.tag)
		{
			case 0:
			{
				NSOpenPanel *panel = [NSOpenPanel openPanel];
				panel.canChooseDirectories = TRUE;
				panel.canChooseFiles = FALSE;
				panel.title = menuItem.title;
				panel.delegate = romdisk;

				if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
				{
					[self.document registerUndoWithMenuItem:menuItem];
					romdisk.url = panel.URLs.firstObject;
				}
				else if (romdisk.url != nil)
				{
					[self.document registerUndoWithMenuItem:menuItem];
					romdisk.url = nil;
				}

				break;
			}

			case 1:
			{
				@synchronized(self.snd.sound)
				{
					ROM *rom; if ((rom = [[ROM alloc] initWithContentsOfResource:self.rom.length == 8192 ? @"Specialist2" : @"Specialist2SD" mask:0x3FFF]) != nil)
					{
						[self.document registerUndoWithMenuItem:menuItem];

						[self.cpu mapObject:self.rom = rom from:0xC000 to:0xEFFF WR:nil];
						if (rom.length == 8192) romdisk.tapeEmulator = FALSE;
					}
				}

				break;
			}

			case 2:
			{
				romdisk.tapeEmulator = !romdisk.tapeEmulator;
				break;
			}
		}

	}
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:18000000]) == nil)
		return FALSE;

	self.cpu.START = 0xC000;

	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Specialist2" mask:0x3FFF]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0xC000 mask:0xFFFF]) == nil)
		return FALSE;

	if (self.crt == nil && (self.crt = [[SpecialistScreen alloc] init]) == nil)
		return FALSE;

	if (self.kbd == nil && (self.kbd = [[SpecialistKeyboard alloc] init]) == nil)
		return FALSE;

	if (self.ext == nil && (self.ext = [[X8255 alloc] init]) == nil)
		return FALSE;

	if (self.snd == nil && (self.snd = [[X8253 alloc] init]) == nil)
		return FALSE;

	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	self.crt.screen = self.ram.mutableBytes + 0x9000;

	[self.cpu mapObject:self.ram from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt from:0x9000 to:0xBFFF RD:self.ram];
	[self.cpu mapObject:self.rom from:0xC000 to:0xEFFF WR:nil];
	[self.cpu mapObject:self.ext from:0xF000 to:0xF7FF];
	[self.cpu mapObject:self.kbd from:0xF800 to:0xFFFF];

	[self.cpu addObjectToRESET:self.kbd];
	[self.cpu addObjectToRESET:self.ext];

	self.kbdHook = [[F812 alloc] initWithRKKeyboard:self.kbd];
	[self.cpu mapHook:[[F803 alloc] initWithF812:(F812 *)self.kbdHook] atAddress:0xC337];

	[self.cpu mapHook:self.inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xC377];
	self.inpHook.extension = @"rks";
	self.inpHook.type = 3;

	if ([self.ext isKindOfClass:[ROMDisk class]])
		[(ROMDisk *)self.ext setRecorder:self.inpHook];

	[self.cpu mapHook:self.outHook = [[F80C alloc] init] atAddress:0xC3D0];
	self.outHook.extension = @"rks";
	self.outHook.type = 3;

	self.kbd.crt = self.crt;
	self.kbd.snd = self.snd;
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

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Specialist1" mask:0x3FFF]) == nil)
					return self = nil;

				break;

			case 2:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Specialist2" mask:0x3FFF]) == nil)
					return self = nil;

				if ((self.ext = [[ROMDisk alloc] init]) == nil)
					return self = nil;

				[(ROMDisk *)self.ext setTapeEmulator:TRUE];

				break;

			case 3:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"SpecialistW" mask:0x3FFF]) == nil)
					return self = nil;

				break;
				
			case 4:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"SpecialistL" mask:0x3FFF]) == nil)
					return self = nil;

				break;

			case 5:

				return self = [[SpecialistSP580 alloc] init];

			case 6:

				return self = [[SpecialistMX alloc] init];
		}

		if (![self createObjects])
			return self = nil;

		if (![self mapObjects])
			return self = nil;

		self.kbdHook.enabled = FALSE;
		self.kbd.qwerty = TRUE;

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

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	if ([[SpecialistMX extensions] containsObject:url.pathExtension.lowercaseString])
		return self = [[SpecialistMX alloc] initWithData:data URL:url];

	const uint8_t* ptr = data.bytes;
	NSUInteger length = data.length;

	if (length > 23 && memcmp(ptr, "\x70\x8F\x82\x8F", 4) == 0)
	{
		ptr += 23; length -= 23; while (length && *ptr == 0x00)
		{
			length--; ptr++;
		}

		if (length-- && *ptr++ == 0xE6 && (self = [self initWithType:4]))
			[self.inpHook setData:[NSData dataWithBytes:ptr length:length]];
		else
			return self = nil;
	}

	else if (length > 4 && memcmp(ptr, "\xD9\xD9\xD9", 3) == 0)
	{
		ptr += 3; length -= 3; while (length && *ptr != 0x00)
		{
			length--; ptr++;
		}

		while (length && *ptr == 0x00)
		{
			length--; ptr++;
		}

		if (length-- && *ptr++ == 0xE6 && (self = [self initWithType:2]))
			[self.inpHook setData:[NSData dataWithBytes:ptr length:length]];
		else
			return self = nil;
	}

	else if (self = [self initWithType:2])
	{
		[self.inpHook setData:data];
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
	[encoder encodeObject:self.kbd forKey:@"kbd"];
	[encoder encodeObject:self.ext forKey:@"ext"];
	[encoder encodeObject:self.snd forKey:@"snd"];

	[encoder encodeBool:self.kbdHook.enabled forKey:@"kbdHook"];
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

	if ((self.snd = [decoder decodeObjectForKey:@"snd"]) == nil)
		return FALSE;

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

		self.kbdHook.enabled = [decoder decodeBoolForKey:@"kbdHook"];
		self.inpHook.enabled = [decoder decodeBoolForKey:@"inpHook"];
		self.outHook.enabled = [decoder decodeBoolForKey:@"outHook"];
	}

	return self;
}

@end
