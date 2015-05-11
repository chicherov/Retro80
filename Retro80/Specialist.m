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
	return [[@[@"rks"] arrayByAddingObjectsFromArray:[SpecialistSP580 extensions]] arrayByAddingObjectsFromArray:[SpecialistMX_RAMFOS extensions]];
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
				[menuItem.submenu addItemWithTitle:menuItem.title action:@selector(ROMDisk:) keyEquivalent:@""].tag = 1;
				[menuItem.submenu addItem:[NSMenuItem separatorItem]];

				[menuItem.submenu addItemWithTitle:@"SD STARTER ROM" action:@selector(ROMDisk:) keyEquivalent:@""].tag = 2;
				[menuItem.submenu addItemWithTitle:@"TAPE EMULATOR" action:@selector(ROMDisk:) keyEquivalent:@""].tag = 3;

				menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;
				menuItem.state = [(ROMDisk*)self.ext URL] != nil;
				return YES;
			}

			case 1:
			{
				NSURL *url = [(ROMDisk*)self.ext URL]; if ((menuItem.state = url != nil))
					menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"][0]) stringByAppendingFormat:@": %@", url.lastPathComponent];
				else
					menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;

				return YES;
			}

			case 2:
				menuItem.state = memcmp(self.rom.mutableBytes, "\xC3\x00\xD8", 3) == 0;
				return YES;

			case 3:
				menuItem.state = [(ROMDisk*)self.ext tapeEmulator];
				return [[(ROMDisk*)self.ext ROM] length] != 0 && memcmp(self.rom.mutableBytes, "\xC3\x00\xD8", 3) != 0 && self.inpHook.enabled;
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
			case 1:
			{
				NSOpenPanel *panel = [NSOpenPanel openPanel];
				panel.canChooseDirectories = TRUE;
				panel.canChooseFiles = FALSE;
				panel.title = menuItem.title;
				panel.delegate = romdisk;

				if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
				{
					[self.document registerUndoWithMenuItem:menuItem];
					romdisk.URL = panel.URLs.firstObject;
				}
				else if (romdisk.URL != nil)
				{
					[self.document registerUndoWithMenuItem:menuItem];
					romdisk.URL = nil;
				}

				break;
			}

			case 2:
			{
				@synchronized(self.snd.sound)
				{
					[self.document registerUndoWithMenuItem:menuItem];

					ROM *rom = nil; if (memcmp(self.rom.mutableBytes, "\xC3\x00\xD8", 3) != 0)
					{
						if ((rom = [[ROM alloc] initWithContentsOfResource:@"Specialist2SD" mask:0x3FFF]) != nil)
							romdisk.tapeEmulator = FALSE;
					}
					else
					{
						if ((rom = [[ROM alloc] initWithContentsOfResource:@"Specialist2" mask:0x3FFF]) != nil)
							romdisk.tapeEmulator = TRUE;
					}

					if (rom)
					{
						self.rom = rom; [self mapObjects];
					}
				}

				break;
			}

			case 3:
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
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:18000000 start:0xC000]) == nil)
		return FALSE;

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

	if (self.inpHook == nil)
	{
		self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
		self.inpHook.mem = self.rom;
		self.inpHook.snd = self.snd;

		self.inpHook.extension = @"rks";
		self.inpHook.type = 3;

		if ([self.ext isKindOfClass:[ROMDisk class]])
			[(ROMDisk *)self.ext setRecorder:self.inpHook];
	}

	if (self.outHook == nil)
	{
		self.outHook = [[F80C alloc] initWithX8080:self.cpu];
		self.outHook.mem = self.rom;

		self.outHook.extension = @"rks";
		self.outHook.type = 3;
	}
	
	[self.cpu mapObject:self.ram from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt from:0x9000 to:0xBFFF RD:self.ram];
	[self.cpu mapObject:self.rom from:0xC000 to:0xEFFF WR:nil];
	[self.cpu mapObject:self.ext from:0xF000 to:0xF7FF];
	[self.cpu mapObject:self.kbd from:0xF800 to:0xFFFF];

	[self.cpu mapObject:self.inpHook from:0xC377 to:0xC377 WR:nil];
	[self.cpu mapObject:self.outHook from:0xC3D0 to:0xC3D0 WR:nil];

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
				[(ROMDisk *)self.ext setSpecialist:TRUE];

				break;

			case 3:

				if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Lik" mask:0x3FFF]) == nil)
					return self = nil;

				break;

			case 4:

				return self = [[SpecialistSP580 alloc] init];

			case 5:

				return self = [[SpecialistMX_Commander alloc] init];

			case 6:

				return self = [[SpecialistMX_RAMFOS alloc] init];

			case 7:

				return self = [[SpecialistMX2 alloc] init];
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

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	if ([[SpecialistSP580 extensions] containsObject:url.pathExtension.lowercaseString])
		return self = [[SpecialistSP580 alloc] initWithData:data URL:url];

	if ([[SpecialistMX_RAMFOS extensions] containsObject:url.pathExtension.lowercaseString])
		return self = [[SpecialistMX_RAMFOS alloc] initWithData:data URL:url];

	const uint8_t* ptr = data.bytes;
	NSUInteger length = data.length;

	if (length > 23 && memcmp(ptr, "\x70\x8F\x82\x8F", 4) == 0)
	{
		ptr += 23; length -= 23; while (length && *ptr == 0x00)
		{
			length--; ptr++;
		}

		if (length-- && *ptr++ == 0xE6 && (self = [self initWithType:3]))
			self.inpHook.buffer = [NSData dataWithBytes:ptr length:length];
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
			self.inpHook.buffer = [NSData dataWithBytes:ptr length:length];
		else
			return self = nil;
	}

	else if (self = [self initWithType:2])
	{
		self.inpHook.buffer = data;
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

		self.inpHook.enabled = [decoder decodeBoolForKey:@"inpHook"];
		self.outHook.enabled = [decoder decodeBoolForKey:@"outHook"];
	}

	return self;
}

@end
