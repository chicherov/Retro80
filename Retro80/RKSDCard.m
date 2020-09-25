/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Адаптер SD-CARD для Радио-86РК

 *****/

#import "RKSDCard.h"

@implementation RKSDCard
{
	NSDirectoryEnumerator *directoryEnumerator;
	NSFileHandle *file, *file2;
}

- (NSString *)sdbiosrk
{
	return @"BOOT/SDBIOS.RK";
}

- (NSString *)bootrk
{
	return @"BOOT/BOOT.RK";
}

- (BOOL)validateDirectory:(NSURL *)url error:(NSError **)outError
{
	return [[NSFileManager defaultManager] fileExistsAtPath:[[NSURL URLWithString:self.bootrk relativeToURL:url] path]];
}

- (void)setURL:(NSURL *)url
{
	if ((rom = [NSData dataWithContentsOfFile:[[[NSURL URLWithString:self.bootrk relativeToURL:url] path] stringByResolvingSymlinksInPath]]) != nil)
	{
		if ((B & 0x7F) < rom.length)
			[rom getBytes:&out range:NSMakeRange(B & 0x7F, 1)];
		else
			out = 0xFF;

		URL = url; sdcard = 1;
	}
	else
	{
		super.URL = url;
		sdcard = 0;
	}
}

- (uint8_t)A
{
	return sdcard ? out : super.A;
}

- (void)setB:(uint8_t)data
{
	switch (sdcard)
	{
		case 1:
		{
			if ((data & 0x7F) < rom.length)
				[rom getBytes:&out range:NSMakeRange(data & 0x7F, 1)];
			else
				out = 0xFF;

			if (B == 0x44 && data == 0x40)
				sdcard++;

			break;
		}

		case 2:
		{
			if ((B & 0x20) && data == 0x00)
			{
				out = ERR_START; sdcard++;
			}
			else if (data & ~0x20)
			{
				sdcard = 1;
			}

			break;
		}

		case 3:
		{
			if ((B & 0x20) && data == 0x00)
			{
				out = ERR_OK_DISK; sdcard++;
			}
			else if (data & ~0x20)
			{
				sdcard = 1;
			}

			break;
		}

		case 4:
		{
			if ((B & 0x20) && data == 0x00)
			{
				pos = 0; sdcard++;
				buffer = nil;
			}
			else if (data & ~0x20)
			{
				sdcard = 1;
			}

			break;
		}

		case 5:
		{
			if ((B & 0x20) && data == 0x00)
			{
				uint8_t err; if ((err = [self execute:A]))
					buffer = [NSMutableData dataWithBytes:&err length:1];

				if (buffer)
				{
					pos = 0; sdcard++;
				}
			}
			else if (data & ~0x20)
			{
				sdcard = 1;
			}

			break;
		}

		case 6:
		{
			if ((B & 0x20) && data == 0x00)
			{
				if (pos < buffer.length)
				{
					[buffer getBytes:&out range:NSMakeRange(pos++, 1)];
				}
				else
				{
					sdcard = 1;
				}
			}
			else if (data & ~0x20)
			{
				sdcard = 1;
			}

			break;
		}

		default:

			super.B = data;
			break;
	}
}

static NSString *stringFromPointer(const void *ptr)
{
	return [NSString stringWithCString:(const char *) ptr encoding:NSASCIIStringEncoding];
}

- (uint8_t)sendFileHandle:(NSFileHandle *)fileHandle length:(uint16_t)length
{
	if (fileHandle == nil)
		return ERR_NOT_OPENED;

	NSData *data = [fileHandle readDataOfLength:length];

	char header[3];
	header[0] = ERR_READ_BLOCK;
	header[1] = (uint8_t) (data.length & 0xFF);
	header[2] = (uint8_t) (data.length >> 8);

	if (buffer == nil)
		buffer = [NSMutableData dataWithCapacity:length + 4];

	[buffer appendBytes:header length:3];
	[buffer appendData:data];

	header[0] = ERR_OK_READ;
	[buffer appendBytes:header length:1];

	return ERR_OK;
}

