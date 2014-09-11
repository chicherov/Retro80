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

	uint8_t _D;
}

// -----------------------------------------------------------------------------

- (void) setDisk:(NSInteger)disk URL:(NSURL *)url;
{
	if (disk == 1 || disk == 2)
	{
		@synchronized(self)
		{
			if (disk != selected)
			{
				URLs[disk-1] = url;
			}
		}
	}
}

- (NSURL *) getDisk:(NSInteger)disk;
{
	if (disk == 1 || disk == 2)
	{
		return URLs[disk-1];
	}

	return nil;
}

// -----------------------------------------------------------------------------

- (NSInteger) selected
{
	return selected;
}

// -----------------------------------------------------------------------------

- (void) write
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
	[self write];
	memset(buffer, 0x00, sizeof(buffer));
	[file seekToFileOffset:offset = (track * 2 + head) * sizeof(buffer)];
	[[file readDataOfLength:sizeof(buffer)] getBytes:buffer length:sizeof(buffer)];
}

- (void) setA:(uint8_t)A
{
	_A = A; if (ready && (_C & 0x01) == 0x00)
	{
		buffer[pos] = A;
		update = TRUE;
		ready = FALSE;
	}
}

- (uint8_t) D
{
	if (ready && (_C & 0x01) == 0x01)
	{
		_D = buffer[pos];
		ready = FALSE;
	}

	return _D;
}


- (uint8_t) B
{
	_B = 0xFF; if (selected)
	{
		if (track == 0)
			_B &= ~0x20;					// РВ5 - трек 00

		if (readonly)
			_B &= ~0x08;					// РВЗ - защита записи

		if (current > started)
		{
			_B &= ~0x10;					// РВ4 - готовность НГМД

			unsigned p = (current - started) / 1024 % sizeof(buffer);

			if (pos != p)
			{
				ready = TRUE;
				pos = p;
			}

			if (pos == sizeof(buffer) - 1)
				_B &= ~0x40;				// РВ6 - индекс

			if (!ready)
				_B &= ~0x80;				// РВ7 - триггер готовности
		}
	}
	else
	{
		_B &= ~0x80;
	}

	return _B;
}

- (void) setC:(uint8_t)C
{
	if ((C & 0x20) == 0)			// PC5 - выбор первого накопителя
	{
		if (selected != 1)
		{
			[self write]; if (file)
			{
				[file closeFile];
				file = nil;
			}

			if (URLs[0] != nil && (file = [NSFileHandle fileHandleForUpdatingURL:URLs[0] error:NULL]) != nil)
			{
				selected = 1; readonly = FALSE;
				started = current + 16000000;
				[self read];
			}
			else if (URLs[0] != nil && (file = [NSFileHandle fileHandleForReadingFromURL:URLs[0] error:NULL]) != nil)
			{
				selected = 1; readonly = TRUE;
				started = current + 16000000;
				[self read];
			}
			else
			{
				selected = 0;
			}
		}
	}
	else if ((C & 0x08) == 0)		// РСЗ - выбор второго накопителя
	{
		if (selected != 2)
		{
			[self write]; if (file)
			{
				[file closeFile];
				file = nil;
			}

			if (URLs[1] != nil && (file = [NSFileHandle fileHandleForUpdatingURL:URLs[1] error:NULL]) != nil)
			{
				selected = 2; readonly = FALSE;
				started = current + 16000000;
				[self read];
			}
			else if (URLs[1] != nil && (file = [NSFileHandle fileHandleForReadingFromURL:URLs[1] error:NULL]) != nil)
			{
				selected = 2; readonly = TRUE;
				started = current + 16000000;
				[self read];
			}
			else
			{
				selected = 0;
			}
		}
	}
	else
	{
		[self write]; if (file)
		{
			[file closeFile];
			file = nil;
		}

		selected = 0;
	}

	if (selected && (_C & 0x10) == 0x10 && (C & 0x10) == 0x00)	// РС4 - шаг
	{
		if (((C & 0x02) == 0x00) && track < 79)		// РС1 - направление шага
		{
			if (current > started)
				started = current + 1600000;

			[self write]; track++;
			[self read];
		}

		if (((C & 0x02) == 0x02) && track > 0)		// РС1 - направление шага
		{
			if (current > started)
				started = current + 1600000;

			[self write]; track--;
			[self read];
		}
	}

	if (selected && ((C & 0x04) != 0) != head)		// РС2 - выбор поверхности
	{
		if (current > started)
			started = current + 800000;

		[self write];
		head = (C & 0x04) != 0;
		[self read];
	}

	_C = C;
}

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	@synchronized(self)
	{
		current = clock; return (addr & 0x07) == 0x04 ? self.D : [super RD:addr CLK:clock status:status];
	}
}

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
