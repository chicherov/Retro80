/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 *****/

#import "DocumentController.h"
#import "ComputerFactory.h"
#import "Document.h"
#import "Computer.h"

@implementation DocumentController
{
	IBOutlet NSMenuItem *menuNew;
}

- (Document *)makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)outError
{
	NSInteger tag = [[NSUserDefaults standardUserDefaults] integerForKey:@"computer"];
	Computer *computer = [ComputerFactory computerByTag:tag];

	return [[Document alloc] initWithComputerType:computer
										 typeName:typeName
											error:outError];
}

- (IBAction) newDocument:(NSMenuItem *)menuItem
{
	if (menuItem.tag && [self parseMenu:menuNew tag:menuItem.tag])
		[[NSUserDefaults standardUserDefaults] setInteger:menuItem.tag forKey:@"computer"];

	[super newDocument:menuItem];
}

- (BOOL)parseMenu:(NSMenuItem *)menu tag:(NSInteger)tag
{
	BOOL done = NO;

	for (NSMenuItem *menuItem in [menu.submenu itemArray])
	{
		if (menuItem.hasSubmenu)
		{
			if ([self parseMenu:menuItem tag:tag])
				menuItem.state = done = YES;
			else
				menuItem.state = NO;
		}

		else if (menuItem.tag == tag)
		{
			menuItem.keyEquivalentModifierMask = NSCommandKeyMask;
			menuItem.keyEquivalent = @"n";
			menuItem.state = done = YES;
		}

		else
		{
			menuItem.keyEquivalent = @"";
			menuItem.state = NO;
		}
	}

	return done;
}

- (void)awakeFromNib
{
	NSInteger tag = [[NSUserDefaults standardUserDefaults] integerForKey:@"computer"];

	if (tag == 0 || ![self parseMenu:menuNew tag:tag])
	{
		NSMenuItem *menuItem = [menuNew.submenu itemAtIndex:0];
		menuItem.keyEquivalentModifierMask = NSCommandKeyMask;
		menuItem.keyEquivalent = @"n";
		menuItem.state = YES;
	}
}

@end
