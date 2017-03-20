/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Системный ROM-диск

 *****/

#import "SystemROMDisk.h"

@implementation SystemROMDisk

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(ROMDisk:))
	{
		switch (menuItem.tag)
		{
			case 0:

				@synchronized(self.computer)
				{
					if ((menuItem.hidden = [URL.URLByDeletingLastPathComponent.path isEqualToString:[NSBundle mainBundle].resourcePath]))
						return NO;
				}

				return [super validateMenuItem:menuItem];

			case 1:

				@synchronized(self.computer)
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
	if (menuItem.tag == 1)
	{
		@synchronized(self.computer)
		{
			[self.computer registerUndoWithMenuItem:menuItem];

			if (![URL.URLByDeletingLastPathComponent.path isEqualToString:[NSBundle mainBundle].resourcePath])
				self.URL = [[NSBundle mainBundle] URLForResource:resource withExtension:@"rom"];
			else
				self.URL = nil;
		}

	}
	else
	{
		return [super ROMDisk:menuItem];
	}

}

- (instancetype)initWithContentsOfResource:(NSString *)string
{
	if (self = [super init])
		self.URL = [[NSBundle mainBundle] URLForResource:resource = string withExtension:@"rom"];

	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	[encoder encodeObject:resource forKey:@"resource"];
}

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
		resource = [decoder decodeObjectForKey:@"resource"];

	return self;
}

@end
