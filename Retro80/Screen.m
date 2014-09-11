#import "Retro80.h"
#import "Screen.h"

@implementation Screen
{
	NSMutableData *data;
	NSInteger scale;

	NSPoint mark;
	BOOL isMark;
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(zoom:))
	{
		menuItem.state = FALSE;

		if (self.window.styleMask & NSFullScreenWindowMask)
			return NO;

		if (scale && menuItem.tag == scale)
		{
			if (graphics.width * scale == self.frame.size.width && graphics.height * scale == self.frame.size.height)
				menuItem.state = YES;
		}

		return YES;
	}

	if (menuItem.action == @selector(selectAll:))
	{
		return TRUE;
	}

	if (menuItem.action == @selector(copy:))
	{
		return isSelected;
	}

	return NO;
}

// -----------------------------------------------------------------------------
// zoom
// -----------------------------------------------------------------------------

- (IBAction) zoom:(NSMenuItem *)sender
{
	CGFloat addHeight = self.window.frame.size.height - self.frame.size.height;

	if (sender != nil && sender.tag >= 1 && sender.tag <= 9)
		scale = sender.tag;

	if (data != nil && scale >= 1 && scale <= 9)
	{
		NSRect frame = self.window.frame; frame.origin.y += frame.size.height;

		frame.size.height = graphics.height * scale + addHeight;
		frame.size.width = graphics.width * scale;
		frame.origin.y -= frame.size.height;

		if (!(self.window.styleMask & NSFullScreenWindowMask))
			[self.window setFrame:frame display:TRUE];

		[self.window setMinSize:NSMakeSize(graphics.width, graphics.height + addHeight)];
	}
}

// -----------------------------------------------------------------------------
// setupGraphics/setupText
// -----------------------------------------------------------------------------

- (void) setupGraphicsWidth:(NSUInteger)width height:(NSUInteger)height
{
	if (data == nil || graphics.width != width || graphics.height != height)
	{
		bitmap = (data = [NSMutableData dataWithLength:width * height * 4]).mutableBytes;
		graphics.width = width; graphics.height = height;

		[self performSelectorOnMainThread:@selector(zoom:)
							   withObject:nil
							waitUntilDone:FALSE];
	}

	isSelected = FALSE;
	isText = FALSE;
}

- (void) setupTextWidth:(NSUInteger)width height:(NSUInteger)height cx:(NSUInteger)cx cy:(NSUInteger)cy
{
	if (data == nil || graphics.width != width * cx || graphics.height != height * cy)
	{
		bitmap = (data = [NSMutableData dataWithLength:(width * cx) * (height * cy) * 4]).mutableBytes;
		graphics.width = width * cx; graphics.height = height * cy;

		[self performSelectorOnMainThread:@selector(zoom:)
							   withObject:nil
							waitUntilDone:FALSE];
	}

	text.height = height;
	text.width = width;
	isSelected = FALSE;
	isText = TRUE;
}

// -----------------------------------------------------------------------------
// drawRect
// -----------------------------------------------------------------------------

- (void) drawRect:(NSRect)rect
{
	NSRect backingBounds = [self convertRectToBacking:[self bounds]];
	GLsizei backingPixelWidth  = (GLsizei)(backingBounds.size.width),
	backingPixelHeight = (GLsizei)(backingBounds.size.height);
	glViewport(0, 0, backingPixelWidth, backingPixelHeight);

	glEnable(GL_TEXTURE_2D);

	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)graphics.width, (GLsizei)graphics.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, bitmap);

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

	glBegin(GL_QUADS);
	glTexCoord2f(0.0, 0.0); glVertex2f(-1.0,  1.0);
	glTexCoord2f(1.0, 0.0); glVertex2f( 1.0,  1.0);
	glTexCoord2f(1.0, 1.0); glVertex2f( 1.0, -1.0);
	glTexCoord2f(0.0, 1.0); glVertex2f(-1.0, -1.0);
	glEnd();

	glDisable(GL_TEXTURE_2D);
	glFlush();
}

// -----------------------------------------------------------------------------
// Выделить весь текст
// -----------------------------------------------------------------------------

- (IBAction) selectAll:(id)sender
{
	@synchronized(self)
	{
		if (isText)
		{
			selected.origin = NSZeroPoint;
			selected.size = text;
			isSelected = TRUE;
		}
	}
}

// -----------------------------------------------------------------------------
// Выделение мышкой
// -----------------------------------------------------------------------------

BOOL isAlphaNumber(uint8_t byte)
{
	return (byte >= '0' && byte <= '9') || (byte >= 'A' && byte <= 'Z') || (byte >= 0x60 && byte <= 0x7E);
}

