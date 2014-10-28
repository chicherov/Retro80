#import <OpenGL/gl.h>

@protocol DisplayController;
@protocol Keyboard;
@class Document;

// -----------------------------------------------------------------------------
// Display - Экран компьютера
// -----------------------------------------------------------------------------

@interface Display : NSOpenGLView <NSWindowDelegate>

- (uint32_t *) setupGraphicsWidth:(NSUInteger)width
						   height:(NSUInteger)height;

- (uint32_t *) setupOverlayWidth:(NSUInteger)width
						  height:(NSUInteger)height;

- (uint32_t *) setupTextWidth:(NSUInteger)width
					   height:(NSUInteger)height
						   cx:(NSUInteger)cx
						   cy:(NSUInteger)cy;

@property (assign) IBOutlet NSResponder *nextResponder;

@property (weak) NSObject <DisplayController> *crt;
@property (weak) NSObject <Keyboard> *kbd;
@property (weak) Document* document;

@end
