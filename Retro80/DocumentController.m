#import "Retro80.h"

@implementation DocumentController
{
	IBOutlet NSMenuItem *menuNew;

	NSArray *computers;
	NSInteger index;
}

// -----------------------------------------------------------------------------

- (id) makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)outError
{
	Computer *computer = [[NSClassFromString([computers objectAtIndex:index]) alloc] init];

	if (computer)
		return [[Document alloc] initWithComputer:computer type:typeName error:outError];

	*outError = nil;
	return nil;
}

// -----------------------------------------------------------------------------

- (IBAction) newDocument:(NSMenuItem *)sender
{
	NSInteger tag = sender.tag; if (tag >= 0 && tag < computers.count)
	{
		for (NSMenuItem *item in [menuNew.submenu itemArray])
		{
			item.state = item.tag == tag ? NSOnState : NSOffState;
			item.keyEquivalent = item.tag == tag ? @"n" : @"";
		}
	}

	else
	{
		tag = 0; for (NSMenuItem *item in [menuNew.submenu itemArray])
			if (item.state == NSOnState)
				tag = item.tag;
	}

	if ([NSClassFromString([computers objectAtIndex:tag]) isSubclassOfClass:[Computer class]])
		[[NSUserDefaults standardUserDefaults] setInteger:index = tag forKey:@"computer"];

	[super newDocument:sender];
}

// -----------------------------------------------------------------------------

- (Computer *) computerByFileExtension:(NSString *)fileExtension data:(NSData *)data
{
	for (NSString *className in computers)
	{
		Class class; if ([(class = NSClassFromString(className)) isSubclassOfClass:[Computer class]])
		{
			if ([[class ext] isEqualTo:fileExtension])
				return [[class alloc] initWithData:data];
		}
	}

	if (([fileExtension isEqualToString:@"gam"] || [fileExtension isEqualToString:@"pki"]) && data.length && *(uint8_t *)data.bytes == 0xE6)
		return [[NSClassFromString(@"Radio86RK") alloc] initWithData:[NSData dataWithBytes:(uint8_t *)data.bytes + 1 length:data.length - 1]];

	return [[NSClassFromString(@"Radio86RK") alloc] initWithData:data];
}

// -----------------------------------------------------------------------------

- (void) awakeFromNib
{
	computers = [NSArray arrayWithObjects: @"Partner", @"Apogeo", @"Radio86RK", @"Microsha", @"~", @"Micro80", @"UT88", nil];
	index = [[NSUserDefaults standardUserDefaults] integerForKey:@"computer"];

	BOOL done = FALSE; for (NSInteger tag = 0; tag < computers.count; tag++)
	{
		if ([[computers objectAtIndex:tag] isEqual:@"~"])
		{
			[menuNew.submenu addItem:[NSMenuItem separatorItem]];
		}
		else
		{
			Class class; if ([(class = NSClassFromString([computers objectAtIndex:tag])) isSubclassOfClass:[Computer class]])
			{
				NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:[class title] action:@selector(newDocument:) keyEquivalent:@""];

				if ((menuItem.tag = tag) == index)
				{
					menuItem.keyEquivalent = @"n";
					menuItem.state = NSOnState;
					done = TRUE;
				}

				[menuNew.submenu addItem:menuItem];
			}
		}
	}

	if (!done)
	{
		NSMenuItem *menuItem = [menuNew.submenu itemAtIndex:0];

		menuItem.keyEquivalent = @"n";
		menuItem.state = NSOnState;
		index = menuItem.tag;
	}
}

@end
