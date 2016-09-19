/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 *****/

#import "Retro80.h"
#import "Display.h"

// -----------------------------------------------------------------------------
// LCD цифра
// -----------------------------------------------------------------------------

@implementation Digit
{
	uint8_t segments;
}

- (uint8_t) segments
{
	return segments;
}

- (void) setSegments:(uint8_t)value
{
	if (segments != value)
	{
		self.needsDisplay = TRUE;
		segments = value;
	}
}

NSImage *image;

- (void) drawRect:(NSRect)rect
{
	if (image == nil)
		image = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"digits" ofType:@"png"]];

	[image drawInRect:rect
			 fromRect:NSMakeRect((segments & 15) * 60, (~(segments >> 4) & 7) * 100, 60, 100)
			operation:NSCompositeSourceOver
			 fraction: 1.0
	 ];
}

@end

// -----------------------------------------------------------------------------
// Display - Экран компьютера
// -----------------------------------------------------------------------------

@implementation Display
{
	IBOutlet NSLayoutConstraint *constraint;

	BOOL hideStatusLine;
	NSInteger scale;

	NSInteger vbScale;
	NSRect vbRect;

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

	unsigned blank;
	unsigned mode;

	BOOL gigaScreen;
	BOOL grayscale;
	BOOL tvnoise;

	GLuint shaderProgram;
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

		if (menuItem.tag)
		{
			if (self.window.screen.frame.size.height < graphics.height * menuItem.tag + self.window.frame.size.height - self.frame.size.height)
				return NO;

			if (self.window.screen.frame.size.width < graphics.width * menuItem.tag)
				return NO;
		}

		return YES;
	}

	if (menuItem.action == @selector(selectAll:))
	{
		return data1 != NULL;
	}

	if (menuItem.action == @selector(copy:))
	{
		return isSelected;
	}

	if (menuItem.action == @selector(paste:))
	{
		return self.kbd && [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString] != nil;
	}

	if (menuItem.action == @selector(gigaScreen:))
	{
		if (menuItem.tag)
		{
			menuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"gigaScreen"];
			return YES;
		}

		if (graphics.width == overlay.width && graphics.height == overlay.height)
		{
			menuItem.state = gigaScreen;
			return YES;
		}

		return menuItem.state = NO;
	}

	if (menuItem.action == @selector(grayscale:))
	{
		if (menuItem.tag)
			menuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"grayscale"];
		else
			menuItem.state = grayscale;

		return YES;
	}

	if (menuItem.action == @selector(tvnoise:))
	{
		if (menuItem.tag)
		{
			menuItem.state = [[NSUserDefaults standardUserDefaults] boolForKey:@"tvnoise"];
			return YES;
		}
		else
		{
			menuItem.state = tvnoise && shaderProgram != 0;
			return shaderProgram != 0;
		}
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

- (void) hideMouse
{
	[NSCursor setHiddenUntilMouseMoves:YES];
}

- (void) windowWillEnterFullScreen:(NSNotification *)notification
{
	timer = [NSTimer scheduledTimerWithTimeInterval:2.0
											 target:self
										   selector:@selector(hideMouse)
										   userInfo:nil
											repeats:NO];

	[self.window setAcceptsMouseMovedEvents:YES];
	constraint.constant = 0;
}

- (void) mouseMoved:(NSEvent *)theEvent
{
	timer = [NSTimer scheduledTimerWithTimeInterval:2.0
											 target:self
										   selector:@selector(hideMouse)
										   userInfo:nil
											repeats:NO];
}

- (void) windowWillExitFullScreen:(NSNotification *)notification
{
	constraint.constant = hideStatusLine ? 0 : 22;

	[self.window setAcceptsMouseMovedEvents:NO];
	[NSCursor setHiddenUntilMouseMoves:NO];
	[timer invalidate];
}

- (void) windowDidExitFullScreen:(NSNotification *)notification
{
	[self performSelectorOnMainThread:@selector(scale:)
						   withObject:nil
						waitUntilDone:FALSE];
}

// -----------------------------------------------------------------------------
// Version browser
// -----------------------------------------------------------------------------

- (NSSize)window:(NSWindow *)window willResizeForVersionBrowserWithMaxPreferredSize:(NSSize)maxPreferredFrameSize maxAllowedSize:(NSSize)maxAllowedFrameSize
{
	float r1 = maxPreferredFrameSize.height / graphics.height;
	float r2 = maxPreferredFrameSize.width / graphics.width;

	NSSize size; size.width = graphics.width * (r1 < r2 ? r1 : r2); size.height = graphics.height * (r1 < r2 ? r1 : r2);
	size.height += self.window.frame.size.height - self.frame.size.height - constraint.constant;

	return size;
}

- (void)windowWillEnterVersionBrowser:(NSNotification *)notification
{
	vbRect = self.window.frame; vbScale = scale;
	constraint.constant = 0;
}

- (void)windowDidExitVersionBrowser:(NSNotification *)notification
{
	constraint.constant = hideStatusLine ? 0 : 22;

	scale = vbScale; if (data1 != nil && scale >= 0 && scale <= 9)
	{
		CGFloat addHeight = self.window.frame.size.height - self.frame.size.height + constraint.constant;

		if (scale)
		{
			vbRect.origin.y += vbRect.size.height;
			vbRect.size.height = graphics.height * scale + addHeight;
			vbRect.size.width = graphics.width * scale;
			vbRect.origin.y -= vbRect.size.height;
		}

		[self.window setMinSize:NSMakeSize(graphics.width, graphics.height + addHeight)];
	}

	[self.window setFrame:vbRect display:TRUE];
}

// -----------------------------------------------------------------------------
// Обработка масштабирования
// -----------------------------------------------------------------------------

- (IBAction) scale:(NSMenuItem *)sender
{
	if (self.document.inViewingMode)
		return;
	
	if (sender != nil && sender.tag >= 1 && sender.tag <= 9)
		scale = sender.tag;

	if (data1 != nil && scale >= 0 && scale <= 9)
	{
		NSRect rect = self.window.frame; rect.origin.y += rect.size.height;
		CGFloat addHeight = rect.size.height - self.frame.size.height;

		rect.size.height = graphics.height * scale + addHeight;
		rect.size.width = graphics.width * scale;
		rect.origin.y -= rect.size.height;

		if (scale && !(self.window.styleMask & NSFullScreenWindowMask))
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
	{
		timer = [NSTimer scheduledTimerWithTimeInterval:2.0
												 target:self
											   selector:@selector(hideMouse)
											   userInfo:nil
												repeats:NO];
	}

	[self.kbd keyUp:nil];
}

- (void) windowDidResignKey:(NSNotification *)notification
{
	[self.kbd keyUp:nil];
}

- (void) windowWillClose:(NSNotification *)notification
{
	[[self.document.windowControllers firstObject] windowWillClose:notification];
}

// -----------------------------------------------------------------------------
// Реежим gigascreen
// -----------------------------------------------------------------------------

- (IBAction)gigaScreen:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		if (menuItem.tag)
			[NSUserDefaults.standardUserDefaults setBool:gigaScreen = ![NSUserDefaults.standardUserDefaults boolForKey:@"gigaScreen"] forKey:@"gigaScreen"];
		else
			gigaScreen = !gigaScreen;
	}
}