- (uint8_t)sendRKFileHandle:(NSFileHandle *)fileHandle
{
	if (fileHandle == nil)
		return ERR_NOT_OPENED;

	NSData* data = [fileHandle readDataOfLength:4];

	if (data && data.length == 4)
	{
		const uint8_t *ptr = (const uint8_t *)data.bytes;

		char header[3];
		header[0] = ERR_OK_RKS;
		header[1] = ptr[1];
		header[2] = ptr[0];

		uint16_t length = ((ptr[2] << 8) | ptr[3]) - ((ptr[0] << 8) | ptr[1]) + 1;
		buffer = [NSMutableData dataWithCapacity:length + 7];
		[buffer appendBytes:header length:3];

		return [self sendFileHandle:fileHandle length:length];
	}
	else
	{
		buffer = [NSMutableData dataWithCapacity:4];
		return [self sendFileHandle:fileHandle length:0];
	}
}

// Команда 0 - cmd_boot()
- (uint8_t)cmd_boot
{
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:[NSURL URLWithString:self.sdbiosrk
																			   relativeToURL:URL].path];

	return fileHandle == nil ? ERR_NO_PATH : [self sendRKFileHandle:fileHandle];
}

// Команда 1 - cmd_ver()
- (uint8_t)cmd_ver
{
	buffer = [NSMutableData dataWithBytes:"\x01V1.1 retro kr580" length:17];
	return ERR_OK;
}

// Команда 2 - cmd_exec()
- (uint8_t)cmd_exec
{
	if (request[pos - 1])
		return ERR_OK;

	NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:[NSURL URLWithString:stringFromPointer(request + 1)
																			   relativeToURL:URL].path];

	return fileHandle == nil ? ERR_NO_PATH : [self sendRKFileHandle:fileHandle];
}

// Команда 3 - cmd_find()
- (uint8_t)cmd_find
{
	if (pos < 4 || request[pos - 3])
		return ERR_OK;

	if (request[1] != ':')
        directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL URLWithString:stringFromPointer(request + 1) relativeToURL:URL]
                                                   includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLFileSizeKey, NSURLAttributeModificationDateKey]
                                                                      options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                                                 errorHandler:nil];
	if (directoryEnumerator == nil)
		return ERR_NO_PATH;

	unsigned count = (request[pos - 1] << 8) | request[pos - 2];
	buffer = [NSMutableData dataWithCapacity:count * 21 + 1];

	for (id object; count && (object = [directoryEnumerator nextObject]) != nil; --count)
	{
		#ifndef GNUSTEP
    		NSString* fullName = [(NSURL*)object path].lastPathComponent.uppercaseString;
        #else
    		NSString* fullName = [object uppercaseString];
		#endif

		NSString* fileName = fullName.stringByDeletingPathExtension;
		NSString* fileExt = fullName.pathExtension;

		if ([fileName characterAtIndex:0] == '.')
			continue;

		uint8_t fileinfo[21] = {ERR_OK_ENTRY, ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '};

        const char *ptr = [fileName cStringUsingEncoding:NSASCIIStringEncoding];
        size_t size = ptr ? strlen(ptr) : 0;

        if (size != fileName.length || size > 8)
            continue;

        memcpy(fileinfo + 1, ptr, size);

        ptr = [fileExt cStringUsingEncoding:NSASCIIStringEncoding];
        size = ptr ? strlen(ptr) : 0;

        if (size != fileExt.length || size > 3)
            continue;

        memcpy(fileinfo + 9, ptr, size);

#ifndef GNUSTEP
		NSNumber *value;
		if ([(NSURL*)object getResourceValue:&value forKey:NSURLIsDirectoryKey error:NULL] && value.boolValue)
#else
        if (directoryEnumerator.fileAttributes.fileType == NSFileTypeDirectory)
#endif
		{
			fileinfo[12] = 0x10;
			fileinfo[13] = 0x00;
			fileinfo[14] = 0x00;
			fileinfo[15] = 0x00;
			fileinfo[16] = 0x00;
		}
		else
		{
#ifndef GNUSTEP
            [(NSURL*)object getResourceValue:&value forKey:NSURLFileSizeKey error:NULL];
            uint32_t fileSize = value.unsignedIntValue;
#else
            uint32_t fileSize = (uint32_t) directoryEnumerator.fileAttributes.fileSize;
#endif

			fileinfo[12] = 0x00;
			fileinfo[13] = (uint8_t) fileSize;
			fileinfo[14] = (uint8_t) (fileSize >> 8);
			fileinfo[15] = (uint8_t) (fileSize >> 16);
			fileinfo[16] = (uint8_t) (fileSize >> 24);
		}

		NSDate *creationDate;
#ifndef GNUSTEP
		[(NSURL*)object getResourceValue:&creationDate forKey:NSURLCreationDateKey error:NULL];
#else
		creationDate = [directoryEnumerator.fileAttributes fileCreationDate];
#endif

        NSDateComponents *dateComponents = [[NSCalendar currentCalendar]
				components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond
				  fromDate:creationDate];

		uint16_t dosTime = (uint16_t) ((dateComponents.hour << 11) | (dateComponents.minute << 5) | (dateComponents.second >> 2));

		fileinfo[17] = (uint8_t) (dosTime & 0xFF);
		fileinfo[18] = (uint8_t) (dosTime >> 8);

		uint16_t dosDate = (uint16_t) (((dateComponents.year - 1980) << 9) | (dateComponents.month  << 5) | dateComponents.day);

		fileinfo[19] = (uint8_t) (dosDate & 0xFF);
		fileinfo[20] = (uint8_t) (dosDate >> 8);

		[buffer appendBytes:fileinfo length:21];
	}

	uint8_t err = ERR_OK_CMD;

	if (count)
		directoryEnumerator = nil;
	else
		err = ERR_MAX_FILES;

	[buffer appendBytes:&err length:1];
	return ERR_OK;
}

