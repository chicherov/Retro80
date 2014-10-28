#import "Retro80.h"
#import "Display.h"

@implementation Display
{
	IBOutlet NSLayoutConstraint *constraint;

	BOOL hideStatusLine;
	NSInteger scale;

	NSTimer *timer;

	NSMutableData *data1;
	NSMutableData *data2;

	NSSize graphics;
	NSSize overlay;

	BOOL isSelected;
	NSRect selected;

	BOOL isText;
	NSSize text;

	NSPoint mark;
	BOOL isMark;
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(statusLine:))
	{
		menuItem.state = constraint.constant == 22;
		return (self.window.styleMask & NSFullScreenWindowMask) == 0;
	}

	if (menuItem.action == @selector(scale:))
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
		return isText && isSelected;
	}

	if (menuItem.action == @selector(paste:))
	{
		return self.kbd && [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString] != nil;
	}

	return NO;
}

// -----------------------------------------------------------------------------
// Обработка наличия строки состояния
// -----------------------------------------------------------------------------

- (IBAction) statusLine:(id)sender
{
	if ((self.window.styleMask & NSFullScreenWindowMask) == 0)
	{
		NSRect windowFrame = self.window.frame; if ((hideStatusLine = !hideStatusLine))
		{
			if (constraint.constant == 22)
			{
				windowFrame.size.height -= 22;
				windowFrame.origin.y += 22;

				[self.window setFrame:windowFrame display:FALSE];
				constraint.constant = 0;
			}
		}
		else if (constraint.constant == 0)
		{
			windowFrame.size.height += 22;
			windowFrame.origin.y -= 22;

			[self.window setFrame:windowFrame display:FALSE];
			constraint.constant = 22;
		}
	}
}

// -----------------------------------------------------------------------------
// Обработка FullScreen
// -----------------------------------------------------------------------------

- (void) mouseMoved:(NSEvent *)theEvent
{
	[timer invalidate];

	timer = [NSTimer scheduledTimerWithTimeInterval:2.0
											 target:self
										   selector:@selector(hideMouse)
										   userInfo:nil
											repeats:NO];
}

- (void) hideMouse
{
	[NSCursor setHiddenUntilMouseMoves:YES];
}

- (void) windowWillEnterFullScreen:(NSNotification *)notification
{
	[self mouseMoved:nil];
	[self.window setAcceptsMouseMovedEvents:YES];

	constraint.constant = 0;
}

- (void) windowWillExitFullScreen:(NSNotification *)notification
{
	constraint.constant = hideStatusLine ? 0 : 22;

	[self.window setAcceptsMouseMovedEvents:NO];
	[NSCursor setHiddenUntilMouseMoves:NO];
	[timer invalidate];
}

// -----------------------------------------------------------------------------
// Обработка масштабирования
// -----------------------------------------------------------------------------

- (IBAction) scale:(NSMenuItem *)sender
{
	if (sender != nil && sender.tag >= 1 && sender.tag <= 9)
		scale = sender.tag;

	if (data1 != nil && scale >= 1 && scale <= 9)
	{
		NSRect rect = self.window.frame; rect.origin.y += rect.size.height;
		CGFloat addHeight = rect.size.height - self.frame.size.height;
		
		rect.size.height = graphics.height * scale + addHeight;
		rect.size.width = graphics.width * scale;
		rect.origin.y -= rect.size.height;

		if (!(self.window.styleMask & NSFullScreenWindowMask))
			[self.window setFrame:rect display:TRUE];

		[self.window setMinSize:NSMakeSize(graphics.width, graphics.height + addHeight)];
	}
}

// -----------------------------------------------------------------------------
// Обработка фокуса приложения
// -----------------------------------------------------------------------------

- (void) windowDidBecomeKey:(NSNotification *)notification
{
	if (self.window.styleMask & NSFullScreenWindowMask)
		[self mouseMoved:nil];

	[self.kbd keyUp:nil];
}

- (void) windowWillClose:(NSNotification *)notification
{
	[[self.document.windowControllers firstObject] windowWillClose:notification];
}

