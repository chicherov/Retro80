#import "Retro80.h"

@interface WindowController ()
- (Document *) document;
@end

@implementation WindowController
{
	BOOL hideStatusLine;
}

- (Document *) document
{
	return super.document;
}


- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(statusLine:))
	{
		menuItem.state = self.constraint.constant == 22;
		return (self.window.styleMask & NSFullScreenWindowMask) == 0;
	}

	return NO;
}

- (void) windowDidResize:(NSNotification *)notification
{
	self.constraint.constant = self.window.styleMask & NSFullScreenWindowMask || hideStatusLine ? 0 : 22;
}

- (IBAction) statusLine:(id)sender
{
	if ((self.window.styleMask & NSFullScreenWindowMask) == 0)
	{
		NSRect frame = self.window.frame; if ((hideStatusLine = !hideStatusLine))
		{
			if (self.constraint.constant == 22)
			{
				frame.size.height -= 22;
				frame.origin.y += 22;
				[self.window setFrame:frame display:FALSE];
				self.constraint.constant = 0;
			}
		}
		else if (self.constraint.constant == 0)
		{
			frame.size.height += 22;
			frame.origin.y -= 22;
			[self.window setFrame:frame display:FALSE];

			self.constraint.constant = 22;
		}
	}
}

- (void) windowDidLoad
{
	self.document.computer.document = self.document;

	Screen* screen = self.document.computer.crt;
	[self.view addSubview:screen];

	[self.window makeFirstResponder:self.document.computer];

	self.document.computer.snd.nextResponder = screen.nextResponder;
	screen.nextResponder = self.document.computer.snd;
	self.document.computer.nextResponder = screen;

	[self.view addConstraint: [NSLayoutConstraint constraintWithItem:screen
															 attribute:NSLayoutAttributeWidth
															 relatedBy:NSLayoutRelationEqual
																toItem:self.view
															 attribute:NSLayoutAttributeWidth
															multiplier:1
															  constant:0]];

	[self.view addConstraint: [NSLayoutConstraint constraintWithItem:screen
															 attribute:NSLayoutAttributeHeight
															 relatedBy:NSLayoutRelationEqual
																toItem:self.view
															 attribute:NSLayoutAttributeHeight
															multiplier:1
															  constant:0]];

	[screen setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];

	[screen setTranslatesAutoresizingMaskIntoConstraints:NO];

	self.document.computer.snd.text = self.text1;

	[[self window] setDelegate:self];
	[self.document.computer start];
}

- (void) windowWillClose:(NSNotification *)notification
{
	[self.document.computer stop];
	[self.document.computer.crt removeFromSuperviewWithoutNeedingDisplay];
}

@end
