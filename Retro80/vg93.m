/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 КР1818ВГ93

 *****/

#import "vg93.h"

#ifndef NDEBUG
	#define NDEBUG
#endif

@implementation VG93
{
	unsigned ms200, ms;
	unsigned TRACK[4];
	NSURL *URLs[4];

	BOOL DIRC;

	uint64_t started;
	uint64_t DRQ;

	NSFileHandle *file;
	BOOL readOnly;
	BOOL newDisk;

	unsigned TRACKS;
	unsigned HEADS;
	unsigned SECTORS;
	unsigned SECSIZE;

	NSMutableData *write;
	NSData *read;

	unsigned length;
	unsigned pos;
	uint8_t *ptr;
}

@synthesize enabled;

@synthesize selected;
@synthesize head;
@synthesize HOLD;

//------------------------------------------------------------------------------
// setDisk/getDisk
//------------------------------------------------------------------------------

- (void) setDisk:(NSInteger)disk URL:(NSURL *)url
{
	if (disk >= 1 && disk <= 4)
	{
		if (disk != selected)
			URLs[disk-1] = url;

		else if (!self.busy)
		{
			self.selected = 0; URLs[disk-1] = url;
			self.selected = (unsigned)disk;
		}
	}
}

- (NSURL *) getDisk:(NSInteger)disk
{
	if (disk >= 1 && disk <= 4)
		return URLs[disk-1];

	return nil;
}

- (BOOL) busy
{
	return write != nil || read != nil;
}

//------------------------------------------------------------------------------
// select disk
//------------------------------------------------------------------------------

- (void) setSelected:(unsigned int)disk
{
	if (selected != disk)
	{
		if (started)
		{
			write = nil; read = nil;
			started = 0; DRQ = -1;
		}

		if (file)
		{
			[file closeFile];
			file = nil;
		}

		if (disk && URLs[disk - 1] != nil)
		{
			readOnly = NO;

			if ((file = [NSFileHandle fileHandleForUpdatingAtPath:URLs[disk - 1].path]) == nil)
				if ((file = [NSFileHandle fileHandleForReadingAtPath:URLs[disk - 1].path]) != nil)
					readOnly = YES;

			if (file)
			{
				unsigned long long fileSize = file.seekToEndOfFile;

				if ((newDisk = fileSize == 0))
				{
					TRACKS = 0; HEADS = 1; SECTORS = 0; SECSIZE = 0;
				}

				else switch (fileSize)
				{
					case 819200:

						TRACKS = 80; HEADS = 2; SECTORS = 5; SECSIZE = 1024;
						break;

					case 737280:

						TRACKS = 80; HEADS = 2; SECTORS = 9; SECSIZE = 512;
						break;

					default:
						file = nil;
						break;
				}
			}
		}

		selected = disk;
	}
}

- (unsigned) selected
{
	return selected;
}

//------------------------------------------------------------------------------
// Команды первого типа
//------------------------------------------------------------------------------

- (void) step
{
	if (command.code > 1 || shift != cylinder)
	{
		if (command.code < 2)
		{
			if ((DIRC = shift > cylinder))
				cylinder++;
			else
				cylinder--;
		}

		else if (command.u)
		{
			if (DIRC)
				cylinder++;
			else
				cylinder--;
		}

		if (selected && TRACK[selected-1] == 0 && DIRC == NO)
		{
			status.S2 = 1; cylinder = 0;
		}
		else
		{
			static unsigned timing[4] = { 6, 12, 20, 30 };
			started += timing[command.r] * ms;

			if (DIRC)
			{
				if (selected && TRACK[selected-1] < 83)
					TRACK[selected-1]++;
			}
			else
			{
				if (selected && TRACK[selected-1])
					TRACK[selected-1]--;
			}
		}
	}

	if (command.V && (command.code > 1 || shift == cylinder || status.S2))
	{
		started += ms * 15; started += ms200 - started % ms200;

		if (file == nil || selected == 0 || cylinder != TRACK[selected-1] || TRACK[selected-1] >= TRACKS)
			started += ms200 * 8;
	}
}

//------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------

