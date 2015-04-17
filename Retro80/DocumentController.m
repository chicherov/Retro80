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
	if (index >= 100 && index / 100 <= computers.count)
	{
		Computer *computer = [[NSClassFromString([computers objectAtIndex:index / 100 - 1]) alloc] initWithType:index % 100];

		if (computer)
			return [[Document alloc] initWithComputer:computer type:typeName error:outError];
	}

	*outError = nil;
	return nil;
}

// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(newDocument:))
		return menuItem.enabled;

	return [super validateMenuItem:menuNew];
}

// -----------------------------------------------------------------------------

- (IBAction) newDocument:(NSMenuItem *)sender
{
	if (sender.tag >= 100 && [self parseMenu:menuNew tag:sender.tag])
	{
		[[NSUserDefaults standardUserDefaults] setInteger:index = sender.tag
												   forKey:@"computer"];

		[super newDocument:sender];
	}

	else if (sender.tag == -1)
	{
		[super newDocument:sender];
	}
}

// -----------------------------------------------------------------------------

- (Computer *) computerByFileExtension:(NSURL *)url data:(NSData *)data
{
	NSString *fileExtension = url.pathExtension.lowercaseString;

	for (NSString *className in computers)
	{
		Class class; if ([(class = NSClassFromString(className)) isSubclassOfClass:[Computer class]])
		{
			if ([[class extensions] containsObject:fileExtension])
				return [[class alloc] initWithData:data URL:url];
		}
	}

	return nil;
}

// -----------------------------------------------------------------------------

- (BOOL) parseMenu:(NSMenuItem *)menu tag:(NSInteger)tag
{
	BOOL done = FALSE; for (NSMenuItem *item in [menu.submenu itemArray])
	{
		if (item.hasSubmenu)
		{
			if ([self parseMenu:item tag:tag])
			{
				item.state = NSOnState;
				done = TRUE;
			}
			else
			{
				item.state = NSOffState;
			}
		}

		else if (item.tag == tag)
		{
			item.keyEquivalentModifierMask = NSCommandKeyMask;
			item.keyEquivalent = @"n";
			item.state = NSOnState;
			done = TRUE;
		}

		else
		{
			item.keyEquivalent = @"";
			item.state = NSOffState;
		}
	}

	return done;
}

// -----------------------------------------------------------------------------

- (void) awakeFromNib
{
	computers = @[@"Radio86RK",  @"Microsha", @"Partner", @"Apogeo", @"Micro80", @"UT88", @"Specialist", @"Orion128"];
	index = [[NSUserDefaults standardUserDefaults] integerForKey:@"computer"];

	if (index == 0 || ![self parseMenu:menuNew tag:index])
	{
		NSMenuItem *menu = [menuNew.submenu itemAtIndex:0];
		menu.keyEquivalentModifierMask = NSCommandKeyMask;
		menu.keyEquivalent = @"n";
		menu.state = NSOnState;
		index = menu.tag;
	}
}

@end