// Команда 4 - cmd_open()
- (uint8_t)cmd_open
{
	if (pos < 3 || request[pos - 1])
		return ERR_OK;

	NSString* path = [[NSURL URLWithString:stringFromPointer(request + 2) relativeToURL:URL] path];

	switch (request[1])
	{
		case 0:	// O_OPEN
		{
			if (!(file = [NSFileHandle fileHandleForUpdatingAtPath:path]))
				return ERR_NO_PATH;
			else
				return ERR_OK_CMD;
		}

		case 1:	// O_CREATE
		{
			if ([[NSFileManager defaultManager] fileExistsAtPath:path])
				return ERR_FILE_EXISTS;

			if (![[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil])
				return ERR_DISK_ERR;

			if (!(file = [NSFileHandle fileHandleForUpdatingAtPath:path]))
				return ERR_NO_PATH;
			else
				return ERR_OK_CMD;
		}

		case 2:	// O_MKDIR
		{
			if ([[NSFileManager defaultManager] fileExistsAtPath:path])
				return ERR_FILE_EXISTS;

			if (![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:NULL])
				return ERR_DISK_ERR;
			else
				return ERR_OK_CMD;
		}

		case 100:	// O_DELETE:
		{
			if (![[NSFileManager defaultManager] fileExistsAtPath:path])
				return ERR_NO_PATH;

			if (![[NSFileManager defaultManager] removeItemAtPath:path error:NULL])
				return ERR_DISK_ERR;
			else
				return ERR_OK_CMD;
		}

		case 101:	// O_SWAP:
		{
			NSFileHandle *swap = file; file = file2; file2 = swap;
			return ERR_OK_CMD;
		}

		default:
		{
			return ERR_INVALID_COMMAND;
		}
	}
}

// Команда 5 - cmd_lseek()
- (uint8_t)cmd_lseek
{
	if (pos < 6)
		return ERR_OK;

	if (request[1] != 101 && request[1] != 102 && file == nil)
		return ERR_NOT_OPENED;

	int32_t offset = request[2] | (request[3] << 8) | (request[4] << 16) | (request[5] << 24);

	switch (request[1])
	{
		case 100:    // fs_getfilesize()
		{
			unsigned long long offsetInFile = file.offsetInFile;
			offset = (uint32_t) file.seekToEndOfFile;
			[file seekToFileOffset:offsetInFile];
			break;
		}

		case 101:    // fs_gettotal()
		{
			NSError *error = nil;
			NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[URL path] error:&error];
			offset = (uint32_t) ([(NSNumber *) attributes[NSFileSystemSize] unsignedIntegerValue] / 1000000);
			break;
		}

		case 102:    // fs_free()
		{
			NSError *error = nil;
			NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[URL path] error:&error];
			offset = (uint32_t) ([(NSNumber *) attributes[NSFileSystemFreeSize] unsignedIntegerValue] / 1000000);
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
			return ERR_INVALID_COMMAND;
		}
	}

	uint8_t header[5];
	header[0] = ERR_OK_CMD;
	header[1] = (uint8_t) offset;
	header[2] = (uint8_t) (offset >> 8);
	header[3] = (uint8_t) (offset >> 16);
	header[4] = (uint8_t) (offset >> 24);

	buffer = [NSMutableData dataWithBytes:header length:5];
	return ERR_OK;
}

