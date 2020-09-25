/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Панель отладчика

 *****/

#import "Debug.h"

@implementation Debug
{
	IBOutlet NSTextView *textView;
	IBOutlet NSPanel *panel;

	NSMutableString *buffer;
	NSUInteger fence;
}

- (void)print:(NSString *)format, ...
{
	va_list va; va_start(va, format);

	if (buffer)
		[buffer appendString:[[NSString alloc] initWithFormat:format arguments:va]];
	else
		buffer = [[NSMutableString alloc] initWithFormat:format arguments:va];

	va_end(va);
}

- (void)flush
{
	[textView replaceCharactersInRange:NSMakeRange(fence, textView.textStorage.length - fence) withString:buffer];
    [textView scrollRangeToVisible: [textView selectedRange]];
	buffer = nil; fence = textView.textStorage.length;

	if (fence > 2000000)
	{
		NSUInteger cut = NSMaxRange([textView.string lineRangeForRange:NSMakeRange(fence - 1000000, 0)]);
		[textView replaceCharactersInRange:NSMakeRange(0, cut) withString:@""];
		fence = textView.textStorage.length;
	}
}

- (void)clear
{
	[textView replaceCharactersInRange:NSMakeRange(fence = 0, textView.textStorage.length) withString:@""];
}

// ---------------------------------------------------------------------------------------------------------------------

- (void)run
{
	[NSApp runModalForWindow:panel];
}

- (void)windowWillClose:(NSNotification *)notification
{
	fence = [textView.string lineRangeForRange:NSMakeRange(fence, 0)].location;

	[textView replaceCharactersInRange:NSMakeRange(fence, textView.textStorage.length - fence) withString:@""];

	[NSApp stopModal];
}

- (NSRange)textView:(NSTextView *)view willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange
{
	if (newSelectedCharRange.location < fence && newSelectedCharRange.length == 0)
	{
		if (oldSelectedCharRange.location < fence)
		{
			oldSelectedCharRange.location = view.textStorage.length;
			oldSelectedCharRange.length = 0;
		}

		[view scrollRangeToVisible:oldSelectedCharRange];
		return oldSelectedCharRange;
	}
	else
	{
		return newSelectedCharRange;
	}
}

- (BOOL)textView:(NSTextView *)view shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	return replacementString != nil && affectedCharRange.location >= fence;
}

- (void)textDidChange:(NSNotification *)notification
{
	NSString *string = [textView.textStorage attributedSubstringFromRange:NSMakeRange(fence, textView.textStorage.length - fence)].string;
	NSArray<NSString *> *array = [string componentsSeparatedByString:@"\n"];

	if ([string rangeOfString:@"."].location != NSNotFound || array.count > 1)
	{
		string = array.count == 1 ? array.firstObject : [array.firstObject stringByAppendingString:array[1]];

		[textView replaceCharactersInRange:NSMakeRange(fence, textView.textStorage.length - fence)
								withString:[string stringByAppendingString:@"\n"]];

		fence = textView.textStorage.length;

		if ([self.delegate Debugger:array.count == 1 ? @"." : string])
		{
			[panel setIsVisible:NO];
			[NSApp stopModal];
		}
		else
		{
			[self flush];
		}
	}
}

#ifdef GNUSTEP

- (void)windowDidResize:(NSNotification *)notification
{
    NSSize size = [panel contentRectForFrameRect:panel.frame].size;
    [textView.superview.superview setFrame:NSMakeRect(0.0, 0.0, size.width, size.height)];
}

#endif

// ---------------------------------------------------------------------------------------------------------------------

- (void)awakeFromNib
{
	[panel setBackgroundColor:[NSColor colorWithCalibratedWhite:1.0 alpha:0.0]];
	[panel setOpaque:NO];

	[textView setFont:[NSFont fontWithName:@"Monaco" size:16]];
}

// ---------------------------------------------------------------------------------------------------------------------
// DEBUG: dealloc
// ---------------------------------------------------------------------------------------------------------------------

#ifdef DEBUG
- (void)dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