// -----------------------------------------------------------------------------
// Черно-белый режим
// -----------------------------------------------------------------------------

- (IBAction)grayscale:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		if (menuItem.tag)
			[NSUserDefaults.standardUserDefaults setBool:grayscale = ![NSUserDefaults.standardUserDefaults boolForKey:@"grayscale"] forKey:@"grayscale"];
		else
			grayscale = !grayscale;
	}
}

// -----------------------------------------------------------------------------
// Режим «старый телевизор»
// -----------------------------------------------------------------------------

- (IBAction)tvnoise:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		if (menuItem.tag)
			[NSUserDefaults.standardUserDefaults setBool:tvnoise = ![NSUserDefaults.standardUserDefaults boolForKey:@"tvnoise"] forKey:@"tvnoise"];
		else
			tvnoise = !tvnoise;
	}
}

// -----------------------------------------------------------------------------
// setupGraphics/setupText
// -----------------------------------------------------------------------------

- (uint32_t *) setupGraphicsWidth:(NSUInteger)width height:(NSUInteger)height
{
	@synchronized(self)
	{
		if (data1 && scale && (self.window.styleMask & NSFullScreenWindowMask) == 0)
			if (self.frame.size.width != graphics.width * scale || self.frame.size.height != graphics.height * scale)
				scale = 0;

		data1 = [NSMutableData dataWithLength:width * height * 4];
		graphics.width = width; graphics.height = height;
		data2 = nil; overlay = NSZeroSize;

		[self performSelectorOnMainThread:@selector(scale:)
							   withObject:nil
							waitUntilDone:FALSE];

		isSelected = FALSE; isText = FALSE;
		return data1.mutableBytes;
	}
}

