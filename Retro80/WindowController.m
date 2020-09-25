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
	unichar lastUndoChar;

	IBOutlet NSLayoutConstraint *constraint;
	bool hideStatusLine;

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

    if ((self.display.nextResponder = self.sound) == nil)
        self.display.nextResponder = self.debug;
    else
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
	scale = 2;

	if (self.document.inViewingMode)
		constraint.constant = 0;

	[self startComputer];
}

// Автоматический останов компьютера при закрытии окна

- (void)windowWillClose:(NSNotification *)notification
{
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
			menuItem.state = NO;
			return NO;
		}

		NSSize size = self.display.size;

		if (scale && menuItem.tag == scale)
			menuItem.state = size.width*scale == self.display.frame.size.width
				&& size.height*scale == self.display.frame.size.height;
		else
			menuItem.state = NO;

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

	return NO;
}

// Обработка наличия строки состояния

- (IBAction)statusLine:(NSMenuItem *)sender
{
	if ((self.window.styleMask & NSWindowStyleMaskFullScreen) == 0)
	{
		NSRect frame = self.window.frame;

		if ((hideStatusLine = !hideStatusLine))
		{
				frame.size.height -= 22;
				frame.origin.y += 22;

				[self.window setFrame:frame display:NO];
				constraint.constant = 0;
		}
		else
		{
			frame.size.height += 22;
			frame.origin.y -= 22;

			[self.window setFrame:frame display:NO];
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

				[self.window setFrame:frame display:YES];
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
	[super keyUp:[NSEvent keyEventWithType:NSKeyUp
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
	[self.window setFrame:vbFrame display:NO];
	scale = vbScale;

	[self performSelectorOnMainThread:@selector(resize)
						   withObject:nil
						waitUntilDone:NO];
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

#ifdef GNUSTEP

- (void)windowDidResize:(NSNotification *)notification
{
    NSSize size = [self.window contentRectForFrameRect:self.window.frame].size;

    if(!hideStatusLine)
    {
        [self.display setFrame:NSMakeRect(0, 22, size.width, size.height - 22)];
        [self.display.digit6 setFrameOrigin:NSMakePoint(size.width - 20, 0)];
        [self.display.digit5 setFrameOrigin:NSMakePoint(size.width - 33, 0)];
        [self.display.digit4 setFrameOrigin:NSMakePoint(size.width - 59, 0)];
        [self.display.digit3 setFrameOrigin:NSMakePoint(size.width - 72, 0)];
        [self.display.digit2 setFrameOrigin:NSMakePoint(size.width - 85, 0)];
        [self.display.digit1 setFrameOrigin:NSMakePoint(size.width - 98, 0)];
    }
    else
    {
        [self.display setFrame:NSMakeRect(0.0, 0.0, size.width, size.height)];
    }
}

- (void)awakeFromNib
{
    self.sound = nil;
}

#endif

#ifdef DEBUG
- (void)dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