- (void) execute:(uint64_t)clock
{
	if (started && started <= clock)
	{
		if ((command.code & 8) == 0)
		{
			if (command.code < 2)
			{
				while (started <= clock && shift != cylinder && !status.S2)
					[self step];

				if (started > clock)
					return;
			}

			if (command.V)
			{
				if (selected == 0 || cylinder != TRACK[selected-1] || TRACK[selected-1] >= TRACKS)
					status.S4 = 1;
			}
		}

		else if (file == nil)
		{
			status.S7 = 1;
		}

		else if ((command.code & 4) == 0)
		{
			if ((command.code & 2) == 0)
			{
				if (read == nil)
					status.S4 = 1;
				else
					status.S2 = 1;
			}
			else if (!readOnly)
			{
				if (write == nil)
					status.S4 = 1;
				else
					status.S2 = 1;
			}
			else
			{
				status.S6 = 1;
			}
		}

		else if (command.code == 0xF)
		{
			if (!readOnly)
			{
				if (write == nil)
					status.S5 = 1;
				else
					status.S2 = 1;
			}
			else
			{
				status.S6 = 1;
			}
		}

		else
		{
			status.S7 = 1;
		}


		write = nil; read = nil;
		started = 0; DRQ = -1;
	}
}

//------------------------------------------------------------------------------
// RD/WR/RESET
//------------------------------------------------------------------------------

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	[self execute:clock];

	switch (addr & 3)
	{
		case 0:

			if ((status.S0 = started != 0))
			{
				if ((command.code & 0x8) == 0)
					status.S1 = clock % ms200 < ms;
				else
					status.S1 = DRQ < clock;
			}
			else
			{
				status.S7 = file == nil;
			}

			*data = status.byte;
			break;

		case 1:

			*data = cylinder;
			break;

		case 2:

			*data = sector;
			break;

		case 3:

			[self RD:data clock:clock];
			break;
	}
}