- (uint32_t *) setupOverlayWidth:(NSUInteger)width height:(NSUInteger)height
{
	@synchronized(self)
	{
		data2 = [NSMutableData dataWithLength:width * height * 4];
		overlay.width = width; overlay.height = height;
		return data2.mutableBytes;
	}
}

- (uint32_t *) setupTextWidth:(NSUInteger)width height:(NSUInteger)height cx:(NSUInteger)cx cy:(NSUInteger)cy
{
	@synchronized(self)
	{
		if (data1 && scale && (self.window.styleMask & NSFullScreenWindowMask) == 0)
			if (self.frame.size.width != graphics.width * scale || self.frame.size.height != graphics.height * scale)
				scale = 0;

		data1 = [NSMutableData dataWithLength:(width * cx) * (height * cy) * 4];
		graphics.width = width * cx; graphics.height = height * cy;
		data2 = nil; overlay = NSZeroSize;

		[self performSelectorOnMainThread:@selector(scale:)
							   withObject:nil
							waitUntilDone:FALSE];

		text.height = height; text.width = width;
		isSelected = FALSE; isText = TRUE;
		return data1.mutableBytes;
	}
}

- (void) blank
{
	blank = 3; self.needsDisplay = TRUE;
}

// -----------------------------------------------------------------------------
// draw
// -----------------------------------------------------------------------------

- (void) draw:(BOOL)page
{
	if (page)
	{
		if (data2 && (gigaScreen || graphics.width != overlay.width || graphics.height != overlay.height))
		{
			mode = 3; self.needsDisplay = TRUE;
		}
		else
		{
			mode = 1; self.needsDisplay = TRUE;
		}
	}
	else if (!gigaScreen)
	{
		mode = 2; self.needsDisplay = TRUE;
	}
}

// -----------------------------------------------------------------------------
// drawRect
// -----------------------------------------------------------------------------

