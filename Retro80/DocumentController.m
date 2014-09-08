#import "Retro80.h"

@implementation DocumentController
{
	IBOutlet NSMenuItem *menuNew;

	NSArray *computers;
	NSInteger computer;
}

// -----------------------------------------------------------------------------

- (id) makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)outError
{
	Document *document = [super makeUntitledDocumentOfType:typeName error:outError]; if (document)
	{
		document.computer = [[NSClassFromString([computers objectAtIndex:computer]) alloc] init];

		if (![document.computer isKindOfClass:[Computer class]])
		{
			if (outError)
			{
				*outError = [NSError errorWithDomain:@"com.uart.Retro80"
												code:1
											userInfo:nil];
			}

			return nil;
		}

		document.computer.document = document;
	}

	return document;
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
	{
		[[NSUserDefaults standardUserDefaults] setInteger:computer = tag forKey:@"computer"];
	}

	[super newDocument:sender];
}

// -----------------------------------------------------------------------------

- (void) awakeFromNib
{
	computers = [NSArray arrayWithObjects: @"Apogeo", @"Radio86RK", @"Microsha", @"~", @"Micro80", @"UT88", nil];
	computer = [[NSUserDefaults standardUserDefaults] integerForKey:@"computer"];

	for (NSInteger tag = 0; tag < computers.count; tag++)
	{
		if ([[computers objectAtIndex:tag] isEqual:@"~"])
		{
			[menuNew.submenu addItem:[NSMenuItem separatorItem]];
		}
		else
		{
			Class class = NSClassFromString([computers objectAtIndex:tag]);

			if ([class isSubclassOfClass:[Computer class]])
			{
				NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:[class title] action:@selector(newDocument:) keyEquivalent:@""];

				if ((menuItem.tag = tag) == computer)
				{
					menuItem.keyEquivalent = @"n";
					menuItem.state = NSOnState;
				}

				[menuNew.submenu addItem:menuItem];
			}
		}
	}
}

@end
