#import "RKRecorder.h"
#import "Sound.h"

// -----------------------------------------------------------------------------
// F806 - Ввод байта с магнитофона
// -----------------------------------------------------------------------------

@implementation F806
{
	int panel; NSData* data;

	const uint8_t* bytes;
	NSUInteger length;
	NSUInteger pos;

	NSObject<SoundController> __weak *snd;
}

@synthesize enabled;

@synthesize extension;
@synthesize readError;
@synthesize type;

// -----------------------------------------------------------------------------

uint16_t csum(const uint8_t* ptr, size_t size, bool microsha)
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

- (id) initWithSound:(NSObject<SoundController> *)object
{
	if (self = [super init])
	{
		snd = object; readError = 0xF800;
	}

	return self;
}

- (void) setData:(NSData *)initData
{
	data = initData; bytes = data.bytes;
	length = data.length; pos = 0;
}

// -----------------------------------------------------------------------------

- (void) open
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];

	openPanel.allowedFileTypes = [NSArray arrayWithObjects:@"wav", @"bin", @"rk", @"pki", @"gam", @"edm", @"bss", @"bsm", extension, nil];

	if ([openPanel runModal] == NSFileHandlingPanelOKButton && openPanel.URLs.count == 1)
	{
		NSString *fileName = [[openPanel.URLs.firstObject path] stringByResolvingSymlinksInPath];
		NSString *fileExt = [[fileName pathExtension]lowercaseString];

		if ([fileExt isEqualToString:@"wav"])
		{
			[snd.sound stop];

			if ([snd.sound open:openPanel.URLs.firstObject])
			{
				[snd.sound start]; panel = 0; return;
			}

			[snd.sound start];
		}

		else if ((data = [NSData dataWithContentsOfFile:fileName]))
		{
			bytes = data.bytes; length = data.length; pos = 0;

			if ([@[@"pki", @"gam", @"bss", @"bsm"] containsObject:fileExt])
			{
				if (length && bytes[0] == 0xE6)
					pos++;
			}
			else if ([fileExt isEqualToString:@"bin"] && length <= 0x10000)
			{
				uint8_t buffer[4]; buffer[0] = 0x00; buffer[1] = 0x00;
				buffer[2] = ((length - 1) >> 8) & 0xFF;
				buffer[3] = (length - 1) & 0xFF;

				NSMutableData *mutableData = [NSMutableData dataWithBytes:buffer length:4];
				[mutableData appendData:data];

				if (type)
				{
					uint16_t cs = csum(bytes, length, type == 2);
					buffer[2] = cs >> 8; buffer[3] = cs & 0xFF;
					buffer[1] = 0xE6;

					if (type == 2)
						[mutableData appendBytes:buffer + 2 length:2];
					else
						[mutableData appendBytes:buffer length:4];
				}

				data = mutableData; bytes = data.bytes; length = data.length;
			}
		}
	}

	panel = 2;
}

// -----------------------------------------------------------------------------

- (int) execute:(X8080 *)cpu
{
	if (enabled && !snd.sound.isInput)
	{
		switch (panel)
		{
			case 0:
			{
				if (pos == length)
				{
					if (cpu.A == 0xFF)
					{
						panel = 1; [self performSelectorOnMainThread:@selector(open) withObject:nil waitUntilDone:FALSE];
					}
					else
					{
						cpu.PC = self.readError;
					}

					return 0;
				}

				if (cpu.A == 0xFF && pos != 0)
					while (pos < length && bytes[pos++] != 0xE6);

				if (pos == length)
					return 0;

				cpu.A = bytes[pos++];
				return 1;
			}

			case 1:
			{
				return 0;
			}

			case 2:
			{
				panel = 0; if (pos < length)
				{
					cpu.A = bytes[pos++];
					return 1;
				}

				cpu.PC = self.readError;
				return 0;
			}
		}
	}

	return 2;
}

@end

// -----------------------------------------------------------------------------
// F80C - Вывод байта на магнитофон
// -----------------------------------------------------------------------------

@implementation F80C
{
	NSMutableData* data;
	NSTimeInterval last;
}

@synthesize enabled;

@synthesize extension;
@synthesize type;

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
			const uint8_t *ptr = data.bytes;
			NSUInteger length = data.length;

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

				else
				{
					NSUInteger i = ((ptr[3] << 8) | ptr[4]) - ((ptr[1] << 8) | ptr[2]) + 6;

					if (length - i == (type ? 2 : 0))
					{
						savePanel.allowedFileTypes = [NSArray arrayWithObject:extension];
						break;
					}

					if (length - i == 5 && ptr[i++] == 0x00 && ptr[i++] == 0x00 && ptr[i++] == 0xE6)
					{
						savePanel.allowedFileTypes = [NSArray arrayWithObject:extension];
						break;
					}

					if (length - i == 4 && ptr[i++] == 0x00 && ptr[i++] == 0xE6)
					{
						savePanel.allowedFileTypes = [NSArray arrayWithObject:extension];
						break;
					}
				}
			}
		}
	}

	if ([savePanel runModal] == NSFileHandlingPanelOKButton)
	{
		@synchronized(self)
		{
			const uint8_t *ptr = data.bytes;
			NSUInteger length = data.length;

			if (length-- && *ptr++ == 0xE6)
				data = [NSMutableData dataWithBytes:ptr length:length];

			[data writeToURL:savePanel.URL atomically:TRUE];

			data = nil;
		}
	}
	else
	{
		@synchronized(self)
		{
			data = nil;
		}
	}
}

// -----------------------------------------------------------------------------

- (int) execute:(X8080 *)cpu
{
	if (enabled)
	{
		@synchronized(self)
		{
			uint8_t byte = type ? cpu.C : cpu.A;

			if (data == nil)
			{
				if (byte != 0xE6)
					return 1;

				data = [NSMutableData dataWithBytes:&byte length:1];
				last = [NSProcessInfo processInfo].systemUptime;

				[self performSelectorOnMainThread:@selector(save) withObject:nil waitUntilDone:FALSE];
			}
			else
			{
				last = [NSProcessInfo processInfo].systemUptime;
				[data appendBytes:&byte length:1];
			}
		}
		
		return 1;
	}

	return 2;
}

@end
