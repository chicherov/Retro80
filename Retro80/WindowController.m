#import "Retro80.h"

@interface WindowController ()
- (Document *) document;
@end

@implementation WindowController

- (Document *) document
{
	return super.document;
}

- (IBAction)reset:(id)sender
{
	@synchronized(self.document.computer.snd)
	{
		[self.document undoPoint:@"Reset"];
	}

	[self.document.computer reset];
}

- (void) windowDidLoad
{
	Screen* screen = self.document.computer.crt;
	[self.window makeFirstResponder:screen];
	[self.view addSubview:screen];

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

	screen.document = self.document;
	[self.document.computer start];
}

- (void) windowWillClose:(NSNotification *)notification
{
//	self.document.computer.crt.document = nil;
	[self.document.computer stop];
}

@end
