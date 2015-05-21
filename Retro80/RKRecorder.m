#import "RKRecorder.h"
#import "Sound.h"

// -----------------------------------------------------------------------------
// F806 - Ввод байта с магнитофона
// -----------------------------------------------------------------------------

@implementation F806

@synthesize enabled;
@synthesize pos;

// -----------------------------------------------------------------------------

- (id) initWithX8080:(X8080 *)cpu
{
	if (self = [self init])
		self.cpu = cpu;

	return self;
}

// -----------------------------------------------------------------------------

- (uint8_t *) BYTE:(uint16_t)addr
{
	if ([self.mem respondsToSelector:@selector(BYTE:)])
		return [(NSObject<BYTE> *)self.mem BYTE:addr];
	else
		return 0;
}

// -----------------------------------------------------------------------------

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if (*data == 0xA2 && enabled && !self.snd.sound.isInput)
	{
		if (panel != nil)
		{
			self.cpu.PC--;
			*data = 0x00;
			return;
		}

			if (cancel)
			cancel = FALSE;

		else
		{
			if (pos != 0 && self.cpu.A == 0xFF)
				while (pos < self.buffer.length && ((const uint8_t *)self.buffer.bytes) [pos++] != 0xE6);

			if (pos < self.buffer.length)
			{
				self.cpu.A = ((const uint8_t *)self.buffer.bytes) [pos++];

				*data = 0xC9;
				return;
			}

			if (self.cpu.A == 0xFF)
			{
				[self performSelectorOnMainThread:@selector(openPanel)
									   withObject:nil
									waitUntilDone:TRUE];

				[self performSelectorOnMainThread:@selector(open)
									   withObject:nil
									waitUntilDone:FALSE];

				self.cpu.PC--;
				*data = 0x00;
				return;
			}
		}
	}

	[self.mem RD:addr data:data CLK:clock];
}

// -----------------------------------------------------------------------------
// Подсчет контрольной суммы для Радио86РК/Микроша
// -----------------------------------------------------------------------------

static uint16_t csum(const uint8_t* ptr, size_t size, bool microsha)
{
	uint8_t B = 0x00, C = 0x00; while (size--)
	{
		if (!microsha)
		{
			bool CF = (C + *ptr) > 0xFF; C += *ptr; if (size)
			{
				B += *ptr + (CF ? 1 : 0);
			}

			ptr++;
		}
		else
		{
			C ^= *ptr++; if (size)
			{
				B ^= *ptr++; size--;
			}
		}
	}

	return (B << 8) | C;
}

// -----------------------------------------------------------------------------
// Панель открытия файла
// -----------------------------------------------------------------------------


- (void) openPanel
{
	panel = [NSOpenPanel openPanel];
}

- (void) open
{
	panel.allowedFileTypes = @[@"wav", @"bin", @"rk", @"pki", @"gam", @"edm", @"bss", @"bsm", self.extension];

	if ([self.extension isEqualToString:@"rko"])
		panel.allowedFileTypes = [panel.allowedFileTypes arrayByAddingObjectsFromArray:@[@"ord", @"bru"]];

	if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
	{
		NSString *fileExt = [panel.URLs.firstObject pathExtension].lowercaseString;

		if ([fileExt isEqualToString:@"wav"])
		{
			[self.snd.sound stop];
			[self.snd.sound open:panel.URLs.firstObject];
			[self.snd.sound start];
		}

		else if ((self.buffer = [NSData dataWithContentsOfURL:panel.URLs.firstObject]))
		{
			pos = 0; if ([@[@"pki", @"gam", @"bss", @"bsm"] containsObject:fileExt])
			{
				if (self.buffer.length && *(const uint8_t *)self.buffer.bytes == 0xE6)
					pos++;
			}

			else if ([@[@"ord", @"bru"] containsObject:fileExt])
			{
				if (self.buffer.length >= 16)
				{
					const uint8_t *ptr = self.buffer.bytes;

					uint16_t len = (ptr[0x0A] | (ptr[0x0B] << 8)) + 0x10;
					if ((len & 0xF) == 0 && self.buffer.length >= len)
					{
						uint8_t buffer[0x4D]; memset(buffer, 0x00, 0x4D);
						memcpy(buffer, self.buffer.bytes, 8);

						buffer[0x48] = 0xE6;
						buffer[0x4B] = (len - 1) >> 8;
						buffer[0x4C] = (len - 1) & 0xFF;

						NSMutableData *mutableData = [NSMutableData dataWithBytes:buffer length:0x4D];
						[mutableData appendBytes:ptr length:len];

						uint16_t cs = csum(ptr, len, FALSE);
						buffer[0x49] = cs >> 8; buffer[0x4A] = cs & 0xFF;
						[mutableData appendBytes:buffer + 0x46 length:5];

						self.buffer = mutableData;
					}

					else
					{
						self.buffer = nil;
						cancel = TRUE;
					}
				}

				else
				{
					self.buffer = nil;
					cancel = TRUE;
				}
			}

			else if ([fileExt isEqualToString:@"bin"])
			{
				if (self.buffer.length && self.buffer.length <= 0x10000)
				{
					uint8_t buffer[4]; buffer[0] = 0x00; buffer[1] = 0x00;
					buffer[2] = ((self.buffer.length - 1) >> 8) & 0xFF;
					buffer[3] = (self.buffer.length - 1) & 0xFF;

					NSMutableData *mutableData = [NSMutableData dataWithBytes:buffer length:4];
					[mutableData appendData:self.buffer];

					if (self.type)
					{
						uint16_t cs = csum(self.buffer.bytes, self.buffer.length, self.type == 2);
						buffer[2] = cs >> 8; buffer[3] = cs & 0xFF; buffer[1] = 0xE6;

						if (self.type == 2)
							[mutableData appendBytes:buffer + 2 length:2];
						else
							[mutableData appendBytes:buffer length:4];
					}

					self.buffer = mutableData;
				}

				else
				{
					self.buffer = nil;
					cancel = TRUE;
				}
			}

		}
	}

	else
	{
		cancel = TRUE;
	}

	panel = nil;
}

