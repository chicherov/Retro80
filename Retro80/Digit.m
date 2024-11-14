/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 LCD цифра

 *****/

#import "Digit.h"

@implementation Digit
{
	uint8_t segments;
}

- (uint8_t)segments
{
	return segments;
}

- (void)setSegments:(uint8_t)value
{
	if (segments != value)
	{
		segments = value; self.needsDisplay = YES;
	}
}

static NSImage *image;

#ifdef GNUSTEP
const NSCompositingOperation NSCompositingOperationSourceOver = NSCompositeSourceOver;
#endif

- (void)drawRect:(NSRect)rect
{
	if (image == nil)
		image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"digits"
																						ofType:@"png"]];

	[image drawInRect:rect
			 fromRect:NSMakeRect((segments & 15)*60, (~(segments >> 4) & 7)*100, 60, 100)
			operation:NSCompositingOperationSourceOver
			 fraction:1.0
	];
}

@end