//------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	[self execute:clock];

	switch (addr & 3)
	{
		case 0:

			if ((data & 0xF0) == 0xD0)	// Принудительное прерывание
			{
#ifndef NDEBUG
				NSLog(@"ВГ93 Принудительное прерывание: %02X", data);
#endif
				if (started && command.code == 0xF)
				{
					length = pos; [self WR:shift clock:DRQ];
				}

				write = nil; read = nil;
				started = 0; DRQ = -1;
			}

			else if (started == 0)
			{
				command.byte = data;
				status.byte = 0;
				started = clock;

#ifndef NDEBUG
				switch (command.code)
				{
					case 0x0:	// Восстановление
						NSLog(@"ВГ93 Восстановление: h=%d, V=%d, r=%d", command.h, command.V, command.r); break;

					case 0x1:	// Поиск
						NSLog(@"ВГ93 Поиск: h=%d, V=%d, r=%d", command.h, command.V, command.r); break;

					case 0x2:	// Шаг
					case 0x3:
						NSLog(@"ВГ93 Шаг: u=%d, h=%d, V=%d, r=%d", command.u, command.h, command.V, command.r); break;

					case 0x4:	// Шаг вперед
					case 0x5:
						NSLog(@"ВГ93 Шаг вперед: u=%d, h=%d, V=%d, r=%d", command.u, command.h, command.V, command.r); break;

					case 0x6:	// Шаг назад
					case 0x7:
						NSLog(@"ВГ93 Шаг назад: u=%d, h=%d, V=%d, r=%d", command.u, command.h, command.V, command.r); break;

					case 0x8:	// Чтение сектора
					case 0x9:
						NSLog(@"ВГ93 Чтение сектора: m=%d, s=%d, E=%d, C=%d", command.m, command.s, command.E, command.C); break;

					case 0xA:	// Запись сектора
					case 0xB:
						NSLog(@"ВГ93 Запись сектора: m=%d, s=%d, E=%d, C=%d, a=%d", command.m, command.s, command.E, command.C, command.a); break;

					case 0x0C:	// Чтение адреса
						NSLog(@"ВГ93 Чтение адреса: E=%d", command.E); break;

					case 0xE:	// Чтение дорожки
						NSLog(@"ВГ93 Чтение дорожки: E=%d", command.E); break;

					case 0xF:	// Запись дорожки
						NSLog(@"ВГ93 Запись дорожки: E=%d", command.E);	break;
				}
#endif

				if ((command.code & 8) == 0)		// Восстановление, поиск, шаг
				{
					status.S5 = command.h;
					status.S6 = readOnly;

					if (command.code & 4)
						DIRC = (command.code & 2) == 0;

					else if (command.code == 0)
					{
						cylinder = 255;
						shift = 0;
					}

					[self step];
				}

				else if (file == nil)
					status.S7 = 1;

				else if ((command.code & 4) == 0)	// Чтение/запись сектора
				{
					if (command.E)
						started += ms * 15;

					if ((command.code & 2) == 0 || !readOnly)
					{
						if (selected && cylinder == TRACK[selected-1] && TRACK[selected-1] < TRACKS && head < HEADS && sector && sector <= SECTORS)
						{
							[file seekToFileOffset:((cylinder * HEADS + head) * SECTORS + sector - 1) * SECSIZE];

							if ((command.code & 2) == 0)
							{
#ifndef NDEBUG
								NSLog(@"ВГ93 Read from drive %c: track %d head %d sector %d", selected - 1 + 'A', cylinder, head, sector);
#endif
								if ((read = [file readDataOfLength:SECSIZE]).length != SECSIZE)
									read = [[NSMutableData alloc] initWithLength:SECSIZE];

								ptr = (uint8_t *) read.bytes;
							}
							else
							{
#ifndef NDEBUG
								NSLog(@"ВГ93 Write to drive %c:  track %d head %d sector %d", selected - 1 + 'A', cylinder, head, sector);
#endif
								write = [[NSMutableData alloc] initWithLength:SECSIZE];
								ptr = write.mutableBytes;
							}

							DRQ = started + ms200 / SECTORS - started % (ms200 / SECTORS);
							unsigned s = DRQ / (ms200 / SECTORS) % SECTORS + 1;
							s = s > sector ? sector + SECTORS - s : sector - s;
							DRQ += ms200 / SECTORS * s;

							started = DRQ + ms200 / SECTORS;
							length = SECSIZE; pos = 0;
						}

						else
						{
							started += ms200 * 5 - started % ms200;
						}
					}
				}

				else if (command.code == 0x0F)	// // Запись дорожки
				{
					if (newDisk)
					{
						if (head == 0)
						{
							if (cylinder == TRACKS)
								TRACKS++;
						}
						else if (HEADS == 1)
						{
							if (TRACKS == 1 && SECTORS && SECSIZE)
								HEADS++;
						}
					}

					if (command.E)
						started += ms * 15;

					if (!readOnly)
					{
						if (selected && cylinder == TRACK[selected-1] && TRACK[selected-1] < TRACKS && head < HEADS)
						{
							write = [[NSMutableData alloc] initWithLength:6250];

							DRQ = started; started = started + ms200 * 2 - started % ms200;

							ptr = write.mutableBytes;
							length = 6250;
							pos = 0;
						}

						else
						{
							started += ms200 * 5 - started % ms200;
						}
					}
				}

				if (started == clock)
					started += ms / 10;
			}

			break;

		case 1:

			cylinder = data;
			break;

		case 2:

			sector = data;
			break;

		case 3:

			[self WR:data clock:clock];
			break;
	}
}

//------------------------------------------------------------------------------

- (void) RESET:(uint64_t)clock
{
	if (selected)
		TRACK[selected-1] = 0;

	self.selected = 0;

	command.byte = 0x03; status.byte = 0x04;
	cylinder = 0; shift = 0; sector = 1;
}

//------------------------------------------------------------------------------
// Работа с DMA
//------------------------------------------------------------------------------

- (uint64_t *) DRQ
{
	return &DRQ;
}

- (void) RD:(uint8_t *)data clock:(uint64_t)clock
{
	status.S1 = 0; if (read && clock > DRQ)
	{
		DRQ += ms200 / 6250; while (DRQ < clock && pos < length)
		{
			status.S2 = 1; shift = ptr[pos++];
			DRQ += ms200 / 6250;
		}

		if (pos < length)
			shift = ptr[pos++];

		if (pos == length)
		{
			if (command.m)
			{
				sector++; if (sector <= SECTORS && (read = [file readDataOfLength:SECSIZE]).length == SECSIZE)
				{
#ifdef DBUG
					NSLog(@"ВГ93 Read next sector %d", sector);
#endif

					DRQ += ms200 / SECTORS - DRQ % (ms200 / SECTORS); started += ms200;
					ptr = (uint8_t *) read.bytes; length = SECSIZE; pos = 0;
				}
				else
				{
					read = nil; started += ms200 * 4; DRQ = -1;
				}
			}
			else
			{
				read = nil; started = 0; DRQ = -1;
			}
		}
	}

	*data = shift;
}

