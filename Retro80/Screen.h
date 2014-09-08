#import <OpenGL/gl.h>

// -----------------------------------------------------------------------------
// Screen - Базовый класс для экрана компьютера
// -----------------------------------------------------------------------------

@interface Screen : NSOpenGLView
{
	uint32_t *bitmap;
	NSSize graphics;

	BOOL isSelected;
	NSRect selected;

	BOOL isText;
	NSSize text;
}

- (void) setupGraphicsWidth:(NSUInteger)width
					 height:(NSUInteger)height;

- (void) setupTextWidth:(NSUInteger)width
				 height:(NSUInteger)height
					 cx:(NSUInteger)cx
					 cy:(NSUInteger)cy;

- (uint8_t) byteAtX:(NSUInteger)x y:(NSUInteger)y;

- (IBAction) copy:(id)sender;

@end