@end

// -----------------------------------------------------------------------------
// F80C - Вывод байта на магнитофон
// -----------------------------------------------------------------------------

@implementation F80C

@synthesize enabled;

// -----------------------------------------------------------------------------

- (id) initWithX8080:(X8080 *)cpu
{
	if (self = [self init])
		self.cpu = cpu;

	return self;
}

// -----------------------------------------------------------------------------

- (uint8_t *) BYTE:(uint16_t)addr
{
	if ([self.mem respondsToSelector:@selector(BYTE:)])
		return [(NSObject<BYTE> *)self.mem BYTE:addr];
	else
		return 0;
}

// -----------------------------------------------------------------------------

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if (*data == 0xA2 && enabled)
	{
		@synchronized(self)
		{
			uint8_t byte = self.type && self.type != 3 ? self.cpu.C : self.cpu.A;

			if (self.buffer == nil)
			{
				if (byte == 0xE6)
				{
					self.buffer = [NSMutableData dataWithBytes:&byte length:1];
					last = [NSProcessInfo processInfo].systemUptime;

					[self performSelectorOnMainThread:@selector(save)
										   withObject:nil
										waitUntilDone:FALSE];
				}
			}

			else
			{
				last = [NSProcessInfo processInfo].systemUptime;
				[self.buffer appendBytes:&byte length:1];
			}
		}

		*data = 0xC9;
		return;
	}

	[self.mem RD:addr data:data CLK:clock];
}

// -----------------------------------------------------------------------------

static NSString* stringFromRK(const uint8_t *ptr, NSUInteger length)
{
	NSMutableData *data = [NSMutableData dataWithBytes:ptr length:length];

	uint8_t* bytes = data.mutableBytes; while (length--)
	{
		if (*bytes >= 0x60) *bytes |= 0x80;	bytes++;
	}

	return [[NSString alloc] initWithBytes:data.bytes
									length:data.length
								  encoding:(NSStringEncoding) 0x80000A02];
}

// -----------------------------------------------------------------------------

