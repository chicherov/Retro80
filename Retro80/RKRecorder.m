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

	Sound __weak *snd;
	BOOL _enabled;
}

// -----------------------------------------------------------------------------

- (id) initWithSound:(Sound *)sound
{
	if (self = [super init])
	{
		_enabled = [[NSUserDefaults standardUserDefaults]
					integerForKey:@"Tape Read Hook"];

		snd = sound; _readError = 0xF800;
	}

	return self;
}
// -----------------------------------------------------------------------------

- (void) open
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];

	openPanel.allowedFileTypes = [NSArray arrayWithObjects:@"wav", @"rk", @"pki", @"gam", @"edm", @"bss", @"bsm", self.extension, nil];

	if ([openPanel runModal] == NSFileHandlingPanelOKButton && openPanel.URLs.count == 1)
	{
		NSString *fileName = [[openPanel.URLs.firstObject path] stringByResolvingSymlinksInPath];
		NSString *extension = [[fileName pathExtension]lowercaseString];

		if ([extension isEqualToString:@"wav"])
		{
			[snd stop];

			if ([snd open:openPanel.URLs.firstObject])
			{
				[snd start]; panel = 0; return;
			}

			[snd start];
		}

		else if ((data = [NSData dataWithContentsOfFile:fileName]))
		{
			bytes = data.bytes; length = data.length; pos = 0;

			if ([@[@"pki", @"gam", @"bss", @"bsm"] containsObject:extension])
			{
				if (length && bytes[0] == 0xE6)
					pos++;
			}
		}
	}

	panel = 2;
}

// -----------------------------------------------------------------------------

- (int) execute:(X8080 *)cpu
{
	if (_enabled && !snd.isInput)
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

				if (cpu.A == 0xFF)
				{
					while (pos < length && bytes[pos++] != 0xE6);
				}

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
					cpu.A = 0x08;
				}
				else
				{
					cpu.PC = self.readError;
				}
				
				return 0;
			}
		}
	}

	return 2;
}

// -----------------------------------------------------------------------------

- (void) setEnabled:(BOOL)enabled
{
	[[NSUserDefaults standardUserDefaults]
	 setInteger:_enabled = enabled
	 forKey:@"Tape Read Hook"];
}

- (BOOL) enabled
{
	return _enabled;
}

- (NSInteger) tag
{
	return 3;
}

@end

// -----------------------------------------------------------------------------
// F80C - Вывод байта на магнитофон
// -----------------------------------------------------------------------------

@implementation F80C
{
	NSMutableData* data;
	NSTimeInterval last;

	BOOL _enabled;
}

// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		_enabled = [[NSUserDefaults standardUserDefaults]
					integerForKey:@"Tape Write Hook"];

	}

	return self;

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

					else if (ptr[4] == 0x00)
					{
						savePanel.allowedFileTypes = @[@"bss"];
						break;
					}
				}

				else
				{
					NSUInteger i = ((ptr[3] << 8) | ptr[4]) - ((ptr[1] << 8) | ptr[2]) + 6;

					if (length - i == _Micro80 ? 0 : 2)
					{
						savePanel.allowedFileTypes = [NSArray arrayWithObject:self.extension];
						break;
					}

					if (length - i == 5 && ptr[i++] == 0x00 && ptr[i++] == 0x00 && ptr[i++] == 0xE6)
					{
						savePanel.allowedFileTypes = [NSArray arrayWithObject:self.extension];
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
	if (_enabled)
	{
		@synchronized(self)
		{
			uint8_t byte = _Micro80 ? cpu.A : cpu.C;

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

// -----------------------------------------------------------------------------

- (void) setEnabled:(BOOL)enabled
{
	[[NSUserDefaults standardUserDefaults]
	 setInteger:_enabled = enabled
	 forKey:@"Tape Write Hook"];
}

- (BOOL) enabled
{
	return _enabled;
}

- (NSInteger) tag
{
	return 2;
}

@end
