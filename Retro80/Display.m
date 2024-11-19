/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Экран компьютера

*****/

#ifndef GNUSTEP
#import <OpenGL/gl.h>
#else
#define GL_GLEXT_PROTOTYPES
#import <GL/gl.h>
#import <GL/glext.h>
#endif

#import "Display.h"

#import "WindowController.h"

@implementation Display
{
	NSMutableData *data1;
	NSMutableData *data2;

	NSObject<TextScreen> __weak *textScreen;

	NSSize graphics;
	NSSize overlay;
	NSSize text;

	BOOL isSelected;
	NSRect selected;

	NSPoint mark;
	BOOL isMark;

	unsigned mode;

	BOOL gigaScreen;
	BOOL grayscale;
	BOOL tvnoise;

	GLuint shaderProgram;
}

- (uint32_t *)setupGraphicsWidth:(NSUInteger)width height:(NSUInteger)height
{
	@synchronized(self)
	{
		data1 = [NSMutableData dataWithLength:width*height*4];
		graphics.width = width;
		graphics.height = height;
		textScreen = nil;
		text = NSZeroSize;
		data2 = nil;
		overlay = NSZeroSize;

		dispatch_async(dispatch_get_main_queue(), ^{
			[(WindowController *) self.window.windowController resize];
		});

		isSelected = NO;
		selected = NSZeroRect;
		return data1.mutableBytes;
	}
}

- (uint32_t *)setupOverlayWidth:(NSUInteger)width height:(NSUInteger)height
{
	@synchronized(self)
	{
		data2 = [NSMutableData dataWithLength:width*height*4];
		overlay.width = width;
		overlay.height = height;
		return data2.mutableBytes;
	}
}

- (uint32_t *)setupTextWidth:(NSUInteger)width height:(NSUInteger)height cx:(NSUInteger)cx cy:(NSUInteger)cy textScreen:(NSObject<TextScreen> *)ts
{
	@synchronized(self)
	{
		[self setupGraphicsWidth:width*cx height:height*cy];
		textScreen = ts;
		text.width = width;
		text.height = height;
		return data1.mutableBytes;
	}
}

- (NSSize)size
{
	@synchronized(self)
	{
		return graphics;
	}
}

- (void)draw:(BOOL)page
{
	if (page)
	{
		if (data2 && (gigaScreen || graphics.width != overlay.width || graphics.height != overlay.height))
		{
			mode = 3;

			dispatch_async(dispatch_get_main_queue(), ^{
				[self setNeedsDisplay:YES];
			});
		}
		else
		{
			mode = 1;

			dispatch_async(dispatch_get_main_queue(), ^{
				[self setNeedsDisplay:YES];
			});
		}
	}
	else if (!gigaScreen)
	{
		mode = 2;

		dispatch_async(dispatch_get_main_queue(), ^{
			[self setNeedsDisplay:YES];
		});
	}
}

// ---------------------------------------------------------------------------------------------------------------------

