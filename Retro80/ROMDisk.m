#import "ROMDisk.h"

@implementation ROMDisk
{
	NSURL* _url;
	NSData *rom;
	int romMode;

	uint16_t latch;
	uint32_t addr;
	uint8_t out;

	NSDirectoryEnumerator *dir;
	NSFileHandle *file, *file2;

	uint8_t buffer[0x11000];
	unsigned bpos, blen;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:self.url forKey:@"url"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
		self.url = [decoder decodeObjectForKey:@"url"];

	return self;
}

// -----------------------------------------------------------------------------
// shouldEnableURL
// -----------------------------------------------------------------------------

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url
{
	BOOL isDirectory; if ([[NSFileManager defaultManager] fileExistsAtPath:url.path.stringByResolvingSymlinksInPath isDirectory:&isDirectory])
	{
		if (!isDirectory)
		{
			NSError* outError; NSNumber *fileSize = nil; if ([url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:&outError])
			{
				NSUInteger size = fileSize.unsignedIntegerValue; return size == 0x80000 || size == 0x40000 || (size && size <= 0x10000 && (size & 0x07FF) == 0x0000);
			}
		}
		else
		{
			return TRUE;
		}
	}

	return FALSE;
}

// -----------------------------------------------------------------------------
// validateURL
// -----------------------------------------------------------------------------

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError
{
	BOOL isDirectory; if ([[NSFileManager defaultManager] fileExistsAtPath:url.path.stringByResolvingSymlinksInPath isDirectory:&isDirectory])
	{
		if (!isDirectory)
		{
			NSNumber *fileSize = nil; if ([url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:outError])
			{
				NSUInteger size = fileSize.unsignedIntegerValue; return size == 0x80000 || size == 0x40000 || (size && size <= 0x10000 && (size & 0x07FF) == 0x0000);
			}
		}
		else if ([sender isKindOfClass:[NSOpenPanel class]] && [(NSOpenPanel *)sender canChooseDirectories])
		{
			return [[NSFileManager defaultManager] fileExistsAtPath:[[NSURL URLWithString:@"boot/boot.rk" relativeToURL:url] path]];
		}
	}

	return FALSE;
}

// -----------------------------------------------------------------------------
// @property NSURL* url;
// -----------------------------------------------------------------------------

- (void) setUrl:(NSURL *)url
{
	if (url)
	{
		BOOL isDirectory; if ([[NSFileManager defaultManager] fileExistsAtPath:url.path.stringByResolvingSymlinksInPath isDirectory:&isDirectory])
		{
			if (isDirectory)
			{
				if ((rom = [NSData dataWithContentsOfFile:[[[NSURL URLWithString:@"boot/boot.rk" relativeToURL:url] path] stringByResolvingSymlinksInPath]]) != nil)
				{
					_length = rom.length; _bytes = rom.bytes;
					_url = url; romMode = 1;
					return;

				}
			}
			else if ((rom = [NSData dataWithContentsOfFile:[[url path] stringByResolvingSymlinksInPath]]) != nil)
			{
				_length = rom.length; _bytes = rom.bytes;
				_url = url; romMode = 0;
				return;
			}
		}
	}

	rom = nil; _length = 0; _bytes = 0;
	_url = nil; romMode = 0;
}

- (NSURL *) url
{
	return _url;
}

// -----------------------------------------------------------------------------

- (uint8_t) A
{
	if (romMode)
		return out;

	if (_length <= 0x10000)
		addr = (C << 8) | B;

	if (addr < _length)
		return _bytes[addr];
	else
		return 0xFF;
}

// -----------------------------------------------------------------------------

- (void) setB:(uint8_t)data
{
	switch (romMode)
	{
		case 0:
		{
			if ((data ^ B) & 0x01)
			{
				if (data & 0x01)
					addr = (((C & 0x0F) << 7 | (data >> 1)) << 11) | latch;
				else
					latch = (C & 0x0F) << 7 | (data >> 1);
			}

			break;
		}

		case 1:
		{
			out = (data & 0x7F) < _length ? _bytes[data & 0x7F] : 0xFF;

			if (B == 0x44 && data == 0x40)
				romMode++;

			break;
		}

		case 2:
		{
			if ((B & 0x20) && (data & 0x20) == 0x00)
			{
				if (data == 0x00)
				{
					out = 0x40; romMode++;
				}
				else
				{
					romMode = 1;
				}
			}
			else if (data & ~0x20)
			{
				romMode = 1;
			}

			break;
		}

		case 3:
		{
			if ((B & 0x20) && (data & 0x20) == 0x00)
			{
				if (data == 0x00)
				{
					if (out == 0x42)
					{
						blen = bpos = 0;
						romMode++;
					}
					else
					{
						out = 0x42;
					}
				}
				else
				{
					romMode = 1;
				}
			}
			else if (data & ~0x20)
			{
				romMode = 1;
			}

			break;
		}

		case 4:
		{
			if ((B & 0x20) && (data & 0x20) == 0x00)
			{
				if (data == 0x00)
				{
					if ([self execute])
					{
						romMode++;
						bpos = 0;
					}
				}
				else
				{
					romMode = 1;
				}
			}
			else if (data & ~0x20)
			{
				romMode = 1;
			}

			break;
		}

		case 5:
		{
			if ((B & 0x20) && (data & 0x20) == 0x00)
			{
				if (data == 0x00 && bpos < blen)
				{
					out = buffer[bpos++];
				}
				else
				{
					romMode = 1;
				}
			}
			else if (data & ~0x20)
			{
				romMode = 1;
			}

			break;
		}
	}
}

