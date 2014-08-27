#import <OpenGL/gl.h>

@protocol Computer;
@class Document;

// -----------------------------------------------------------------------------
// Протокол настройки эмуляции компьютера
// -----------------------------------------------------------------------------

@protocol Adjustment <NSObject>

@property BOOL enabled;
- (NSInteger) tag;

@end


// -----------------------------------------------------------------------------

@interface Adjustment : NSObject <Adjustment>

- (id) initWithTag:(NSInteger)tag
		  computer:(NSObject <Computer> *)computer
			setter:(SEL)setter
			getter:(SEL)getter;

@end

// -----------------------------------------------------------------------------
// Протокол клавиатуры
// -----------------------------------------------------------------------------

@protocol Keyboard <NSObject>

- (void) flagsChanged:(NSEvent*)theEvent;
- (void) keyDown:(NSEvent*)theEvent;
- (void) keyUp:(NSEvent*)theEvent;

- (void) paste:(id)sender;

@end

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

- (void) addAdjustment:(NSObject <Adjustment> *)adjustment;

@property (weak) Document *document;
@property NSObject <Keyboard> *kbd;

- (void) setupGraphicsWidth:(NSUInteger)width
					 height:(NSUInteger)height;

- (void) setupTextWidth:(NSUInteger)width
				 height:(NSUInteger)height
					 cx:(NSUInteger)cx
					 cy:(NSUInteger)cy;

- (IBAction) copy:(id)sender;

@end