- (void)drawRect:(NSRect)rect
{
	@synchronized(self)
	{
#ifndef GNUSTEP
		NSRect backingBounds = [self convertRectToBacking:[self bounds]];
#else
		NSRect backingBounds = [self bounds];
#endif
		glViewport(0, 0, backingBounds.size.width, backingBounds.size.height);

		if (((mode & 1) == 0 || data1) && ((mode & 2) == 0 || data2))
		{
			if (grayscale && !(tvnoise && shaderProgram))
			{
				glMatrixMode(GL_COLOR);
				glPushMatrix();

				static float mat[] = {
					0.30, 0.30, 0.30, 0.00,
					0.59, 0.59, 0.58, 0.00,
					0.11, 0.11, 0.11, 0.00,
					0.00, 0.00, 0.00, 1.00
				};

				glLoadMatrixf(mat);

				glMatrixMode(GL_MODELVIEW);
			}

			glEnable(GL_TEXTURE_2D);

			GLuint tex[2];
			glGenTextures(2, tex);

			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, tex[0]);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, tvnoise ? GL_LINEAR : GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, tvnoise ? GL_LINEAR : GL_NEAREST);

			if (mode != 2)
			{
				glTexImage2D(GL_TEXTURE_2D,
							 0,
							 GL_RGBA,
							 (GLsizei) graphics.width,
							 (GLsizei) graphics.height,
							 0,
							 GL_RGBA,
							 GL_UNSIGNED_BYTE,
							 data1.bytes);
			}

			if (mode == 3)
			{
				glBindTexture(GL_TEXTURE_2D, tex[1]);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, tvnoise ? GL_LINEAR : GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, tvnoise ? GL_LINEAR : GL_NEAREST);
			}

			if (mode != 1)
			{
				glTexImage2D(GL_TEXTURE_2D,
							 0,
							 GL_RGBA,
							 (GLsizei) overlay.width,
							 (GLsizei) overlay.height,
							 0,
							 GL_RGBA,
							 GL_UNSIGNED_BYTE,
							 data2.bytes);
			}

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
					glUniform1f(location, (float) [[NSProcessInfo processInfo] systemUptime]);

				if ((location = glGetUniformLocation(shaderProgram, "resolution")) != -1)
					glUniform2f(location, graphics.width, graphics.height);

				if ((location = glGetUniformLocation(shaderProgram, "grayscale")) != -1)
					glUniform1i(location, grayscale);

				if ((location = glGetUniformLocation(shaderProgram, "tex0")) != -1)
				{
					glActiveTexture(GL_TEXTURE0);
					glBindTexture(GL_TEXTURE_2D, tex[0]);
					glUniform1i(location, 0);
				}

				if ((location = glGetUniformLocation(shaderProgram, "blend")) != -1)
					glUniform1i(location, mode == 3);

				if (mode == 3 && (location = glGetUniformLocation(shaderProgram, "tex1")) != -1)
				{
					glActiveTexture(GL_TEXTURE1);
					glBindTexture(GL_TEXTURE_2D, tex[1]);
					glUniform1i(location, 1);
				}

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
				glTexCoord2f(1.0, 0.0);	glVertex2f( 1.0,  1.0);
				glTexCoord2f(1.0, 1.0);	glVertex2f( 1.0, -1.0);
				glTexCoord2f(0.0, 1.0);	glVertex2f(-1.0, -1.0);
				glEnd();

				if (mode == 3)
				{
					glEnable(GL_BLEND);
					glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

					glBindTexture(GL_TEXTURE_2D, tex[1]);

					glBegin(GL_QUADS);
					glTexCoord2f(0.0, 0.0); glVertex2f(-1.0,  1.0);
					glTexCoord2f(1.0, 0.0);	glVertex2f( 1.0,  1.0);
					glTexCoord2f(1.0, 1.0);	glVertex2f( 1.0, -1.0);
					glTexCoord2f(0.0, 1.0);	glVertex2f(-1.0, -1.0);
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

				if (textScreen)
				{
					glVertex2f(selected.origin.x/text.width*2 - 1, 1 - selected.origin.y/text.height*2);
					glVertex2f((selected.origin.x + selected.size.width)/text.width*2 - 1,
							   1 - selected.origin.y/text.height*2);
					glVertex2f((selected.origin.x + selected.size.width)/text.width*2 - 1,
							   1 - (selected.origin.y + selected.size.height)/text.height*2);
					glVertex2f(selected.origin.x/text.width*2 - 1,
							   1 - (selected.origin.y + selected.size.height)/text.height*2);
				}
				else
				{
					glVertex2f(selected.origin.x/graphics.width*2 - 1, 1 - selected.origin.y/graphics.height*2);
					glVertex2f((selected.origin.x + selected.size.width)/graphics.width*2 - 1,
							   1 - selected.origin.y/graphics.height*2);
					glVertex2f((selected.origin.x + selected.size.width)/graphics.width*2 - 1,
							   1 - (selected.origin.y + selected.size.height)/graphics.height*2);
					glVertex2f(selected.origin.x/graphics.width*2 - 1,
							   1 - (selected.origin.y + selected.size.height)/graphics.height*2);
				}

				glEnd();

				glColor4f(1.0, 1.0, 1.0, 1.0);
				glDisable(GL_BLEND);
			}
		}
		else
		{
			glClear(GL_COLOR_BUFFER_BIT);
		}

        [[self openGLContext] flushBuffer];
		glFlush();
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (sel_isEqual(menuItem.action, @selector(selectAll:)))
		return data1 != NULL;

	if (sel_isEqual(menuItem.action, @selector(copy:)))
		return isSelected;

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

		menuItem.state = NO;
		return NO;
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

		menuItem.state = tvnoise && shaderProgram != 0;
		return shaderProgram != 0;
	}

	return NO;
}

- (IBAction)gigaScreen:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		if (menuItem.tag)
			[NSUserDefaults.standardUserDefaults
				setBool:(gigaScreen = ![NSUserDefaults.standardUserDefaults boolForKey:@"gigaScreen"])
				 forKey:@"gigaScreen"];
		else
			gigaScreen = !gigaScreen;
	}
}