// -----------------------------------------------------------------------------
// setupGraphics/setupText
// -----------------------------------------------------------------------------

- (uint32_t *) setupGraphicsWidth:(NSUInteger)width height:(NSUInteger)height
{
	if (data1 == nil || graphics.width != width || graphics.height != height)
	{
		data1 = [NSMutableData dataWithLength:width * height * 4];
		graphics.width = width; graphics.height = height;
		data2 = nil; overlay = NSZeroSize;

		[self performSelectorOnMainThread:@selector(scale:)
							   withObject:nil
							waitUntilDone:FALSE];
	}

	isSelected = FALSE; isText = FALSE;
	return data1.mutableBytes;
}

- (uint32_t *) setupOverlayWidth:(NSUInteger)width height:(NSUInteger)height
{
	if (data2 == nil || overlay.width != width || overlay.height != height)
	{
		data2 = [NSMutableData dataWithLength:width * height * 4];
		overlay.width = width; overlay.height = height;
	}

	return data2.mutableBytes;
}

- (uint32_t *) setupTextWidth:(NSUInteger)width height:(NSUInteger)height cx:(NSUInteger)cx cy:(NSUInteger)cy
{
	if (data1 == nil || graphics.width != width * cx || graphics.height != height * cy)
	{
		data1 = [NSMutableData dataWithLength:(width * cx) * (height * cy) * 4];
		graphics.width = width * cx; graphics.height = height * cy;
		data2 = nil; overlay = NSZeroSize;

		[self performSelectorOnMainThread:@selector(scale:)
							   withObject:nil
							waitUntilDone:FALSE];
	}

	text.height = height; text.width = width;
	isSelected = FALSE; isText = TRUE;
	return data1.mutableBytes;
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

	if (data1)
	{
		glEnable(GL_TEXTURE_2D);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)graphics.width, (GLsizei)graphics.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data1.bytes);

		glBegin(GL_QUADS);
		glTexCoord2f(0.0, 0.0); glVertex2f(-1.0,  1.0);
		glTexCoord2f(1.0, 0.0); glVertex2f( 1.0,  1.0);
		glTexCoord2f(1.0, 1.0); glVertex2f( 1.0, -1.0);
		glTexCoord2f(0.0, 1.0); glVertex2f(-1.0, -1.0);
		glEnd();

		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		if (data2)
		{
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)overlay.width, (GLsizei)overlay.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data2.bytes);

			glBegin(GL_QUADS);
			glTexCoord2f(0.0, 0.0); glVertex2f(-1.0,  1.0);
			glTexCoord2f(1.0, 0.0); glVertex2f( 1.0,  1.0);
			glTexCoord2f(1.0, 1.0); glVertex2f( 1.0, -1.0);
			glTexCoord2f(0.0, 1.0); glVertex2f(-1.0, -1.0);
			glEnd();

		}

		glDisable(GL_TEXTURE_2D);

		if (isSelected)
		{
			glBegin(GL_QUADS);
			glColor4f(1.0, 1.0, 1.0, 0.5);

			if (isText)
			{
				glVertex2f(selected.origin.x / text.width * 2 - 1, 1 - selected.origin.y / text.height * 2);
				glVertex2f((selected.origin.x + selected.size.width) / text.width * 2 - 1, 1 - selected.origin.y / text.height * 2);
				glVertex2f((selected.origin.x + selected.size.width) / text.width * 2 - 1, 1 - (selected.origin.y + selected.size.height) / text.height * 2);
				glVertex2f(selected.origin.x / text.width * 2 - 1, 1 - (selected.origin.y + selected.size.height) / text.height * 2);
			}
			else
			{
				glVertex2f(selected.origin.x / graphics.width * 2 - 1, 1 - selected.origin.y / graphics.height * 2);
				glVertex2f((selected.origin.x + selected.size.width) / graphics.width * 2 - 1, 1 - selected.origin.y / graphics.height * 2);
				glVertex2f((selected.origin.x + selected.size.width) / graphics.width * 2 - 1, 1 - (selected.origin.y + selected.size.height) / graphics.height * 2);
				glVertex2f(selected.origin.x / graphics.width * 2 - 1, 1 - (selected.origin.y + selected.size.height) / graphics.height * 2);
			}

			glColor4f(1.0, 1.0, 1.0, 1.0);
			glEnd();
		}
		
		glDisable(GL_BLEND);
	}
	else
	{
		glClear(GL_COLOR_BUFFER_BIT);
	}

	glFlush();
}

