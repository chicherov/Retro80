#import "Retro80.h"

@implementation WindowController
{
	id eventMonitor;
}

- (void) windowDidLoad
{
	self.document.computer.document = self.document;

	self.document.computer.crt.display = self.document.display;
	self.document.computer.snd.sound = self.document.sound;

	self.document.display.crt = self.document.computer.crt;
	self.document.display.kbd = self.document.computer.kbd;

	self.document.sound.cpu = self.document.computer.cpu;
	self.document.sound.snd = self.document.computer.snd;
	self.document.sound.crt = self.document.computer.crt;

	self.document.computer.nextResponder = self.document.display;
	self.nextResponder = self.document.computer;

	__weak WindowController *safeSelf = self;

	eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^(NSEvent *theEvent)
					{
						NSWindow *targetWindow = theEvent.window;
						if (targetWindow != safeSelf.window)
							return theEvent;

						if (theEvent.keyCode == 53 || theEvent.keyCode == 48)
						{
							[safeSelf keyDown:theEvent];
							return (NSEvent*) nil;
						}

						return theEvent;
					}];

	[self.document.computer start];
}

- (void) windowWillClose:(NSNotification *)notification
{
	[self.document.computer stop];
	[NSEvent removeMonitor:eventMonitor];
}

// -----------------------------------------------------------------------------
// DEBUG: dealloc
// -----------------------------------------------------------------------------

#ifdef DEBUG
- (void) dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
