#import "Floppy.h"

@implementation Floppy
{
	NSURL *URLs[2];

	NSInteger selected;
	NSFileHandle *file;
	unsigned track;
	unsigned head;

	uint64_t current;
	uint64_t started;

	unsigned long long offset;
	uint8_t buffer[3125];
	unsigned pos;

	BOOL readonly;

	BOOL update;
	BOOL ready;

	uint8_t D;
}

// -----------------------------------------------------------------------------

- (void) setDisk:(NSInteger)disk URL:(NSURL *)url;
{
	if (disk == 1 || disk == 2)
	{
		@synchronized(self)
		{
			if (disk != selected)
				URLs[disk-1] = url;
		}
	}
}

- (NSURL *) getDisk:(NSInteger)disk;
{
	if (disk == 1 || disk == 2)
		return URLs[disk-1];

	return nil;
}

// -----------------------------------------------------------------------------

- (NSInteger) selected
{
	return selected;
}

// -----------------------------------------------------------------------------

- (void) flush
{
	if (update)
	{
		[file seekToFileOffset:offset];
		[file writeData:[NSData dataWithBytes:buffer length:sizeof(buffer)]];
		update = FALSE;
	}
}

- (void) read
{
	[self flush];
	memset(buffer, 0x00, sizeof(buffer));
	[file seekToFileOffset:offset = (track * 2 + head) * sizeof(buffer)];
	[[file readDataOfLength:sizeof(buffer)] getBytes:buffer length:sizeof(buffer)];
}

// -----------------------------------------------------------------------------

- (void) select:(int)disk
{
	if (selected != disk)
	{
		if (file)
		{
			[self flush]; [file closeFile];
			file = nil; selected = 0;
		}

		if (disk)
		{
			if (URLs[disk - 1] != nil && (file = [NSFileHandle fileHandleForUpdatingURL:URLs[disk - 1] error:NULL]) != nil)
			{
				selected = disk; readonly = FALSE;
				started = current + 16000000;
				[self read];
			}
			else if (URLs[disk - 1] != nil && (file = [NSFileHandle fileHandleForReadingFromURL:URLs[disk - 1] error:NULL]) != nil)
			{
				selected = disk; readonly = TRUE;
				started = current + 16000000;
				[self read];
			}
		}
	}
}

// -----------------------------------------------------------------------------

- (void) setA:(uint8_t)data
{
	if (ready && (C & 0x01) == 0x00)
	{
		buffer[pos] = data;
		update = TRUE;
		ready = FALSE;
	}
}

// -----------------------------------------------------------------------------

- (uint8_t) D
{
	if (ready && (C & 0x01) == 0x01)
	{
		D = buffer[pos];
		ready = FALSE;
	}

	return D;
}


// -----------------------------------------------------------------------------

- (uint8_t) B
{
	uint8_t status = 0xFF; if (selected)
	{
		if (track == 0)
			status &= ~0x20;				// РВ5 - трек 00

		if (readonly)
			status &= ~0x08;				// РВЗ - защита записи

		if (current > started)
		{
			status &= ~0x10;				// РВ4 - готовность НГМД

			unsigned p = (current - started) / 1024 % sizeof(buffer);

			if (pos != p)
			{
				ready = TRUE;
				pos = p;
			}

			if (pos == sizeof(buffer) - 1)
				status &= ~0x40;			// РВ6 - индекс

			if (!ready)
				status &= ~0x80;			// РВ7 - триггер готовности
		}
	}
	else
	{
		status &= ~0x80;
	}

	return status;
}

// -----------------------------------------------------------------------------

- (void) setC:(uint8_t)data
{
	if ((data & 0x28) == 0x08)		// PC5 - выбор первого накопителя
	{
		[self select:1];
	}
	else if ((data & 0x28) == 0x20)	// РСЗ - выбор второго накопителя
	{
		[self select:2];
	}
	else
	{
		[self select:0];
	}

	if (selected && (C & 0x10) == 0x10 && (data & 0x10) == 0x00)	// РС4 - шаг
	{
		if (((data & 0x02) == 0x00) && track < 79)		// РС1 - направление шага
		{
			if (current > started)
				started = current + 1600000;

			head = (C & 0x04) != 0;
			track++; [self read];
		}

		if (((data & 0x02) == 0x02) && track > 0)		// РС1 - направление шага
		{
			if (current > started)
				started = current + 1600000;

			head = (C & 0x04) != 0;
			track--; [self read];
		}
	}

	if (selected && ((data & 0x04) != 0) != head)		// РС2 - выбор поверхности
	{
		if (current > started)
			started = current + 800000;

		head = (C & 0x04) != 0;
		[self read];
	}
}

// -----------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	@synchronized(self)
	{
		current = clock; return (addr & 0x07) == 0x04 ? self.D : [super RD:addr CLK:clock status:status];
	}
}

// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	@synchronized(self)
	{
		current = clock; [super WR:addr byte:data CLK:clock];
	}
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	[encoder encodeObject:URLs[0] forKey:@"urlA"];
	[encoder encodeObject:URLs[1] forKey:@"urlB"];
}


- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		URLs[0] = [decoder decodeObjectForKey:@"urlA"];
		URLs[1] = [decoder decodeObjectForKey:@"urlB"];
	}

	return self;
}

@end