// -----------------------------------------------------------------------------

NSString* stringFromPointer(uint8_t *ptr)
{
	return [NSString stringWithCString:(const char *)ptr encoding:NSASCIIStringEncoding];
}

// -----------------------------------------------------------------------------

- (void) sendLength:(uint16_t)length
{
	if (file)
	{
		NSData* data = [file readDataOfLength:length];
		const uint8_t *ptr = (uint8_t *)data.bytes;
		length = data.length;

		buffer[blen++] = 0x4F;
		buffer[blen++] = length & 0xFF;
		buffer[blen++] = length >> 8;

		memcpy(buffer + blen, ptr, length);
		blen += length;

		buffer[blen++] = 0x44;
	}
	else
	{
		buffer[blen++] = 3;
	}
}

// -----------------------------------------------------------------------------

- (void) sendRKS
{
	if (file)
	{
		NSData* rk_header = [file readDataOfLength:4];

		if (rk_header && rk_header.length == 4)
		{
			const uint8_t *ptr = (uint8_t *)rk_header.bytes;
			uint16_t rk_length = ((ptr[2] << 8) | ptr[3]) - ((ptr[0] << 8) | ptr[1]) + 1;

			buffer[blen++] = 0x47;
			buffer[blen++] = ptr[1];
			buffer[blen++] = ptr[0];

			[self sendLength:rk_length];
		}
		else
		{
			[self sendLength:0];
		}
	}
	else
	{
		buffer[blen++] = 3;
	}
}

// -----------------------------------------------------------------------------
// Команда 0 - cmd_boot
// -----------------------------------------------------------------------------

- (BOOL) cmd_boot
{
	blen = 0;

	if ((file = [NSFileHandle fileHandleForReadingAtPath:[[NSURL URLWithString:@"boot/sdbios.rk" relativeToURL:_url] path]]) == nil)
	{
		buffer[blen++] = 4;
		return TRUE;
	}

	[self sendRKS];
	return TRUE;
}

// -----------------------------------------------------------------------------
// Команда 1 - cmd_ver
// -----------------------------------------------------------------------------

- (BOOL) cmd_ver
{
	blen = 0;

	buffer[blen++] = 1;
	memcpy(buffer + blen, "V1.0 retro kr580", 16); blen += 16;

	return TRUE;
}

// -----------------------------------------------------------------------------
// Команда 2 - cmd_exec
// -----------------------------------------------------------------------------

- (BOOL) cmd_exec
{
	if (A)
		return FALSE;

	blen = 0;

	if ((file = [NSFileHandle fileHandleForReadingAtPath:[[NSURL URLWithString:stringFromPointer(buffer+1) relativeToURL:_url] path]]) == nil)
	{
		buffer[blen++] = 4;
		return TRUE;
	}

	[self sendRKS];
	return TRUE;
}

// -----------------------------------------------------------------------------
// Команда 3 - cmd_find
// -----------------------------------------------------------------------------