- (IBAction)grayscale:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		if (menuItem.tag)
			[NSUserDefaults.standardUserDefaults
				setBool:(grayscale = ![NSUserDefaults.standardUserDefaults boolForKey:@"grayscale"])
				 forKey:@"grayscale"];
		else
			grayscale = !grayscale;
	}
}

- (IBAction)tvnoise:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		if (menuItem.tag)
			[NSUserDefaults.standardUserDefaults
				setBool:(tvnoise = ![NSUserDefaults.standardUserDefaults boolForKey:@"tvnoise"])
				 forKey:@"tvnoise"];
		else
			tvnoise = !tvnoise;
	}
}

- (IBAction)selectAll:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		isSelected = YES;
		selected.origin = NSZeroPoint;
		selected.size = textScreen ? text : graphics;
	}
}

- (void)mouseDown:(NSEvent *)theEvent
{
	@synchronized(self)
	{
		NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];
		NSSize size = textScreen ? text : graphics;

		mark.y = trunc(size.height - point.y/self.frame.size.height*size.height);
		mark.x = trunc(point.x/self.frame.size.width*size.width);

		isSelected = NO;
		isMark = YES;

		NSCharacterSet *isAlphaNumber = [NSCharacterSet alphanumericCharacterSet];

		if (textScreen && theEvent.clickCount == 2)
		{
			if ([isAlphaNumber characterIsMember:[textScreen unicharAtX:mark.x Y:mark.y]])
			{
				selected.size.height = 1;
				selected.size.width = 1;

				selected.origin = mark;
				isSelected = YES;

				while (selected.origin.x + selected.size.width < text.width)
				{
					unichar ch = [textScreen unicharAtX:selected.origin.x + selected.size.width Y:selected.origin.y];

					if ([isAlphaNumber characterIsMember:ch])
						selected.size.width += 1;
					else
						break;
				}

				while (selected.origin.x >= 1)
				{
					unichar ch = [textScreen unicharAtX:selected.origin.x - 1 Y:selected.origin.y];

					if ([isAlphaNumber characterIsMember:ch])
					{
						selected.size.width += 1;
						selected.origin.x -= 1;
					}
					else
						break;
				}

				mark = selected.origin;
			}
		}
	}
}

- (void)mouseUp:(NSEvent *)theEvent
{
	isMark = NO;
}

- (void)mouseDragged:(NSEvent *)theEvent
{
	if (isMark)
	{
		@synchronized(self)
		{
			NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];
			NSSize size = textScreen ? text : graphics;

			point.y = trunc(size.height - point.y/self.frame.size.height*size.height);
			point.x = trunc(point.x/self.frame.size.width*size.width);

			if (point.y < size.height && point.x < size.width)
			{
				if (point.y < mark.y)
				{
					selected.origin.y = point.y;
					selected.size.height = mark.y - point.y + 1;
				}
				else
				{
					selected.origin.y = mark.y;
					selected.size.height = point.y - mark.y + 1;
				}

				if (point.x < mark.x)
				{
					selected.origin.x = point.x;
					selected.size.width = mark.x - point.x + 1;
				}
				else
				{
					selected.origin.x = mark.x;
					selected.size.width = point.x - mark.x + 1;
				}

				isSelected = YES;
			}
		}
	}
}

- (void)keyDown:(NSEvent *)theEvent
{
	[super keyDown:theEvent];
	isSelected = NO;
}

