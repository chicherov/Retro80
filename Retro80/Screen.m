#import "Retro80.h"
#import "Screen.h"

// -----------------------------------------------------------------------------

@implementation Adjustment
{
	NSObject<Computer> __weak * _computer;

	SEL _setter; void (*fSetter)(id, SEL, BOOL);
	SEL _getter; BOOL (*fGetter)(id, SEL);

	NSInteger _tag;
}

- (id) initWithTag:(NSInteger)tag computer:(NSObject<Computer> *)computer setter:(SEL)setter getter:(SEL)getter
{
	if (self = [super init])
	{
		_tag = tag; _computer = computer;
		fSetter = (void *)[computer methodForSelector:_setter = setter];
		fGetter = (void *)[computer methodForSelector:_getter = getter];
		_getter = getter;
	}

	return self;
}

- (void) setEnabled:(BOOL)enabled
{
	fSetter(_computer, _setter, enabled);
}

- (BOOL) enabled
{
	return fGetter(_computer, _getter);
}

- (NSInteger) tag
{
	return _tag;
}

@end

// -----------------------------------------------------------------------------

@implementation Screen
{
	NSMutableDictionary *adjustments;
	NSMutableData *data;
	NSInteger scale;

	NSPoint mark;
	BOOL isMark;
}

// -----------------------------------------------------------------------------
// Adjustments: опции эмуляции компьютера
// -----------------------------------------------------------------------------

- (void) addAdjustment:(NSObject<Adjustment> *)adjustment
{
	[adjustments setObject:adjustment forKey:[NSNumber numberWithInteger:adjustment.tag]];
}

- (IBAction) adjustment:(NSMenuItem *)menuItem
{
	NSObject <Adjustment> *adjustment = [adjustments objectForKey:[NSNumber numberWithInteger:[menuItem tag]]];
	adjustment.enabled = adjustment.enabled == FALSE;
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

- (IBAction) play:(id)sender
{
	[self.document.computer.snd play:sender];
}

- (IBAction) stop:(id)sender
{
	[self.document.computer.snd stop:sender];
}

- (IBAction) stepBackward:(id)sender
{
	[self.document.computer.snd stepBackward:sender];
}

- (IBAction) stepForward:(id)sender
{
	[self.document.computer.snd stepForward:sender];
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(adjustment:))
	{
		NSObject <Adjustment> *adjustment = [adjustments objectForKey:[NSNumber numberWithInteger:menuItem.tag]];

		[menuItem setHidden:adjustment == nil];

		if (adjustment)
		{
			menuItem.state = adjustment.enabled ? NSOnState : NSOffState;
			return YES;
		}

		return NO;
	}
	
	else if (menuItem.action == @selector(zoom:))
	{
		menuItem.state = menuItem.tag == scale ? NSOnState : NSOffState;

		if (self.window.styleMask & NSFullScreenWindowMask)
			return NO;
		else
			return YES;
	}

	else if (menuItem.action == @selector(selectAll:))
	{
		return TRUE;
	}

	else if (menuItem.action == @selector(copy:))
	{
		return TRUE;
		return isSelected;
	}

	else if (menuItem.action == @selector(paste:))
	{
		return [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString] != nil;
	}

	else if ([self.document.computer.snd respondsToSelector:menuItem.action])
	{
		return [self.document.computer.snd validateMenuItem:menuItem];
	}

	else
	{
		return NO;
	}
}

// -----------------------------------------------------------------------------
// zoom
// -----------------------------------------------------------------------------

- (IBAction) zoom:(NSMenuItem *)sender
{
	if (sender != nil && sender.tag >= 1 && sender.tag <= 9)
	{
		[[NSUserDefaults standardUserDefaults] setInteger:scale = sender.tag forKey:@"scale"];

		if (scale && self.window.isZoomed)
			[self.window zoom:sender];
	}

	if (data != nil && scale >= 1 && scale <= 9)
	{
		NSRect frame = self.window.frame; frame.origin.y += frame.size.height;

		frame.size.height = graphics.height * scale + 44;
		frame.size.width = graphics.width * scale;
		frame.origin.y -= frame.size.height;

		if (!(self.window.isZoomed || self.window.styleMask & NSFullScreenWindowMask))
			[self.window setFrame:frame display:TRUE];

		[self.window setMinSize:NSMakeSize(graphics.width, graphics.height + 44)];
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
//
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
// События клавиатуры
// -----------------------------------------------------------------------------

- (void) flagsChanged:(NSEvent*)theEvent
{
	[self.kbd flagsChanged:theEvent];
}

- (void) keyDown:(NSEvent*)theEvent
{
	[self.kbd keyDown:theEvent];
	isSelected = FALSE;
}

- (void) keyUp:(NSEvent*)theEvent
{
	[self.kbd keyUp:theEvent];
}

// -----------------------------------------------------------------------------
// copy/paste
// -----------------------------------------------------------------------------

- (IBAction) copy:(id)sender
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

// -----------------------------------------------------------------------------

- (IBAction) paste:(id)sender
{
	[self.kbd paste:sender];
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		adjustments = [[NSMutableDictionary alloc] init];

		scale = [[NSUserDefaults standardUserDefaults]
				 integerForKey:@"scale"];
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
		adjustments = [[NSMutableDictionary alloc] init];

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