- (BOOL) cmd_find
{
	if (bpos != 2)
	{
		if (bpos || A == 0x00)
		{
			bpos++;
		}

		return FALSE;
	}

	NSString* path = stringFromPointer(buffer + 1);
	uint16_t n = *(uint16_t *)(buffer + blen - 2);

	blen = 0; if (buffer[1] != ':')
	{
		dir = nil; BOOL isDirectory; if ([[NSFileManager defaultManager] fileExistsAtPath:[[NSURL URLWithString:path relativeToURL:_url] path] isDirectory:&isDirectory])
		{
			if (isDirectory)
			{
				dir = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL URLWithString:path relativeToURL:_url] includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLFileSizeKey, NSURLAttributeModificationDateKey] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];
			}
		}
	}

	if (dir == nil)
	{
		buffer[blen++] = 4;
		return TRUE;
	}

	NSURL *fileURL; while (n && (fileURL = [dir nextObject]) != nil)
	{
		NSString* fullName = fileURL.path.lastPathComponent.uppercaseString;
		NSString* fileName = fullName.stringByDeletingPathExtension;
		NSString* fileExt = fullName.pathExtension;

		if ([fileName characterAtIndex:0] == '.')
			continue;

		memset(buffer + blen + 1, 0x20, 11);

		NSUInteger usedLength; [fileName getBytes:buffer + blen + 1 maxLength:8 usedLength:&usedLength encoding:NSASCIIStringEncoding options:0 range:NSMakeRange(0, fileName.length) remainingRange:NULL];

		if (usedLength != fileName.length)
			continue;

		[fileExt getBytes:buffer + blen + 9 maxLength:3 usedLength:&usedLength encoding:NSASCIIStringEncoding options:0 range:NSMakeRange(0, fileExt.length) remainingRange:NULL];

		if (usedLength != fileExt.length)
			continue;

		n--;

		buffer[blen++] = 0x45;
		blen += 11;

		NSNumber *isDirectory; [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];

		if (isDirectory.boolValue)
		{
			buffer[blen++] = 0x10;

			buffer[blen++] = 0x00;
			buffer[blen++] = 0x00;
			buffer[blen++] = 0x00;
			buffer[blen++] = 0x00;
		}
		else
		{
			buffer[blen++] = 0x00;

			NSNumber *fileSize; [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
			*(uint32_t *)(buffer + blen) = fileSize.unsignedIntValue; blen += 4;
		}

		NSDate* modificationDate; [fileURL getResourceValue:&modificationDate forKey:NSURLAttributeModificationDateKey error:NULL];

		NSDateComponents* dateComponents = [[NSCalendar currentCalendar] components:NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:modificationDate];

		uint16_t dosTime = (dateComponents.hour << 11) | (dateComponents.minute << 5) | (dateComponents.second >> 2);

		buffer[blen++] = dosTime & 0xFF;
		buffer[blen++] = dosTime >> 8;

		uint16_t dosDate = ((dateComponents.year - 1980) << 9) | (dateComponents.month << 5) | dateComponents.day;

		buffer[blen++] = dosDate & 0xFF;
		buffer[blen++] = dosDate >> 8;
	}

	if (n)
	{
		buffer[blen++] = 0x43;
		dir = nil;
	}
	else
	{
		buffer[blen++] = 10;
	}

	return TRUE;
}

// -----------------------------------------------------------------------------
// Команда 4 - cmd_open
// -----------------------------------------------------------------------------

