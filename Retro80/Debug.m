/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 *****/

#import "Retro80.h"
#import "Debug.h"

@implementation Debug
{
	NSObject<Debug> *debugger;

	NSMutableString *buffer;
	NSUInteger fence;
}

- (void) print:(NSString *)format, ...
{
	va_list va; va_start(va, format);

	if (buffer)
		[buffer appendString: [[NSString alloc] initWithFormat:format arguments:va]];
	else
		buffer = [[NSMutableString alloc] initWithFormat:format arguments:va];

	va_end(va);
}

- (void) flush
{
	[self.textView replaceCharactersInRange:NSMakeRange(fence, self.textView.textStorage.length - fence) withString:buffer];
	[self.textView scrollRangeToVisible:NSMakeRange(fence, buffer.length)]; buffer = nil;
	fence = self.textView.textStorage.length;

	if (fence > 2000000)
	{
		NSUInteger cut = NSMaxRange([self.textView.string lineRangeForRange:NSMakeRange(fence - 1000000, 0)]);
		[self.textView replaceCharactersInRange:NSMakeRange(0, cut) withString:@""];
		fence = self.textView.textStorage.length;
	}
}

- (void) clear
{
	[self.textView replaceCharactersInRange:NSMakeRange(fence = 0, self.textView.textStorage.length) withString:@""];
}

// -----------------------------------------------------------------------------
// Вызов отладчика
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(debug:))
		return self.document.sound.debug == FALSE && [self.document.computer.cpu respondsToSelector:@selector(debug)];

	return NO;
}

- (IBAction) debug:(id)sender
{
	@synchronized(self.document.computer.cpu)
	{
		self.document.sound.debug = TRUE;
	}

	if (debugger || (debugger = [self.document.computer.cpu debug]))
	{
		[debugger attach:self.document.computer.cpu debug:self];
		[NSApp runModalForWindow:self.panel];
	}

	self.document.sound.debug = FALSE;
}


- (void) windowWillClose:(NSNotification *)notification
{
	fence = [self.textView.string lineRangeForRange:NSMakeRange(fence, 0)].location;

	[self.textView replaceCharactersInRange:NSMakeRange(fence, self.textView.textStorage.length - fence)
								 withString:@""];

	[NSApp stopModal];
}

- (NSRange) textView:(NSTextView *)textView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange
{
	if (newSelectedCharRange.location < fence && newSelectedCharRange.length == 0)
	{
		if (oldSelectedCharRange.location < fence)
		{
			oldSelectedCharRange.location = textView.textStorage.length;
			oldSelectedCharRange.length = 0;
		}

		[textView scrollRangeToVisible:oldSelectedCharRange];
		return oldSelectedCharRange;
	}
	else
	{
		return newSelectedCharRange;
	}
}

- (BOOL) textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	return self.document.sound.debug && replacementString != nil && affectedCharRange.location >= fence;
}

- (void) textDidChange:(NSNotification *)notification
{
	NSString *string = [self.textView.textStorage attributedSubstringFromRange:NSMakeRange(fence, self.textView.textStorage.length - fence)].string;

	NSArray *array = [string componentsSeparatedByString:@"\n"]; if ([string rangeOfString:@"."].location != NSNotFound || array.count > 1)
	{
		string = array.count == 1 ? array[0] : [array[0] stringByAppendingString:array[1]];

		[self.textView replaceCharactersInRange:NSMakeRange(fence, self.textView.textStorage.length - fence)
									 withString:[string stringByAppendingString:@"\n"]];

		fence = self.textView.textStorage.length;

		if ([debugger Debugger:array.count == 1 ? @"." : string])
		{
			[self.panel setIsVisible:FALSE];
			[NSApp stopModal];
		}

		else
		{
			[self flush];
		}
	}
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (void) awakeFromNib
{
	[self.panel setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.0]];
	[self.panel setOpaque:NO];

	[self.textView setFont:[NSFont fontWithName:@"Monaco" size:16]];
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