- (IBAction)copy:(NSMenuItem *)menuItem
{
	@synchronized(self)
	{
		if (isSelected)
		{
			NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];

			if (textScreen)
			{
				NSMutableString *string = [[NSMutableString alloc] init];

				for (unsigned y = selected.origin.y; y < selected.origin.y + selected.size.height; y++)
				{
					int count = 0;

					for (unsigned x = selected.origin.x; x < selected.origin.x + selected.size.width; x++)
					{
						unichar ch = [textScreen unicharAtX:x Y:y];

						if (ch == ' ')
							count++;
						else
							count = 0;

						[string appendString:[NSString stringWithCharacters:&ch length:1]];
					}

					if (selected.size.height > 1)
					{
						if (count)
							[string deleteCharactersInRange:NSMakeRange(string.length - count, count)];

						[string appendString:@"\n"];
					}
				}

				[pasteBoard declareTypes:@[NSPasteboardTypeString, NSPasteboardTypeTIFF] owner:nil];
				[pasteBoard setString:string forType:NSPasteboardTypeString];

				selected.origin.x = selected.origin.x*graphics.width/text.width;
				selected.origin.y = selected.origin.y*graphics.height/text.height;

				selected.size.width = selected.size.width*graphics.width/text.width;
				selected.size.height = selected.size.height*graphics.height/text.height;
			}

			else
			{
				[pasteBoard declareTypes:@[NSPasteboardTypeTIFF] owner:nil];
			}

			glViewport(0, 0, graphics.width, graphics.height);

			if (data1)
			{
				glEnable(GL_TEXTURE_2D);

				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

				glTexImage2D(GL_TEXTURE_2D,
							 0,
							 GL_RGBA,
							 (GLsizei) graphics.width,
							 (GLsizei) graphics.height,
							 0,
							 GL_RGBA,
							 GL_UNSIGNED_BYTE,
							 data1.bytes);

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

					glTexImage2D(GL_TEXTURE_2D,
								 0,
								 GL_RGBA,
								 (GLsizei) overlay.width,
								 (GLsizei) overlay.height,
								 0,
								 GL_RGBA,
								 GL_UNSIGNED_BYTE,
								 data2.bytes);

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

			NSInteger bytesPerRow = selected.size.width*3;

			if (bytesPerRow%4)
				bytesPerRow += 4 - bytesPerRow%4;

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

			glReadPixels(selected.origin.x,
						 selected.origin.y,
						 selected.size.width,
						 selected.size.height,
						 GL_RGB,
						 GL_UNSIGNED_BYTE,
						 image.bitmapData);

			uint8_t *ptr1 = image.bitmapData;
			uint8_t *ptr2 = ptr1 + ((GLint) selected.size.height - 1)*bytesPerRow;
			uint8_t buffer[bytesPerRow];

			while (ptr1 < ptr2)
			{
				memcpy(buffer, ptr1, bytesPerRow);
				memcpy(ptr1, ptr2, bytesPerRow);
				memcpy(ptr2, buffer, bytesPerRow);

				ptr1 += bytesPerRow;
				ptr2 -= bytesPerRow;
			}

			[pasteBoard setData:[image TIFFRepresentation]
						forType:NSPasteboardTypeTIFF];

			isSelected = NO;
		}
	}
}

static GLuint createShader(GLenum shaderType)
{
	NSString
		*file = [NSBundle.mainBundle pathForResource:@"tvnoise" ofType:shaderType == GL_VERTEX_SHADER ? @"vs" : @"fs"],
		*text = [NSString stringWithContentsOfFile:file encoding:NSASCIIStringEncoding error:NULL];

	const GLchar *source = (GLchar *) [text cStringUsingEncoding:NSASCIIStringEncoding];

	if (source == 0)
		return 0;

	GLuint shader = glCreateShader(shaderType);

	if (shader == 0)
		return 0;

	glShaderSource(shader, 1, &source, NULL);
	glCompileShader(shader);

#ifndef NDEBUG
	GLint logLength; glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);

	if (logLength > 0)
	{
		GLchar *log = malloc((size_t) logLength);
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

// ---------------------------------------------------------------------------------------------------------------------

- (void)awakeFromNib
{
	gigaScreen = [NSUserDefaults.standardUserDefaults boolForKey:@"gigaScreen"];
	grayscale = [NSUserDefaults.standardUserDefaults boolForKey:@"grayscale"];
	tvnoise = [NSUserDefaults.standardUserDefaults boolForKey:@"tvnoise"];

	mode = 1;

#ifndef GNUSTEP
	[self setWantsBestResolutionOpenGLSurface:YES];
	[[self openGLContext] makeCurrentContext];
#endif

	GLuint fragmentShader = createShader(GL_FRAGMENT_SHADER);

	if (fragmentShader)
	{
		GLuint vertexShader = createShader(GL_VERTEX_SHADER);

		if (vertexShader)
		{
			shaderProgram = glCreateProgram();
			glAttachShader(shaderProgram, fragmentShader);
			glAttachShader(shaderProgram, vertexShader);
			glLinkProgram(shaderProgram);

#ifndef NDEBUG
			GLint logLength; glGetProgramiv(shaderProgram, GL_INFO_LOG_LENGTH, &logLength);

			if (logLength > 0)
			{
				GLchar *log = malloc((size_t) logLength);
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
}

- (void)dealloc
{
#ifndef NDEBUG
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
#endif

	if (shaderProgram)
	{
#ifndef GNUSTEP
		[[self openGLContext] makeCurrentContext];
#endif
		glDeleteProgram(shaderProgram);
	}
}

@end