- (void) WR:(uint8_t)data clock:(uint64_t)clock
{
	status.S1 = 0; if (write)
	{
		DRQ += ms200 / 6250; while (DRQ < clock && pos < length)
		{
			status.S2 = 1; ptr[pos++] = shift;
			DRQ += ms200 / 6250;

			if (command.code == 0xF && pos < 4)
			{
				started = 0;
				write = nil;
				DRQ = -1;
				return;
			}
		}

		shift = data; if (pos < length)
		{
			ptr[pos++] = data;

			if (command.code == 0xF && pos == 3)
				DRQ += ms200 - DRQ % ms200;
		}

		if (pos == length)
		{
			if (command.code != 0xF)
			{
				[file writeData:write];

				started = 0;
				write = nil;
				DRQ = -1;
			}

			else
			{
				for (pos = 0; pos < length; pos++) if (pos + 7 <= length && ptr[pos] == 0xF5 && ptr[pos + 1] == 0xFE && ptr[pos + 6] == 0xF7)
				{
					if (newDisk && TRACKS == 1 && HEADS == 1)
					{
						if (SECTORS < ptr[pos + 4] && ptr[pos + 4] <= 32)
							SECTORS = ptr[pos + 4];

						if (SECSIZE == 0 && ptr[pos + 5] < 4)
							SECSIZE = 128 << ptr[pos + 5];
					}

					if (ptr[pos + 2] != cylinder || ptr[pos + 3] != head || ptr[pos + 4] == 0x00 || ptr[pos + 4] > SECTORS || 128 << ptr[pos + 5] != SECSIZE)
					{
						status.S5 = 1; length = 0; break;
					}

					[file seekToFileOffset:((cylinder * HEADS + head) * SECTORS + ptr[pos + 4] - 1) * SECSIZE];

					for (pos += 7; pos + 1 < length; pos++) if (ptr[pos] == 0xF5 && ptr[pos + 1] != 0xF5)
					{
						if (ptr[pos + 1] != 0xFB || pos + SECSIZE + 3 > length || ptr[pos + 2 + SECSIZE] != 0xF7)
						{
							status.S5 = 1; length = 0; break;
						}

						[file writeData:[NSData dataWithBytes:ptr + pos + 2 length:SECSIZE]];

						pos += SECSIZE + 3;
						break;
					}
				}
				
				started = 0;
				write = nil;
				DRQ = -1;
			}
		}
	}
	else
	{
		shift = data;
	}
}

//------------------------------------------------------------------------------
// HLDA
//------------------------------------------------------------------------------

- (unsigned) HLDA:(uint64_t)clock clk:(unsigned int)clk
{
	if (HOLD)
	{
		HOLD = NO; if (DRQ == -1 || DRQ < clock)
			return 0;

		clk = (unsigned) (DRQ - clock);
		clk += 9 - clk % 9; return clk;
	}

	return 0;
}

//------------------------------------------------------------------------------
// Инициализация
//------------------------------------------------------------------------------

- (id) initWithQuartz:(unsigned)quartz
{
	if (self = [super init])
	{
		ms = (ms200 = quartz / 5) / 200; DRQ = -1;
		enabled = YES;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:ms200 * 5 forKey:@"quartz"];
	[encoder encodeBool:enabled forKey:@"enabled"];

	[encoder encodeObject:URLs[0] forKey:@"urlA"];
	[encoder encodeObject:URLs[1] forKey:@"urlB"];
	[encoder encodeObject:URLs[2] forKey:@"urlC"];
	[encoder encodeObject:URLs[3] forKey:@"urlD"];

	[encoder encodeInt:TRACK[0] forKey:@"TRACKA"];
	[encoder encodeInt:TRACK[1] forKey:@"TRACKB"];
	[encoder encodeInt:TRACK[2] forKey:@"TRACKC"];
	[encoder encodeInt:TRACK[3] forKey:@"TRACKD"];
	[encoder encodeBool:DIRC forKey:@"DIRC"];

	[encoder encodeInt:selected forKey:@"selected"];
	[encoder encodeInt:head forKey:@"head"];

	[encoder encodeInt:cylinder forKey:@"cylinder"];
	[encoder encodeInt:sector forKey:@"sector"];
	[encoder encodeInt:shift forKey:@"shift"];
}