// -----------------------------------------------------------------------------
// Выделить весь текст
// -----------------------------------------------------------------------------

- (IBAction) selectAll:(id)sender
{
	@synchronized(self)
	{
		isSelected = TRUE;
		selected.origin = NSZeroPoint;
		selected.size = isText ? text : graphics;
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
		NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];
		NSSize size = isText ? text : graphics;

		mark.y = trunc(size.height - point.y / self.frame.size.height * size.height);
		mark.x = trunc(point.x / self.frame.size.width * size.width);

		isSelected = FALSE;
		isMark = TRUE;

		if (isText && theEvent.clickCount == 2 && isAlphaNumber([self.crt charAtX:mark.x Y:mark.y]))
		{
			selected.size.height = 1;
			selected.size.width = 1;

			selected.origin = mark;
			isSelected = TRUE;

			while (selected.origin.x + selected.size.width < text.width && isAlphaNumber([self.crt charAtX:selected.origin.x + selected.size.width Y:selected.origin.y]))
			{
				selected.size.width += 1;
			}

			while (selected.origin.x >= 1 && isAlphaNumber([self.crt charAtX:selected.origin.x - 1 Y:selected.origin.y]))
			{
				selected.origin.x -= 1; selected.size.width += 1;
			}

			mark = selected.origin;
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
			NSSize size = isText ? text : graphics;

			point.y = trunc(size.height - point.y / self.frame.size.height * size.height);
			point.x = trunc(point.x / self.frame.size.width * size.width);

			if (point.y < size.height && point.x < size.width)
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
						if ((*ptr = [self.crt charAtX:x Y:y]) < 0x20 || *ptr > 0x80) *ptr = 0x20;
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

				uint8_t *bytes = data1.mutableBytes;

				NSBitmapImageRep *image = [[NSBitmapImageRep alloc]
										   initWithBitmapDataPlanes:&bytes
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
// События клавиатуры
// -----------------------------------------------------------------------------

- (void) flagsChanged:(NSEvent*)theEvent
{
	[self.kbd flagsChanged:theEvent];
}

- (void) keyDown:(NSEvent*)theEvent
{
	if ((theEvent.modifierFlags & NSCommandKeyMask) == 0 && theEvent.characters.length != 0)
	{
		NSString *typing = NSLocalizedString(@"Набор на клавиатуре", "Typing");
		unichar ch = [theEvent.characters characterAtIndex:0];

		if (ch == 0x09 || (ch >= 0x20 && ch < 0x7F) || (ch >= 0x410 && ch <= 0x44F))
			[self.document registerUndoWitString:typing type:1];
		else if (ch == 0xF700 || ch == 0xF701 || ch == 0xF702 || ch == 0xF703)
			[self.document registerUndoWitString:typing type:2];
		else if (ch == 0x7F)
			[self.document registerUndoWitString:typing type:3];
		else if (ch == 0x0D)
			[self.document registerUndoWitString:typing type:4];
		else
			[self.document registerUndoWitString:typing type:5];
	}

	[self.kbd keyDown:theEvent];
	//	isSelected = FALSE;
}

- (void) keyUp:(NSEvent*)theEvent
{
	[self.kbd keyUp:theEvent];
}

- (IBAction) paste:(NSMenuItem *)menuItem
{
	[self.document registerUndoWithMenuItem:menuItem];
	[self.kbd paste:[[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString]];
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (void) awakeFromNib
{
	scale = 2;
}

@end
