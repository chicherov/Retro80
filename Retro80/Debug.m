#import "Debug.h"

@implementation Debug
{
	NSObject<Debug> *debugger;
	NSUInteger fence;
}

- (void) windowWillClose:(NSNotification *)notification
{
	[NSApp stopModal];
}

- (void) run:(NSObject<Debug>*)debug
{
	NSString *out = [debug debugCommand:nil];

	[self.textView replaceCharactersInRange:NSMakeRange(fence, self.textView.textStorage.length - fence) withString:out];
	[self.textView scrollRangeToVisible:NSMakeRange(fence, out.length)];
	fence += out.length;

	if (fence > 2000000)
	{
		NSUInteger cut = NSMaxRange([self.textView.string lineRangeForRange:NSMakeRange(fence - 1000000, 0)]);
		[self.textView replaceCharactersInRange:NSMakeRange(0, cut) withString:@""];
		self.textView.selectedRange = NSMakeRange(fence = self.textView.textStorage.length, 0);
	}

	debugger = debug;
	[self.panel setIsVisible:TRUE];
	[NSApp runModalForWindow:self.panel];
	debugger = nil;;
}

- (BOOL) textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	return debugger != nil && replacementString != nil && affectedCharRange.location >= fence;
}

- (void) textDidChange:(NSNotification *)notification
{
	NSString *string = [self.textView.textStorage attributedSubstringFromRange:NSMakeRange(fence, self.textView.textStorage.length - fence)].string.uppercaseString;

	NSRange range = [string rangeOfString:@"."];

	NSArray *array = [string componentsSeparatedByString:@"\n"]; if (range.location != NSNotFound || array.count > 1)
	{
		if (array.count == 2)
			string = [array[0] stringByAppendingString:array[1]];
		else
			string = array[0];

		[self.textView replaceCharactersInRange:NSMakeRange(fence, self.textView.textStorage.length - fence)
									 withString:[string stringByAppendingString:@"\n"]];

		fence += string.length + 1;

		if ((string = [debugger debugCommand:range.location != NSNotFound ? @"." : string]) == nil)
		{
			[self.panel setIsVisible:FALSE];
			[NSApp stopModal];
		}
		else
		{
			[self.textView replaceCharactersInRange:NSMakeRange(fence, 0)
										 withString:string];

			fence += string.length;
		}
	}
	else
	{
		NSRange selectedRange = self.textView.selectedRange;

		[self.textView replaceCharactersInRange:NSMakeRange(fence, self.textView.textStorage.length - fence)
									 withString:string];

		self.textView.selectedRange = selectedRange;
	}
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

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (void) awakeFromNib
{
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