// Команда 6 - cmd_read()
- (uint8_t)cmd_read
{
	return pos < 3 ? ERR_OK : [self sendFileHandle:file length:request[1] | (request[2] << 8)];
}

// Команда 7 - cmd_write
- (uint8_t)cmd_write
{
	if (pos < 3)
		return ERR_OK;

	if (file == nil)
		return ERR_NOT_OPENED;

	uint16_t length; if ((length = request[1] | (request[2] << 8)) == 0)
	{
		[file truncateFileAtOffset:file.offsetInFile]; return ERR_OK_CMD;
	}

	uint16_t blockLength = MIN(length, sizeof(request) - 7);

	if (pos == blockLength + 7)
	{
		[file writeData:[NSData dataWithBytes:request + 7 length:blockLength]];

		if ((length -= blockLength) == 0)
			return ERR_OK_CMD;

		request[1] = (uint8_t) length;
		request[2] = (uint8_t) (length >> 8);

		pos = 3;
		return ERR_OK;
	}

	if (pos == 4)
		out = ERR_OK_WRITE;
	else if (pos == 5)
		out = (uint8_t) blockLength;
	else if (pos == 6)
		out = (uint8_t) (blockLength >> 8);

	return ERR_OK;
}

// Команда 8 - cmd_move
- (uint8_t)cmd_move
{
	if (pos < 3 || request[pos - 1])
		return ERR_OK;

	NSString *from = [[NSURL URLWithString:stringFromPointer(request + 1) relativeToURL:URL] path];

	if (out != ERR_OK_WRITE)
	{
		if (![[NSFileManager defaultManager] fileExistsAtPath:from])
			return ERR_NO_PATH;

		if (request[pos - 2] == 0)
			out = ERR_OK_WRITE;

		return ERR_OK;
	}

	else if (pos < sizeof(request)/2)
	{
		pos = sizeof(request)/2;
		return ERR_OK;
	}

	NSString *to = [[NSURL URLWithString:stringFromPointer(request + sizeof(request)/2) relativeToURL:URL] path];

	if ([[NSFileManager defaultManager] fileExistsAtPath:to])
		return ERR_FILE_EXISTS;

	if (![[NSFileManager defaultManager] moveItemAtPath:from toPath:to error:NULL])
		return ERR_DISK_ERR;

	return ERR_OK_CMD;
}

// Выполнить команды rksd
- (uint8_t)execute:(uint8_t)data
{
	if (pos >= sizeof(request))
		return ERR_RECV_STRING;

	request[pos++] = data;

	switch (request[0])
	{
		case 0:
			return [self cmd_boot];

		case 1:
			return [self cmd_ver];

		case 2:
			return [self cmd_exec];

		case 3:
			return [self cmd_find];

		case 4:
			return [self cmd_open];

		case 5:
			return [self cmd_lseek];

		case 6:
			return [self cmd_read];

		case 7:
			return [self cmd_write];

		case 8:
			return [self cmd_move];

		default:
			return ERR_INVALID_COMMAND;
	}
}

@end