- (instancetype) initWithCoder:(NSCoder *)decoder
{
	if (self = [self initWithQuartz:[decoder decodeIntForKey:@"quartz"]])
	{
		enabled = [decoder decodeBoolForKey:@"enabled"];

		URLs[0] = [decoder decodeObjectForKey:@"urlA"];
		URLs[1] = [decoder decodeObjectForKey:@"urlB"];
		URLs[2] = [decoder decodeObjectForKey:@"urlC"];
		URLs[3] = [decoder decodeObjectForKey:@"urlD"];

		self.selected = [decoder decodeIntForKey:@"selected"];
		head = [decoder decodeIntForKey:@"head"];

		TRACK[0] = [decoder decodeIntForKey:@"TRACKA"];
		TRACK[1] = [decoder decodeIntForKey:@"TRACKB"];
		TRACK[2] = [decoder decodeIntForKey:@"TRACKC"];
		TRACK[3] = [decoder decodeIntForKey:@"TRACKD"];
		DIRC = [decoder decodeBoolForKey:@"DIRC"];

		cylinder = [decoder decodeIntForKey:@"cylinder"];
		sector = [decoder decodeIntForKey:@"sector"];
		shift = [decoder decodeIntForKey:@"shift"];
	}

	return self;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(floppy:))
	{
		menuItem.hidden = menuItem.tag < 1 || menuItem.tag > 4;

		switch (menuItem.tag)
		{
			case 1:
			case 2:
			{
				menuItem.hidden = false;
				break;
			}

			case 3:
			case 4:
			{
				menuItem.hidden = menuItem.tag == ([self.computer isKindOfClass:NSClassFromString(@"Partner")] ? 3 : 4);
				menuItem.state = self.isEnabled;
				return !self.busy;
			}

			default:
			{
				menuItem.hidden = true;
				menuItem.state = NO;
				return NO;
			}

		}

		NSURL *url = [self getDisk:menuItem.tag];

		if ((menuItem.state = url != nil))
			menuItem.title = [[menuItem.title componentsSeparatedByString:@":"].firstObject stringByAppendingFormat:@": %@", url.lastPathComponent];
		else
			menuItem.title = [[menuItem.title componentsSeparatedByString:@":"].firstObject stringByAppendingString:@":"];

		return self.isEnabled && (menuItem.tag != selected || !self.busy);
	}

	return NO;
}

- (IBAction)floppy:(NSMenuItem *)menuItem;
{
	if (menuItem.tag == 3 || menuItem.tag == 4)
	{
		@synchronized(self.computer)
		{
			[self.computer registerUndoWithMenuItem:menuItem];
			self.enabled = self.isEnabled ? self.busy : YES;
		}
	}

	else if ((menuItem.tag == 1 || menuItem.tag == 2) && self.isEnabled)
	{
		NSOpenPanel *panel = [NSOpenPanel openPanel];

		panel.allowedFileTypes = [self.computer isKindOfClass:NSClassFromString(@"Partner")] ? @[@"cpm"] : @[@"odi", @"kdi", @"cpm"];
		panel.canChooseDirectories = NO;
		panel.title = menuItem.title;

		if ([panel runModal] == NSModalResponseOK && panel.URLs.count == 1)
		{
			@synchronized(self.computer)
			{
				[self.computer registerUndoWithMenuItem:menuItem];
				[self setDisk:menuItem.tag URL:panel.URLs.firstObject];
			}
		}
		else
		{
			@synchronized(self)
			{
				if ([self getDisk:0] != nil)
				{
					[self.computer registerUndoWithMenuItem:menuItem];
					[self setDisk:menuItem.tag URL:nil];
				}
			}
		}
	}
}

#ifndef NDEBUG
- (void) dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