- (void) drawRect:(NSRect)rect
{
	@synchronized(self)
	{
		NSRect backingBounds = [self convertRectToBacking:[self bounds]];
		GLsizei backingPixelWidth  = (GLsizei)(backingBounds.size.width),
		backingPixelHeight = (GLsizei)(backingBounds.size.height);
		glViewport(0, 0, backingPixelWidth, backingPixelHeight);

		if (!blank && ((mode & 1) == 0 || data1) && ((mode & 2) == 0 || data2))
		{
			if (grayscale && !(tvnoise && shaderProgram))
			{
				static float mat[] =
				{
					0.30, 0.30, 0.30, 0.00,
					0.59, 0.59, 0.58, 0.00,
					0.11, 0.11, 0.11, 0.00,
					0.00, 0.00, 0.00, 1.00
				};

				glMatrixMode(GL_COLOR);
				glPushMatrix(); glLoadMatrixf(mat);
				glMatrixMode(GL_MODELVIEW);
			}
			
			glEnable(GL_TEXTURE_2D);

			GLuint tex[2]; glGenTextures(2, tex);

			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, tex[0]);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

			if (mode != 2)
				glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)graphics.width, (GLsizei)graphics.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data1.bytes);

			if (mode == 3)
			{
				glBindTexture(GL_TEXTURE_2D, tex[1]);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
			}

			if (mode != 1)
				glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)overlay.width, (GLsizei)overlay.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data2.bytes);

			if (grayscale && !(tvnoise && shaderProgram))
			{
				glMatrixMode(GL_COLOR);
				glPopMatrix();
				glMatrixMode(GL_MODELVIEW);
			}

			if (tvnoise && shaderProgram)
			{
				glUseProgram(shaderProgram);

				GLint location;

				if ((location = glGetUniformLocation(shaderProgram, "time")) != -1)
					glUniform1f(location, (float)[[NSProcessInfo processInfo] systemUptime]);

				if ((location = glGetUniformLocation(shaderProgram, "resolution")) != -1)
					glUniform2f(location, graphics.width, graphics.height);

				if ((location = glGetUniformLocation(shaderProgram, "tex0")) != -1)
				{
					glActiveTexture(GL_TEXTURE0);
					glBindTexture(GL_TEXTURE_2D, tex[0]);
					glUniform1i(location, 0);
				}

				if (mode == 3 && (location = glGetUniformLocation(shaderProgram, "tex1")) != -1)
				{
					glActiveTexture(GL_TEXTURE1);
					glBindTexture(GL_TEXTURE_2D, tex[1]);
					glUniform1i(location, 1);
				}

				if ((location = glGetUniformLocation(shaderProgram, "blend")) != -1)
					glUniform1i(location, mode == 3);

				if ((location = glGetUniformLocation(shaderProgram, "grayscale")) != -1)
					glUniform1i(location, grayscale);

				glBegin(GL_QUADS);
				glTexCoord2f(0.0, 0.0); glVertex2f(-1.0,  1.0);
				glTexCoord2f(1.0, 0.0); glVertex2f( 1.0,  1.0);
				glTexCoord2f(1.0, 1.0); glVertex2f( 1.0, -1.0);
				glTexCoord2f(0.0, 1.0); glVertex2f(-1.0, -1.0);
				glEnd();

				glUseProgram(0);
			}

			else
			{
				glActiveTexture(GL_TEXTURE0);
				glBindTexture(GL_TEXTURE_2D, tex[0]);

				glBegin(GL_QUADS);
				glTexCoord2f(0.0, 0.0); glVertex2f(-1.0,  1.0);
				glTexCoord2f(1.0, 0.0); glVertex2f( 1.0,  1.0);
				glTexCoord2f(1.0, 1.0); glVertex2f( 1.0, -1.0);
				glTexCoord2f(0.0, 1.0); glVertex2f(-1.0, -1.0);
				glEnd();

				if (mode == 3)
				{
					glBindTexture(GL_TEXTURE_2D, tex[1]);

					glEnable(GL_BLEND);
					glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

					glBegin(GL_QUADS);
					glTexCoord2f(0.0, 0.0); glVertex2f(-1.0,  1.0);
					glTexCoord2f(1.0, 0.0); glVertex2f( 1.0,  1.0);
					glTexCoord2f(1.0, 1.0); glVertex2f( 1.0, -1.0);
					glTexCoord2f(0.0, 1.0); glVertex2f(-1.0, -1.0);
					glEnd();

					glDisable(GL_BLEND);
				}
			}

			glActiveTexture(0);

			glBindTexture(GL_TEXTURE_2D, 0);
			glDeleteTextures(2, tex);
			glDisable(GL_TEXTURE_2D);

			if (isSelected)
			{
				glEnable(GL_BLEND);
				glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
				glColor4f(1.0, 1.0, 1.0, 0.5);

				glBegin(GL_QUADS);

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

				glEnd();

				glColor4f(1.0, 1.0, 1.0, 1.0);
				glDisable(GL_BLEND);
			}
		}
		else
		{
			glClear(GL_COLOR_BUFFER_BIT);
			if (blank) blank--;
		}

		glFlush();
	}
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

		NSCharacterSet *isAlphaNumber = [NSCharacterSet alphanumericCharacterSet];

		if (isText && theEvent.clickCount == 2 && [isAlphaNumber characterIsMember:[self.crt charAtX:mark.x Y:mark.y]])
		{
			selected.size.height = 1;
			selected.size.width = 1;

			selected.origin = mark;
			isSelected = TRUE;

			while (selected.origin.x + selected.size.width < text.width && [isAlphaNumber characterIsMember:[self.crt charAtX:selected.origin.x + selected.size.width Y:selected.origin.y]])
			{
				selected.size.width += 1;
			}

			while (selected.origin.x >= 1 && [isAlphaNumber characterIsMember:[self.crt charAtX:selected.origin.x - 1 Y:selected.origin.y]])
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
			isSelected = FALSE;

			NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];

			if (isText)
			{
				NSMutableString *string = [[NSMutableString alloc] init];

				for (unsigned y = selected.origin.y; y < selected.origin.y + selected.size.height; y++)
				{
					int count = 0; for (unsigned x = selected.origin.x; x < selected.origin.x + selected.size.width; x++)
					{
						unichar ch = [self.crt charAtX:x Y:y]; if (ch == ' ') count++; else count = 0;
						[string appendString:[NSString stringWithCharacters:&ch length:1]];
					}

					if (selected.size.height > 1)
					{
						if (count)
							[string deleteCharactersInRange:NSMakeRange(string.length - count, count)];

						[string appendString:@"\n"];
					}
				}

				[pasteBoard declareTypes:[NSArray arrayWithObjects:NSPasteboardTypeString, NSPasteboardTypeTIFF, nil] owner:nil];

				[pasteBoard setString:string
							  forType:NSPasteboardTypeString];

				selected.origin.x = selected.origin.x * graphics.width / text.width;
				selected.origin.y = selected.origin.y * graphics.height / text.height;

				selected.size.width = selected.size.width * graphics.width / text.width;
				selected.size.height = selected.size.height * graphics.height / text.height;
			}

			else
			{
				[pasteBoard declareTypes:[NSArray arrayWithObject:NSPasteboardTypeTIFF] owner:nil];
			}

			glViewport(0, 0, graphics.width, graphics.height);

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

				if (data2 && (gigaScreen || graphics.width != overlay.width || graphics.height != overlay.height))
				{
					glEnable(GL_BLEND);
					glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
					
					glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)overlay.width, (GLsizei)overlay.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data2.bytes);

					glBegin(GL_QUADS);
					glTexCoord2f(0.0, 0.0); glVertex2f(-1.0,  1.0);
					glTexCoord2f(1.0, 0.0); glVertex2f( 1.0,  1.0);
					glTexCoord2f(1.0, 1.0); glVertex2f( 1.0, -1.0);
					glTexCoord2f(0.0, 1.0); glVertex2f(-1.0, -1.0);
					glEnd();

					glDisable(GL_BLEND);

				}
				
				glDisable(GL_TEXTURE_2D);
			}

			selected.origin.y = graphics.height - selected.origin.y - selected.size.height;

			NSInteger bytesPerRow = selected.size.width * 3;

			if (bytesPerRow % 4)
				bytesPerRow += 4 - bytesPerRow % 4;

			NSBitmapImageRep *image = [[NSBitmapImageRep alloc]
									   initWithBitmapDataPlanes:NULL
									   pixelsWide:selected.size.width
									   pixelsHigh:selected.size.height
									   bitsPerSample:8
									   samplesPerPixel:3
									   hasAlpha:NO
									   isPlanar:NO
									   colorSpaceName:NSDeviceRGBColorSpace
									   bitmapFormat:0
									   bytesPerRow:bytesPerRow
									   bitsPerPixel:0];


			glReadPixels(selected.origin.x, selected.origin.y, selected.size.width, selected.size.height, GL_RGB, GL_UNSIGNED_BYTE, image.bitmapData);

			uint8_t *ptr1 = image.bitmapData, *ptr2 = ptr1 + ((GLint)selected.size.height - 1) * bytesPerRow;
			unsigned char* buffer = malloc(bytesPerRow);

			while (ptr1 < ptr2)
			{
				memcpy(buffer, ptr1,   bytesPerRow);
				memcpy(ptr1,   ptr2,   bytesPerRow);
				memcpy(ptr2,   buffer, bytesPerRow);

				ptr1 += bytesPerRow;
				ptr2 -= bytesPerRow;
			}

			free(buffer);

			[pasteBoard setData:[image TIFFRepresentation]
						forType:NSPasteboardTypeTIFF];
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
	isSelected = FALSE;
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