- (void) save
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	savePanel.allowedFileTypes = @[@"rk"];

	while ([NSProcessInfo processInfo].systemUptime - last < 1)
	{
		@synchronized(self)
		{
			const uint8_t *ptr = self.buffer.bytes;
			NSUInteger length = self.buffer.length;

			if (length > 5)
			{
				if (ptr[1] == 0xE6 && ptr[2] == 0xE6 && ptr[3] == 0xE6 && ptr[4] == 0xE6)
				{
					int i; for (i = 5; i < length && ptr[i] >= 0x20 && ptr[i] < 0x7F; i++);

					if (ptr[i] == 0)
					{
						savePanel.nameFieldStringValue = stringFromRK(ptr + 5, i - 5);
						savePanel.allowedFileTypes = @[@"edm"];
						break;
					}
				}

				else if (ptr[1] == 0xD3 && ptr[2] == 0xD3 && ptr[3] == 0xD3)
				{
					if (ptr[4] == 0xD3)
					{
						int i; for (i = 5; i < length && ptr[i] >= 0x20 && ptr[i] < 0x7F; i++);

						if (ptr[i] == 0)
						{
							savePanel.allowedFileTypes = @[@"bsm"];

							if (ptr[5] == 0x22)
								savePanel.nameFieldStringValue = stringFromRK(ptr + 6, i - 6);
							else
								savePanel.nameFieldStringValue = stringFromRK(ptr + 5, i - 5);

							break;
						}
					}

					else
					{
						savePanel.allowedFileTypes = @[@"bss"];
						break;
					}
				}

				if (self.type == 3 && ptr[1] == 0xD9 && ptr[2] == 0xD9 && ptr[3] == 0xD9)
				{
					int i = 4; while (i < length && ptr[i] >= 0x20 && ptr[i] < 0x7F) i++; if (i < length && (ptr[i] == 0x00 || ptr[i] == 0x0D) && i <= 20)
					{
						int j = i; if (ptr[j] == 0x0D) j++; while (j < length && ptr[j] == 0x00) j++; if (j < length && ptr[j] == 0xE6)
						{
							if (j + ((ptr[j + 4] << 8) | ptr[j + 3]) - ((ptr[j + 2] << 8) | ptr[j + 1]) + 8 == length)
							{
								savePanel.allowedFileTypes = [NSArray arrayWithObject:self.extension];
								savePanel.nameFieldStringValue = stringFromRK(ptr + 4, i - 4);
								break;
							}
						}
					}
				}

				else if (self.type == 4 && ptr[0] == 0x00)
				{
					int i = 9; while (i < length && ptr[i] >= 0x20 && ptr[i] < 0x7F) i++; if (i < length && ptr[i] == 0x00 && i <= 25)
					{
						if (length == ((ptr[4] << 8) | ptr[3]) - ((ptr[2] << 8) | ptr[1]) + i + 2)
						{
							savePanel.allowedFileTypes = [NSArray arrayWithObject:self.extension];
							savePanel.nameFieldStringValue = stringFromRK(ptr + 9, i - 9);
							break;
						}
					}
				}

				else if (length > 0x5E && ptr[0x49] == 0xE6 && ptr[0x4A] == 0x00 && ptr[0x4B] == 0x00 && memcmp(ptr + 1, ptr + 0x4E, 8) == 0)
				{
					if (length == ((ptr[0x4C] << 8) | ptr[0x4D]) + 0x54)
					{
						const uint8_t *p = memchr(ptr + 1, 0x20, 8);

						savePanel.nameFieldStringValue = stringFromRK(ptr + 1, p ? p - ptr - 1 : 8);
						savePanel.allowedFileTypes = [NSArray arrayWithObject:self.extension];
						break;
					}
				}

				else
				{
					int i = ((ptr[3] << 8) | ptr[4]) - ((ptr[1] << 8) | ptr[2]) + 6;

					if (self.type == 3)
						i = ((ptr[4] << 8) | ptr[3]) - ((ptr[2] << 8) | ptr[1]) + 6;

					if (length - i == (self.type ? 2 : 0))
					{
						savePanel.allowedFileTypes = [NSArray arrayWithObject:self.extension];
						break;
					}

					if (length - i == 5 && ptr[i++] == 0x00 && ptr[i++] == 0x00 && ptr[i++] == 0xE6)
					{
						savePanel.allowedFileTypes = [NSArray arrayWithObject:self.extension];
						break;
					}

					if (length - i == 4 && ptr[i++] == 0x00 && ptr[i++] == 0xE6)
					{
						savePanel.allowedFileTypes = [NSArray arrayWithObject:self.extension];
						break;
					}
				}
			}
		}
	}

	if ([savePanel runModal] == NSFileHandlingPanelOKButton) @synchronized(self)
	{
		const uint8_t *ptr = self.buffer.bytes;
		NSUInteger length = self.buffer.length;

		if (length && *ptr == 0xE6)
			self.buffer = [NSMutableData dataWithBytes:++ptr length:--length];

		[self.buffer writeToURL:savePanel.URL atomically:TRUE];

		self.buffer = nil;
	}

	else @synchronized(self)
	{
		self.buffer = nil;
	}
}

@end
