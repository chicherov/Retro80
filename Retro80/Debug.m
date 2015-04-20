#import "Debug.h"

@implementation Debug
{
	NSObject<Debug> *debugger;
	NSRange range;
}

- (void) windowWillClose:(NSNotification *)notification
{
	[NSApp stopModal];
}

- (void) run:(NSObject<Debug>*)debug
{
	NSString *out = [debug debugCommand:nil];

	range.length = self.textView.textStorage.length - range.location;
	[self.textView replaceCharactersInRange:range withString:out];
	range.length = out.length; [self.textView scrollRangeToVisible:range];
	range.location += range.length;

	if (range.location > 2000000)
	{
		NSUInteger cut = NSMaxRange([self.textView.string lineRangeForRange:NSMakeRange(range.location - 1000000, 0)]);
		[self.textView replaceCharactersInRange:NSMakeRange(0, cut) withString:@""];
		range.location = self.textView.textStorage.length;
	}

	debugger = debug;
	[self.panel setIsVisible:TRUE];
	[NSApp runModalForWindow:self.panel];
	debugger = nil;;
}

- (BOOL) textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	if (debugger != nil && replacementString != nil && affectedCharRange.location >= range.location)
		return TRUE;

//	range.length = self.textView.textStorage.length - range.location;
//	textView.selectedRange = NSMakeRange(NSMaxRange(range), 0);
//	[textView scrollRangeToVisible:range];
	return FALSE;
}

- (void) textDidChange:(NSNotification *)notification
{
	range.length = self.textView.textStorage.length - range.location;

	NSString *string = [self.textView.textStorage attributedSubstringFromRange:range].string.uppercaseString;

	NSUInteger lf = [string rangeOfString:@"\n"].location; if (lf != NSNotFound)
	{
		[self.textView replaceCharactersInRange:range
									 withString:[string substringToIndex:lf + 1]];

		range.location += lf + 1;

		if ((string = [debugger debugCommand:[string substringToIndex:lf]]) == nil)
		{
			[self.panel setIsVisible:FALSE];
			[NSApp stopModal];
		}
		else
		{
			range.length = 0;

			[self.textView replaceCharactersInRange:range
										 withString:string];

			range.location += string.length;
		}
	}
	else
	{
		NSRange selectedRange = self.textView.selectedRange;

		[self.textView replaceCharactersInRange:range
									 withString:string];

		self.textView.selectedRange = selectedRange;
	}
}

- (NSRange) textView:(NSTextView *)textView willChangeSelectionFromCharacterRange:(NSRange)oldSelectedCharRange toCharacterRange:(NSRange)newSelectedCharRange
{
	if (newSelectedCharRange.location < range.location && newSelectedCharRange.length == 0)
	{
		if (oldSelectedCharRange.location < range.location)
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

- (void) awakeFromNib
{
	[self.textView setFont:[NSFont fontWithName:@"Monaco" size:16]];
}

@end
