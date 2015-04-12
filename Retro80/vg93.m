/*******************************************************************************
 КР1818ВГ93
 ******************************************************************************/

#import "vg93.h"

@implementation VG93
{
	unsigned ms200, ms;
	NSURL *URLs[2];

	unsigned selected;
	unsigned TRACK;
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

@synthesize head;

//------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------

- (BOOL) busy
{
	return started != 0;
}

//------------------------------------------------------------------------------
// setDisk/getDisk
//------------------------------------------------------------------------------

- (void) setDisk:(NSInteger)disk URL:(NSURL *)url
{
	if (disk == 1 || disk == 2)
	{
		if (disk != selected)
			URLs[disk-1] = url;

		else if (started == 0)
		{
			self.selected = 0; URLs[disk-1] = url;
			self.selected = (unsigned)disk;
		}
	}
}

- (NSURL *) getDisk:(NSInteger)disk
{
	if (disk == 1 || disk == 2)
		return URLs[disk-1];

	return nil;
}

//------------------------------------------------------------------------------
// select disk
//------------------------------------------------------------------------------

- (void) setSelected:(unsigned int)disk
{
	if (selected != disk)
	{
		if (file)
		{
			[file closeFile];
			file = nil;
		}

		readOnly = FALSE;
		newDisk = FALSE;

		if (disk && URLs[disk - 1] != nil)
		{
			if ((file = [NSFileHandle fileHandleForUpdatingURL:URLs[disk - 1] error:NULL]) == nil)
				if ((file = [NSFileHandle fileHandleForReadingFromURL:URLs[disk - 1] error:NULL]) != nil)
					readOnly = TRUE;

			if (file)
			{
				unsigned long long fileSize = file.seekToEndOfFile;

				if (fileSize == 0)
				{
					TRACKS = 0; HEADS = 1; SECTORS = 0; SECSIZE = 0;
					newDisk = TRUE;
				}

				else if (fileSize % 5120 == 0)
				{
					HEADS = 1; SECTORS = 5; SECSIZE = 1024;
					TRACKS = (unsigned) fileSize / 5120;

					if (TRACKS >= 160 && (TRACKS & 1) == 0)
					{
						TRACKS >>= 1; HEADS = 2;
					}

					if (TRACKS < 80 || TRACKS > 83)
					{
						file = nil;
					}
				}

				else
				{
					file = nil;
				}
			}
		}

		status.S7 = (selected = disk) == 0;
	}
}

- (unsigned) selected
{
	return selected;
}

//------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------

- (void) step:(uint64_t)clock
{
	status.byte = 1;

	status.S6 = file != nil && readOnly;	// Защита записи
	status.S5 = command.h;					// Загрузка МГ
	status.S2 = TRACK == 0;					// Дор.0

	if (command.code < 2)
	{
		if (shift == cylinder)
		{
			started = clock;
			return;
		}

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

	if (TRACK == 0 && DIRC == FALSE)
	{
		started = clock;
		cylinder = 0;
		return;
	}

	static unsigned timing[4] = { 6, 12, 20, 30 };
	started = clock + timing[command.r] * ms;

	if (DIRC)
	{
		if (TRACK < 83)
			TRACK++;
	}
	else
	{
		if (TRACK > 0)
			TRACK--;
	}
}

- (void) read:(uint64_t)clock
{
	status.byte = 1;

	started = clock; if (command.E)
		started += ms * 15;

	if (file != nil && cylinder == TRACK && cylinder < TRACKS && head < HEADS && sector && sector <= SECTORS)
	{
		NSLog(@"ВГ93 Read from drive %c: track %d head %d sector %d", selected - 1 + 'A', cylinder, head, sector);
		[file seekToFileOffset:((cylinder * HEADS + head) * SECTORS + sector - 1) * SECSIZE];
		read = [file readDataOfLength:SECSIZE];
	}
	else
	{
		read = nil;
	}

	if (read == nil || read.length != SECSIZE)
	{
		read = nil; started += ms200 * 5 - started % ms200;
	}
	else
	{
		DRQ = started + ms200 / SECTORS - started % (ms200 / SECTORS);
		unsigned s = DRQ / (ms200 / SECTORS) % SECTORS + 1;
		s = s > sector ? sector + SECTORS - s : sector - s;
		DRQ += ms200 / SECTORS * s;

		started = DRQ + ms200 / SECTORS;

		ptr = (uint8_t *) read.bytes;
		length = SECSIZE;
		pos = 0;
	}
}

- (void) write:(uint64_t)clock
{
	status.byte = 1;

	started = clock; if (command.E)
		started += ms * 15;

	if (file && readOnly)
		return;

	if (file != nil && cylinder == TRACK && cylinder < TRACKS && head < HEADS && sector && sector <= SECTORS)
	{
		NSLog(@"ВГ93 Write to drive %c:  track %d head %d sector %d", selected - 1 + 'A', cylinder, head, sector);
		[file seekToFileOffset:((cylinder * HEADS + head) * SECTORS + sector - 1) * SECSIZE];
		write = [[NSMutableData alloc] initWithLength:SECSIZE];

		DRQ = started + ms200 / SECTORS - started % (ms200 / SECTORS);
		unsigned s = DRQ / (ms200 / SECTORS) % SECTORS + 1;
		s = s > sector ? sector + SECTORS - s : sector - s;
		DRQ += ms200 / SECTORS * s;

		started = DRQ + ms200 / SECTORS;

		ptr = write.mutableBytes;
		length = SECSIZE;
		pos = 0;
	}

	else
	{
		write = nil; started += ms200 * 5 - started % ms200;
	}
}

- (void) writeTrack:(uint64_t)clock
{
	status.byte = 1;

	started = clock; if (command.E)
		started += ms * 15;

	if (file && readOnly)
		return;

	if (file != nil && newDisk)
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

	if (file != nil && cylinder == TRACK && cylinder < TRACKS && head < HEADS)
	{
		NSLog(@"ВГ93 Write track %d head %d to drive %c", cylinder, head, selected - 1 + 'A');
		write = [[NSMutableData alloc] initWithLength:6250];

		DRQ = started; started = started + ms200 * 2 - started % ms200;

		ptr = write.mutableBytes;
		length = 6250;
		pos = 0;
	}

	else
	{
		write = nil; started += ms200 * 5 - started % ms200;
	}
}

//------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------

- (void) startCommand:(uint8_t)data clock:(uint64_t)clock
{
	if ((data & 0xF0) == 0xD0 || (selected && started == 0))
	{
		command.byte = data; switch (command.code)
		{
			case 0x0:	// Восстановление

				NSLog(@"ВГ93 Восстановление: h=%d, V=%d, r=%d", command.h, command.V, command.r);
				cylinder = 0xFF; shift = 0x00; [self step:clock]; break;

			case 0x1:	// Поиск

				NSLog(@"ВГ93 Поиск: h=%d, V=%d, r=%d", command.h, command.V, command.r);
				[self step:clock]; break;

			case 0x2:	// Шаг
			case 0x3:

				NSLog(@"ВГ93 Шаг: u=%d, h=%d, V=%d, r=%d", command.u, command.h, command.V, command.r);
				[self step:clock]; break;

			case 0x4:	// Шаг вперед
			case 0x5:

				NSLog(@"ВГ93 Шаг вперед: u=%d, h=%d, V=%d, r=%d", command.u, command.h, command.V, command.r);
				DIRC = TRUE; [self step:clock]; break;

			case 0x6:	// Шаг назад
			case 0x7:

				NSLog(@"ВГ93 Шаг назад: u=%d, h=%d, V=%d, r=%d", command.u, command.h, command.V, command.r);
				DIRC = FALSE; [self step:clock]; break;

			case 0x8:	// Чтение сектора
			case 0x9:

				NSLog(@"ВГ93 Чтение сектора: m=%d, s=%d, E=%d, C=%d", command.m, command.s, command.E, command.C);
				[self read:clock];
				break;

			case 0xA:	// Запись сектора
			case 0xB:

				NSLog(@"ВГ93 Запись сектора: m=%d, s=%d, E=%d, C=%d, a=%d", command.m, command.s, command.E, command.C, command.a);
				[self write:clock];
				break;

			case 0x0C:	// Чтение адреса

				NSLog(@"ВГ93 Чтение адреса: E=%d", command.E);
				status.byte = 0x03;
				break;

			case 0xD:	// Принудительное прерывание

				NSLog(@"ВГ93 Принудительное прерывание: J3=%d, J2=%d, J1=%d, J0=%d", command.J3, command.J2, command.J1, command.J0);
				started = 0; DRQ = -1; write = nil; read = nil;
				status.S0 = 0;
				break;

			case 0xE:	// Чтение дорожки

				NSLog(@"ВГ93 Чтение дорожки: E=%d", command.E);
				status.byte = 0x03;
				break;

			case 0xF:	// Запись дорожки

				NSLog(@"ВГ93 Запись дорожки: E=%d", command.E);
				[self writeTrack:clock];
				break;
		}
	}
}

- (void) execute:(uint64_t)clock
{
	if (started) switch (command.code)
	{
		case 0x0:	// Восстановление
		case 0x1:	// Поиск
		case 0x2:	// Шаг
		case 0x3:
		case 0x4:	// Шаг вперед
		case 0x5:
		case 0x6:	// Шаг назад
		case 0x7:

			status.S1 = clock % ms200 < ms; while (started <= clock)
			{
				if (command.code < 2 && (shift != cylinder))
				{
					[self step:started]; continue;
				}

				if (command.V == 0)
				{
					status.S0 = 0;
					started = 0;
				}

				else
				{
					status.S5 = 1; if (file != nil && cylinder == TRACK && cylinder < TRACKS && head < HEADS)
					{
						if (started + (ms * 216) - (started + ms * 15) % ms200 <= clock)
						{
							status.S0 = 0;
							started = 0;
						}
					}
					else if (started + (ms * 1816) - (started + ms * 15) % ms200 <= clock)
					{
						status.S4 = 1;	// Ошибка поиска

						status.S0 = 0;
						started = 0;
					}
				}

				break;
			}

			break;

		case 0x8:	// Чтение сектора
		case 0x9:

			status.S1 = DRQ < clock;

			if (DRQ != -1 && DRQ + ms200 / 6250 < clock)
				status.S2 = 1;

			if (started < clock)
			{
				status.S4 = read == nil;

				status.S0 = 0;
				started = 0;

				read = nil;
				DRQ = -1;
			}

			break;

		case 0xA:	// Запись сектора
		case 0xB:

			status.S1 = DRQ < clock;

			if (DRQ != -1 && DRQ + ms200 / 6250 < clock)
				status.S2 = 1;

			if (started < clock)
			{
				if (file != nil && readOnly)
					status.S6 = 1;
				else
					status.S5 = 1;

				status.S0 = 0;
				started = 0;

				write = nil;
				DRQ = -1;
			}

			break;

		case 0xC:	// Чтение адреса
		case 0xE:	// Чтение дорожки

			break;

		case 0xF:	// Запись дорожки

			status.S1 = DRQ < clock;

			if (DRQ != -1 && DRQ + ms200 / 6250 < clock)
				status.S2 = 1;

			if (started < clock)
			{
				if (file != nil && readOnly)
					status.S6 = 1;

				else if (write == nil)
					status.S5 = 1;

				else
				{
					length = pos; for (pos = 0; pos < length; pos++) if (pos + 7 <= length && ptr[pos] == 0xF5 && ptr[pos + 1] == 0xFE && ptr[pos + 6] == 0xF7)
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
				}

				status.S1 = 0;
				status.S0 = 0;
				started = 0;

				write = nil;
				DRQ = -1;
			}

			break;
	}
}

//------------------------------------------------------------------------------
// RESET/RD/WR
//------------------------------------------------------------------------------

- (void) RESET
{
	self.selected = 0;

	write = nil;
	read = nil;

	started = 0;
	DRQ = -1;
}

//------------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock data:(uint8_t)ignore
{

	[self execute:clock];

	switch (addr & 3)
	{
		case 0:

			return status.byte;

		case 1:

			return cylinder;

		case 2:

			return sector;

		case 3:

			NSLog(@"ВГ93 read data: %02X", shift);
			return shift;
	}

	return 0xFF;
}

//------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{

	[self execute:clock];

	switch (addr & 3)
	{
		case 0:
		{
			[self startCommand:data clock:clock];
			break;
		}

		case 1:

			NSLog(@"ВГ93 cylinder = %d", data);
			cylinder = data;
			break;

		case 2:

			NSLog(@"ВГ93 sector = %d", data);
			sector = data;
			break;

		case 3:

			NSLog(@"ВГ93 data: %02X", data);
			shift = data;
			break;
	}
}

//------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------

- (uint64_t *) DRQ
{
	return &DRQ;
}

- (void) RD:(uint8_t *)data clock:(uint64_t)clock
{
	if (read)
	{
		DRQ += ms200 / 6250; if (DRQ < clock)
		{
			status.S2 = 1; do { pos++; DRQ += ms200 / 6250; }
			while (DRQ < clock && pos < length);
		}

		if (pos < length)
			*data = ptr[pos++];

		if (pos == length)
		{
			status.S0 = 0;
			status.S1 = 0;

			started = 0;
			read = nil;
			DRQ = -1;
		}
	}
	else
	{
		DRQ = -1;
	}
}

- (void) WR:(uint8_t)data clock:(uint64_t)clock
{
	if (write)
	{
		if (command.code != 0x0F)
		{
			DRQ += ms200 / 6250; if (DRQ < clock)
			{
				status.S2 = 1; do { pos++; DRQ += ms200 / 6250; }
				while (DRQ < clock && pos < length);
			}

			if (pos < length)
				ptr[pos++] = data;

			if (pos == length)
			{
				[file writeData:write];

				status.S0 = 0;
				status.S1 = 0;

				started = 0;
				write = nil;
				DRQ = -1;
			}
		}
		else
		{
			DRQ += ms200 / 6250; if (DRQ < clock)
			{
				status.S2 = 1;
				status.S1 = 0;
				status.S0 = 0;

				started = 0;
				write = nil;
				DRQ = -1;
			}

			if (pos < length)
			{
				ptr[pos++] = data; if (pos == 3)
					DRQ += ms200 - clock % ms200;
			}
		}
	}
	else
	{
		DRQ = -1;
	}
}

//------------------------------------------------------------------------------
// Инициализация
//------------------------------------------------------------------------------

- (id) initWithQuartz:(unsigned)quartz
{
	if (self = [super init])
	{
		ms = (ms200 = quartz / 5) / 200; DRQ = -1;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:ms200 * 5 forKey:@"quartz"];
	[encoder encodeObject:URLs[0] forKey:@"urlA"];
	[encoder encodeObject:URLs[1] forKey:@"urlB"];

	[encoder encodeInt:selected forKey:@"selected"];
	[encoder encodeInt:head forKey:@"head"];

	[encoder encodeInt:TRACK forKey:@"TRACK"];
	[encoder encodeBool:DIRC forKey:@"DIRC"];

	[encoder encodeInt:cylinder forKey:@"cylinder"];
	[encoder encodeInt:sector forKey:@"sector"];
	[encoder encodeInt:shift forKey:@"shift"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self initWithQuartz:[decoder decodeIntForKey:@"quartz"]])
	{
		URLs[0] = [decoder decodeObjectForKey:@"urlA"];
		URLs[1] = [decoder decodeObjectForKey:@"urlB"];

		self.selected = [decoder decodeIntForKey:@"selected"];
		head = [decoder decodeIntForKey:@"head"];

		TRACK = [decoder decodeIntForKey:@"TRACK"];
		DIRC = [decoder decodeBoolForKey:@"DIRC"];

		cylinder = [decoder decodeIntForKey:@"cylinder"];
		sector = [decoder decodeIntForKey:@"sector"];
		shift = [decoder decodeIntForKey:@"shift"];
	}

	return self;
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