static GLuint createShader(GLenum shaderType)
{
	const GLchar *source = (GLchar *)[[NSString stringWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"tvnoise" ofType:shaderType == GL_VERTEX_SHADER ? @"vs" : @"fs"] encoding:NSASCIIStringEncoding error:nil] cStringUsingEncoding:NSASCIIStringEncoding];

	if (source == 0)
		return 0;

	GLuint shader = glCreateShader(shaderType);

	if (shader == 0)
		return 0;

	glShaderSource(shader, 1, &source, NULL);
	glCompileShader(shader);

#if defined(DEBUG)
	GLint logLength; glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);

	if (logLength > 0)
	{
		GLchar *log = malloc((size_t)logLength);
		glGetShaderInfoLog(shader, logLength, &logLength, log);
		NSLog(@"Shader compilation failed:\n%s", log);
		free(log);
	}
#endif

	GLint status; glGetShaderiv(shader, GL_COMPILE_STATUS, &status);

	if (!status)
	{
		glDeleteShader(shader);
		return 0;
	}

	return shader;
}

- (void) awakeFromNib
{
	[self setWantsBestResolutionOpenGLSurface:YES];

	if (self.document.isInViewingMode)
		constraint.constant = 0;

	gigaScreen = [NSUserDefaults.standardUserDefaults boolForKey:@"gigaScreen"];
	grayscale = [NSUserDefaults.standardUserDefaults boolForKey:@"grayscale"];
	tvnoise = [NSUserDefaults.standardUserDefaults boolForKey:@"tvnoise"];

	[[self openGLContext] makeCurrentContext];

	GLuint fragmentShader = createShader(GL_FRAGMENT_SHADER);  if (fragmentShader)
	{
		GLuint vertexShader = createShader(GL_VERTEX_SHADER); if (vertexShader)
		{
			shaderProgram = glCreateProgram();

			glAttachShader(shaderProgram, fragmentShader);
			glAttachShader(shaderProgram, vertexShader);

			glLinkProgram(shaderProgram);

#if defined(DEBUG)
			GLint logLength; glGetProgramiv(shaderProgram, GL_INFO_LOG_LENGTH, &logLength);

			if (logLength > 0)
			{
				GLchar *log = malloc((size_t)logLength);
				glGetProgramInfoLog(shaderProgram, logLength, &logLength, log);
				NSLog(@"Shader program linking failed:\n%s", log);
				free(log);
			}
#endif

			GLint status; glGetProgramiv(shaderProgram, GL_LINK_STATUS, &status);

			if (!status)
			{
				glDeleteProgram(shaderProgram);
				shaderProgram = 0;
			}

			glDeleteShader(vertexShader);
		}

		glDeleteShader(fragmentShader);
	}

	scale = 2;
	mode = 1;
}

// -----------------------------------------------------------------------------
// DEBUG: dealloc
// -----------------------------------------------------------------------------

- (void) dealloc
{
#ifdef DEBUG
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
#endif

	if (shaderProgram)
	{
		[[self openGLContext] makeCurrentContext];
		glDeleteProgram(shaderProgram);
	}
}

@end
