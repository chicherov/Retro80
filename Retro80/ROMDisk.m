/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ROM-диск

 *****/

#import "ROMDisk.h"
#import "RKRecorder.h"

@implementation ROMDisk

@synthesize rom;
@synthesize MSB;

- (uint8_t)A
{
	if (rom.length == 0x100000)
		addr = (MSB << 16) | (C << 8) | B;

	else if (rom.length <= 0x10000)
		addr = (C << 8) | B;

	if (addr < rom.length)
		return ((const uint8_t *) rom.bytes)[addr];
	else
		return 0xFF;
}

- (void)setB:(uint8_t)data
{
	if ((data ^ B) & 0x01)
	{
		if (data & 0x01)
			addr = (((C & 0x0F) << 7 | (data >> 1)) << 11) | latch;
		else
			latch = (C & 0x0F) << 7 | (data >> 1);
	}
}

- (void)setURL:(NSURL *)url
{
	if (url && (rom = [NSData dataWithContentsOfFile:[[url path] stringByResolvingSymlinksInPath]]) != nil)
		URL = url;

	else
	{
		rom = nil;
		URL = nil;
	}
}

- (NSURL *)URL
{
	return URL;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:resource forKey:@"resource"];
	[encoder encodeObject:URL forKey:@"URL"];

	[encoder encodeInteger:MSB forKey:@"MSB"];

	if (rom.length > 0x10000)
	{
		[encoder encodeInteger:latch forKey:@"latch"];
		[encoder encodeInteger:addr forKey:@"addr"];
	}
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		resource = [decoder decodeObjectForKey:@"resource"];
		self.URL = [decoder decodeObjectForKey:@"URL"];

		MSB = (uint8_t) [decoder decodeIntegerForKey:@"MSB"];

		if (rom.length > 0x10000)
		{
			latch = (uint32_t) [decoder decodeIntegerForKey:@"latch"];
			addr = (uint16_t) [decoder decodeIntegerForKey:@"addr"];
		}
	}

	return self;
}

- (instancetype)initWithContentsOfResource:(NSString *)aResource
{
	if (self = [super init])
		self.URL = [[NSBundle mainBundle] URLForResource:resource = aResource withExtension:@"rom"];

	return self;
}

- (BOOL)validateDirectory:(NSURL *)url error:(NSError **)outError
{
	return NO;
}

- (BOOL)validateFile:(NSURL *)url error:(NSError **)outError
{
	NSNumber *fileSize = nil;

	if (![url getResourceValue:&fileSize forKey:NSURLFileSizeKey error:outError])
		return FALSE;

	NSUInteger size = fileSize.unsignedIntegerValue;

	if (size == 0x80000 || size == 0x40000 || size == 0x100000)
		return TRUE;

	return size && size <= 0x10000;
}

- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url
{
	BOOL isDirectory;

	if ([[NSFileManager defaultManager] fileExistsAtPath:url.path.stringByResolvingSymlinksInPath
											 isDirectory:&isDirectory])
	{
		return isDirectory || [self validateFile:url error:nil];
	}

	return FALSE;
}

- (BOOL)panel:(id)sender validateURL:(NSURL *)url error:(NSError **)outError
{
	BOOL isDirectory;

	if ([[NSFileManager defaultManager] fileExistsAtPath:url.path.stringByResolvingSymlinksInPath
											 isDirectory:&isDirectory])
	{
		if (isDirectory)
			return [self validateDirectory:url error:outError];
		else
			return [self validateFile:url error:outError];
	}

	return FALSE;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(ROMDisk:))
	{
		@synchronized(self.computer)
		{
			if (menuItem.tag == 0)
			{
				if ((menuItem.hidden = [URL.URLByDeletingLastPathComponent.path isEqualToString:[NSBundle mainBundle].resourcePath]))
					return NO;

				menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;

				if ((menuItem.state = URL != nil))
					menuItem.title = [menuItem.title stringByAppendingFormat:@": %@", URL.lastPathComponent];

				return YES;
			}

			if (menuItem.tag == 1)
			{
				menuItem.state = [URL.URLByDeletingLastPathComponent.path isEqualToString:[NSBundle mainBundle].resourcePath];
				menuItem.alternate = !menuItem.state;
				menuItem.hidden = FALSE;
				return YES;
			}
		}
	}

	menuItem.alternate = FALSE;
	menuItem.hidden = TRUE;
	return NO;
}

- (IBAction)ROMDisk:(NSMenuItem *)menuItem
{
	if (menuItem.tag == 1 && ![URL.URLByDeletingLastPathComponent.path isEqualToString:[NSBundle mainBundle].resourcePath])
	{
		@synchronized(self.computer)
		{
			[self.computer registerUndoWithMenuItem:menuItem];
			self.URL = [[NSBundle mainBundle] URLForResource:resource withExtension:@"rom"];
			return;
		}
	}

	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.allowedFileTypes = @[@"rom", @"bin"];
	panel.canChooseDirectories = TRUE;
	panel.title = menuItem.title;
	panel.delegate = self;

	if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
	{
		@synchronized(self.computer)
		{
			[self.computer registerUndoWithMenuItem:menuItem];
			self.URL = panel.URLs.firstObject;
		}
	}
	else
	{
		@synchronized(self.computer)
		{
			if (URL != nil)
			{
				[self.computer registerUndoWithMenuItem:menuItem];
				self.URL = nil;
			}
		}
	}
}

@end