- (void) mouseDown:(NSEvent *)theEvent
{
	@synchronized(self)
	{
		isSelected = FALSE;

		if (isText)
		{
			NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];

			mark.y = trunc(text.height - point.y / self.frame.size.height * text.height);
			mark.x = trunc(point.x / self.frame.size.width * text.width);
			isMark = TRUE;

			if (theEvent.clickCount == 2 && isAlphaNumber([self byteAtX:mark.x y:mark.y]))
			{
				selected.size.height = 1;
				selected.size.width = 1;

				selected.origin = mark;
				isSelected = TRUE;

				while (selected.origin.x + selected.size.width < text.width && isAlphaNumber([self byteAtX:selected.origin.x + selected.size.width y:selected.origin.y]))
				{
					selected.size.width += 1;
				}

				while (selected.origin.x >= 1 && isAlphaNumber([self byteAtX:selected.origin.x - 1 y:selected.origin.y]))
				{
					selected.origin.x -= 1; selected.size.width += 1;
				}

				mark = selected.origin;
			}
		}
	}
}

// -----------------------------------------------------------------------------

- (void) mouseUp:(NSEvent *)theEvent
{
	isMark = FALSE;
}

// -----------------------------------------------------------------------------

- (void) mouseDragged:(NSEvent *)theEvent
{
	if (isMark)
	{
		@synchronized(self)
		{
			NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];

			point.y = trunc(text.height - point.y / self.frame.size.height * text.height);
			point.x = trunc(point.x / self.frame.size.width * text.width);

			if (point.y < text.height && point.x < text.width)
			{
				if (point.y < mark.y)
				{
					selected.origin.y = point.y; selected.size.height = mark.y - point.y + 1;
				}
				else
				{
					selected.origin.y = mark.y; selected.size.height = point.y - mark.y + 1;
				}

				if (point.x < mark.x)
				{
					selected.origin.x = point.x; selected.size.width = mark.x - point.x + 1;
				}
				else
				{
					selected.origin.x = mark.x; selected.size.width = point.x - mark.x + 1;
				}

				isSelected = TRUE;
			}
		}
	}
}

// -----------------------------------------------------------------------------
// copy/paste
// -----------------------------------------------------------------------------

- (uint8_t) byteAtX:(NSUInteger)x y:(NSUInteger)y
{
	return 0;
}

- (IBAction) copy:(id)sender
{
	@synchronized(self)
	{
		if (isSelected)
		{
			if (isText)
			{
				NSMutableData *buffer = [NSMutableData dataWithLength:selected.size.height * (selected.size.width + 1)];

				uint8_t *buf = buffer.mutableBytes;
				uint8_t *ptr = buf;

				for (unsigned y = selected.origin.y; y < selected.origin.y + selected.size.height; y++)
				{
					for (unsigned x = selected.origin.x; x < selected.origin.x + selected.size.width; x++)
					{
						if ((*ptr = [self byteAtX:x y:y]) < 0x20 || *ptr > 0x80) *ptr = 0x20;
						else if (*ptr >= 0x60) *ptr |= 0x80;
						ptr++;
					}

					if (selected.size.height > 1)
					{
						while (ptr > buf && ptr[-1] == ' ')
							ptr--;

						*ptr++ = '\n';
					}
				}

				NSString *string = [[NSString alloc] initWithBytes:buf
															length:ptr - buf
														  encoding:(NSStringEncoding) 0x80000A02];

				NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
				[pasteBoard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
				[pasteBoard setString:string forType:NSPasteboardTypeString];

				isSelected = FALSE;
			}

			else
			{
				NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
				[pasteBoard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeTIFF] owner:nil];

				NSBitmapImageRep *image = [[NSBitmapImageRep alloc]
										   initWithBitmapDataPlanes:(uint8_t **)&bitmap
										   pixelsWide:graphics.width
										   pixelsHigh:graphics.height
										   bitsPerSample:8
										   samplesPerPixel:4
										   hasAlpha:YES
										   isPlanar:NO
										   colorSpaceName:NSDeviceRGBColorSpace
										   bitmapFormat:0
										   bytesPerRow:graphics.width * 4
										   bitsPerPixel:0];

				[pasteBoard setData:[image TIFFRepresentation]
							forType:NSPasteboardTypeTIFF];
			}
		}
	}
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		scale = 2;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		scale = [[NSUserDefaults standardUserDefaults]
				 integerForKey:@"scale"];
	}

	return self;
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
