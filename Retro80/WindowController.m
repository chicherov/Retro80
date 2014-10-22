#import "Retro80.h"

@interface WindowController ()
- (Document *) document;
@end

@implementation WindowController
{
	BOOL hideStatusLine;
	NSTimer *timer;
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

// -----------------------------------------------------------------------------
// Обработка FullScreen
// -----------------------------------------------------------------------------

- (void) hideMouse:(NSTimer *)theTimer
{
	[NSCursor setHiddenUntilMouseMoves:YES];
}

- (void) mouseMoved:(NSEvent *)theEvent
{
	[timer invalidate];

	timer = [NSTimer scheduledTimerWithTimeInterval:2.0
											 target:self
										   selector:@selector(hideMouse:)
										   userInfo:nil
											repeats:NO];
}

- (void) windowDidBecomeKey:(NSNotification *)notification
{
	if (self.window.styleMask & NSFullScreenWindowMask)
		[self mouseMoved:nil];

	[self.document.computer.kbd keyUp:nil];
}

- (void) windowWillEnterFullScreen:(NSNotification *)notification
{
	timer = [NSTimer scheduledTimerWithTimeInterval:2.0
											 target:self
										   selector:@selector(hideMouse:)
										   userInfo:nil
											repeats:NO];

	[self.window setAcceptsMouseMovedEvents:YES];

	self.constraint.constant = 0;
}

- (void) windowWillExitFullScreen:(NSNotification *)notification
{
	self.constraint.constant = hideStatusLine ? 0 : 22;

	[self.window setAcceptsMouseMovedEvents:NO];
	[NSCursor setHiddenUntilMouseMoves:NO];
	[timer invalidate];
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

	self.document.computer.snd.textField = self.text1;

#ifdef DEBUG
	[self.document.computer.crt.textField = self.text2 setHidden:NO];
#endif

	[[self window] setDelegate:self];
	[self.document.computer start];
}

- (void) windowWillClose:(NSNotification *)notification
{
	[self.document.computer stop];
	[self.document.computer.crt removeFromSuperviewWithoutNeedingDisplay];
}

@end