- (BOOL) cmd_open
{
	if (blen < 3 || A)
		return FALSE;

	NSString* path = [[NSURL URLWithString:stringFromPointer(buffer + 2) relativeToURL:_url] path];

	blen = 0; switch (buffer[1])
	{
		case 0:	// O_OPEN
		{
			if ((file = [NSFileHandle fileHandleForUpdatingAtPath:path]))
				buffer[blen++] = 0x43;
			else
				buffer[blen++] = 4;

			break;
		}

		case 1:	// O_CREATE
		{
			if ([[NSFileManager defaultManager] fileExistsAtPath:path])
			{
				buffer[blen++] = 8;
				break;
			}

			if (![[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil])
			{
				buffer[blen++] = 2;
				break;
			}

			if ((file = [NSFileHandle fileHandleForUpdatingAtPath:path]))
				buffer[blen++] = 0x43;
			else
				buffer[blen++] = 4;

			break;
		}

		case 2:	// O_MKDIR
		{
			if ([[NSFileManager defaultManager] fileExistsAtPath:path])
			{
				buffer[blen++] = 8;
				break;
			}

			if ([[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:nil])
				buffer[blen++] = 0x43;
			else
				buffer[blen++] = 2;

			break;
		}

		case 100:	// O_DELETE:
		{
			if (![[NSFileManager defaultManager] fileExistsAtPath:path])
			{
				buffer[blen++] = 4;
				break;
			}

			if ([[NSFileManager defaultManager] removeItemAtPath:path error:nil])
				buffer[blen++] = 0x43;
			else
				buffer[blen++] = 2;

			break;
		}

		case 101:	// O_SWAP:
		{
			NSFileHandle *f = file; file = file2; file2 = f;
			buffer[blen++] = 0x43;
			break;
		}

		default:
		{
			buffer[blen++] = 12;
			break;
		}

	}

	return TRUE;
}

// -----------------------------------------------------------------------------
// Команда 5 - cmd_lseek
// -----------------------------------------------------------------------------

- (BOOL) cmd_lseek
{
	if (blen < 6)
		return FALSE;

	blen = 0; if (buffer[1] != 101 && buffer[1] != 102 && file == nil)
	{
		buffer[blen++] = 3;
		return TRUE;
	}

	int32_t offset = *(int32_t *)(buffer + 2);

	switch (buffer[1])
	{
		case 100:	// fs_getfilesize()
		{
			unsigned long long offsetInFile = file.offsetInFile;
			offset = (uint32_t) file.seekToEndOfFile;
			[file seekToFileOffset:offsetInFile];
			break;
		}

		case 101:	// fs_gettotal()
		{
			offset = 0x40000000;
			break;
		}

		case 102:	// fs_free()
		{
			offset = 0x20000000;
			break;
		}

		case 0:
		{
			[file seekToFileOffset:offset];
			offset = (uint32_t) file.offsetInFile;
			break;
		}

		case 1:
		{
			[file seekToFileOffset:file.offsetInFile + offset];
			offset = (uint32_t) file.offsetInFile;
			break;
		}

		case 2:
		{
			[file seekToFileOffset:file.seekToEndOfFile + offset];
			offset = (uint32_t) file.offsetInFile;
			break;
		}

		default:
		{
			buffer[blen++] = 12;
			return TRUE;
		}
	}

	buffer[blen++] = 0x43;
	*(uint32_t *)(buffer + blen) = offset; blen += 4;
	return TRUE;
}

// -----------------------------------------------------------------------------
// Команда 6 - cmd_read
// -----------------------------------------------------------------------------

- (BOOL) cmd_read
{
	if (blen < 3)
		return FALSE;

	blen = 0; if (file == nil)
	{
		buffer[blen++] = 3;
		return TRUE;
	}

	uint16_t length = *(uint16_t *)(buffer + 1);
	[self sendLength:length];
	return TRUE;
}

// -----------------------------------------------------------------------------
// Команда 7 - cmd_write
// -----------------------------------------------------------------------------

- (BOOL) cmd_write
{
	switch (blen)
	{
		case 1:
		{
			break;
		}

		case 2:
		{
			break;
		}

		case 3:
		{
			if (file == nil)
			{
				blen = 0; buffer[blen++] = 3;
				return TRUE;
			}

			break;
		}

		case 4:
		{
			out = 0x46;
			break;
		}

		case 5:
		{
			out = buffer[1];
			break;
		}

		case 6:
		{
			out = buffer[2];
			break;
		}

		default:
		{
			uint16_t length = *(uint16_t *)(buffer + 1);

			if (blen == length + 7)
			{
				[file writeData:[NSData dataWithBytes:buffer + 7 length:length]];
				blen = 0; buffer[blen++] = 0x43;
				return TRUE;
			}
		}
	}

	return FALSE;
}

// -----------------------------------------------------------------------------
// Команда 8 - cmd_move
// -----------------------------------------------------------------------------

- (BOOL) cmd_move
{
	if (bpos == 0)
	{
		if (A == 0)
			bpos = blen;

		return FALSE;
	}

	else if (bpos + 1 >= blen)
	{
		out = 0x46; return FALSE;
	}

	else if (A)
	{
		return FALSE;
	}

	NSString *from = [[NSURL URLWithString:stringFromPointer(buffer + 1) relativeToURL:_url] path];
	NSString *to = [[NSURL URLWithString:stringFromPointer(buffer + bpos + 2) relativeToURL:_url] path];

	blen = 0; if (![[NSFileManager defaultManager] fileExistsAtPath:from])
		buffer[blen++] = 4;

	else if ([[NSFileManager defaultManager] fileExistsAtPath:to])
		buffer[blen++] = 8;

	else if ([[NSFileManager defaultManager] moveItemAtPath:from toPath:to error:nil])
		buffer[blen++] = 0x43;
	else
		buffer[blen++] = 2;

	return TRUE;

}

// -----------------------------------------------------------------------------
// Прием и исполнение команды RKSD
// -----------------------------------------------------------------------------

- (BOOL) execute
{
	buffer[blen++] = A; switch (buffer[0])
	{
		case 0:		// cmd_boot();
		{
			return [self cmd_boot];
		}

		case 1:		// cmd_ver();
		{
			return [self cmd_ver];
		}

		case 2:		// cmd_exec();
		{
			return [self cmd_exec];
		}

		case 3:		// cmd_find();
		{
			return [self cmd_find];
		}

		case 4:		// cmd_open();
		{
			return [self cmd_open];
		}

		case 5:		// cmd_lseek();
		{
			return [self cmd_lseek];
		}

		case 6:		// cmd_read();
		{
			return [self cmd_read];
		}

		case 7:		// cmd_write();
		{
			return [self cmd_write];
		}

		case 8:		// cmd_move();
		{
			return [self cmd_move];
		}

		default:
		{
			buffer[blen++] = 12;
			return TRUE;
		}
	}
}

@end
