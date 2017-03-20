/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 *****/

#import "WindowController.h"
#import "Document.h"

#import "Computer.h"
#import "Display.h"
#import "Sound.h"
#import "Debug.h"

@implementation WindowController
{
	id __weak eventMonitor;
	unichar lastUndoChar;

	IBOutlet NSLayoutConstraint *constraint;
	BOOL hideStatusLine;

	NSInteger scale;
	NSSize lastSize;

	NSTimer *timer;

	NSInteger vbScale;
	NSRect vbFrame;
}

@dynamic document;

- (void)startComputer
{
	Computer *computer = self.document.computer;

	computer.document = self.document;
	computer.display = self.display;
	computer.sound = self.sound;
	computer.debug = self.debug;

	self.nextResponder = self.display;
	self.display.nextResponder = self.sound;
	self.sound.nextResponder = self.debug;
	self.debug.nextResponder = computer;

	self.sound.computer = computer;

	[computer start];
}

- (void)stopComputer
{
	[self.document.computer stop];

	self.debug.nextResponder = nil;
}

// Автоматический запуск компьютера при открытии окна

- (void)windowDidLoad
{
	eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^(NSEvent *theEvent) {

		if (theEvent.window == self.window && (theEvent.keyCode == 53 || theEvent.keyCode == 48))
		{
			[self keyDown:theEvent];
			return (NSEvent *) nil;
		}
		else
		{
			return theEvent;
		}
	}];

	scale = 2;

	if (self.document.isInViewingMode)
		constraint.constant = 0;

	[self startComputer];
}

// Автоматический останов компьютера при закрытии окна

- (void)windowWillClose:(NSNotification *)notification
{
	[NSEvent removeMonitor:eventMonitor];

	[self stopComputer];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(statusLine:))
	{
		menuItem.state = constraint.constant == 22;
		return (self.window.styleMask & NSWindowStyleMaskFullScreen) == 0;
	}

	if (menuItem.action == @selector(scale:))
	{
		if (self.window.styleMask & NSWindowStyleMaskFullScreen)
		{
			menuItem.state = FALSE;
			return NO;
		}

		NSSize size = self.display.size;

		if (scale && menuItem.tag == scale)
			menuItem.state = size.width*scale == self.display.frame.size.width
				&& size.height*scale == self.display.frame.size.height;
		else
			menuItem.state = FALSE;

		if (menuItem.tag)
		{
			if (self.window.screen.frame.size.height
				< size.height*menuItem.tag + self.window.frame.size.height - self.display.frame.size.height)
				return NO;

			if (self.window.screen.frame.size.width < size.width*menuItem.tag)
				return NO;
		}

		return YES;
	}

	return [super validateMenuItem:menuItem];
}

// Обработка наличия строки состояния

- (IBAction)statusLine:(NSMenuItem *)sender
{
	if ((self.window.styleMask & NSWindowStyleMaskFullScreen) == 0)
	{
		NSRect frame = self.window.frame;

		if ((hideStatusLine = !hideStatusLine))
		{
			if (constraint.constant == 22)
			{
				frame.size.height -= 22;
				frame.origin.y += 22;

				[self.window setFrame:frame display:FALSE];
				constraint.constant = 0;
			}
		}
		else if (constraint.constant == 0)
		{
			frame.size.height += 22;
			frame.origin.y -= 22;

			[self.window setFrame:frame display:FALSE];
			constraint.constant = 22;
		}
	}
}

// Обработка масштабирования

- (IBAction)scale:(NSMenuItem *)sender
{
	if (!self.document.inViewingMode && sender.tag > 0 && sender.tag <= 3)
	{
		lastSize = NSZeroSize;
		scale = sender.tag;
		[self resize];
	}
}

