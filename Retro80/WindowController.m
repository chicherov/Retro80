#import "Retro80.h"

@interface WindowController ()
- (Document *) document;
@end

@implementation WindowController

- (Document *) document
{
	return super.document;
}

- (void) windowDidLoad
{
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

//	screen.document = self.document;
	self.document.computer.document = self.document;
	[self.document.computer start];
}

- (void) windowWillClose:(NSNotification *)notification
{
	[self.document.computer stop];
	[self.document.computer.crt removeFromSuperviewWithoutNeedingDisplay];
}

@end