- (void)resize
{
	NSSize size = self.display.size;
	if (size.width && size.height)
	{
		NSRect frame = self.window.frame;
		CGFloat addHeight = frame.size.height - self.display.frame.size.height;
		[self.window setMinSize:NSMakeSize(size.width, size.height + addHeight)];

		if (scale && !(self.window.styleMask & NSWindowStyleMaskFullScreen))
		{
			if (lastSize.width && lastSize.height)
				if (lastSize.width != frame.size.width || lastSize.height + constraint.constant != frame.size.height)
					scale = 0;

			if (scale)
			{
				frame.origin.y += frame.size.height;
				frame.size.width = size.width*scale;
				frame.size.height = size.height*scale + addHeight;
				frame.origin.y -= frame.size.height;

				[self.window setFrame:frame display:TRUE];
				frame.size.height -= constraint.constant;
				lastSize = frame.size;
			}
		}
	}
}

// Обработка FullScreen

- (void)hideMouse
{
	[NSCursor setHiddenUntilMouseMoves:YES];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	timer = [NSTimer scheduledTimerWithTimeInterval:2.0
											 target:self
										   selector:@selector(hideMouse)
										   userInfo:nil
											repeats:NO];
}

- (void)windowWillEnterFullScreen:(NSNotification *)notification
{
	timer = [NSTimer scheduledTimerWithTimeInterval:2.0
											 target:self
										   selector:@selector(hideMouse)
										   userInfo:nil
											repeats:NO];

	[self.window setAcceptsMouseMovedEvents:YES];
	constraint.constant = 0;
}

- (void)windowWillExitFullScreen:(NSNotification *)notification
{
	constraint.constant = hideStatusLine ? 0 : 22;

	[self.window setAcceptsMouseMovedEvents:NO];
	[NSCursor setHiddenUntilMouseMoves:NO];
	[timer invalidate];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
	[self resize];
}

// Обработка фокуса приложения

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	if (self.window.styleMask & NSWindowStyleMaskFullScreen)
	{
		timer = [NSTimer scheduledTimerWithTimeInterval:2.0
												 target:self
											   selector:@selector(hideMouse)
											   userInfo:nil
												repeats:NO];
	}
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	[super keyUp:[NSEvent keyEventWithType:NSEventTypeKeyUp
								  location:NSZeroPoint
							 modifierFlags:0
								 timestamp:0
							  windowNumber:0
								   context:nil
								characters:@""
			   charactersIgnoringModifiers:@""
								 isARepeat:NO
								   keyCode:-1]];
}

// Version browser

- (NSSize)window:(NSWindow *)window willResizeForVersionBrowserWithMaxPreferredSize:(NSSize)maxPreferredFrameSize
  maxAllowedSize:(NSSize)maxAllowedFrameSize
{
	NSSize size = self.display.size;

	if (size.width && size.height)
	{
		CGFloat r = MIN(maxPreferredFrameSize.width/size.width, maxPreferredFrameSize.height/size.height);
		size.height = size.height*r + self.window.frame.size.height - self.display.frame.size.height;
		size.width *= r;
		return size;
	}
	else
	{
		return maxPreferredFrameSize;
	}
}

- (void)windowWillEnterVersionBrowser:(NSNotification *)notification
{
	vbFrame = self.window.frame;
	constraint.constant = 0;
	vbScale = scale;
}

- (void)windowDidExitVersionBrowser:(NSNotification *)notification
{
	constraint.constant = hideStatusLine ? 0 : 22;
	[self.window setFrame:vbFrame display:FALSE];
	scale = vbScale;

	[self performSelectorOnMainThread:@selector(resize)
						   withObject:nil
						waitUntilDone:FALSE];
}

// Создавать undo при работе с клавиатурой

- (void)keyDown:(NSEvent *)theEvent
{
	if ((theEvent.modifierFlags & NSCommandKeyMask) == 0 && !theEvent.isARepeat)
	{
		if (theEvent.characters.length != 0)
		{
			unichar ch = [theEvent.characters characterAtIndex:0];

			if (ch == 0x09 || (ch >= 0x20 && ch < 0x7F) || (ch >= 0x410 && ch <= 0x44F))
				ch = 'A';

			if (ch == 0x0D || ch != lastUndoChar)
				[self.document registerUndo:@"Набор на клавиатуре"];

			lastUndoChar = ch;
		}
	}

	[super keyDown:theEvent];
}

#ifdef DEBUG
- (void)dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
