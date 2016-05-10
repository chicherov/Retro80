/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>
 
 *****/

#import <OpenGL/gl.h>

@protocol CRT;
@protocol KBD;

@class Document;
@class Digit;

// -----------------------------------------------------------------------------
// Display - Экран компьютера
// -----------------------------------------------------------------------------

@interface Display : NSOpenGLView <NSWindowDelegate>

@property (weak) IBOutlet NSResponder *nextResponder;
@property (weak) IBOutlet Document* document;

@property IBOutlet Digit *digit1;
@property IBOutlet Digit *digit2;
@property IBOutlet Digit *digit3;
@property IBOutlet Digit *digit4;

@property IBOutlet Digit *digit5;
@property IBOutlet Digit *digit6;

@property (weak) NSObject <CRT> *crt;
@property (weak) NSObject <KBD> *kbd;

- (uint32_t *) setupGraphicsWidth:(NSUInteger)width
						   height:(NSUInteger)height;

- (uint32_t *) setupOverlayWidth:(NSUInteger)width
						  height:(NSUInteger)height;

- (uint32_t *) setupTextWidth:(NSUInteger)width
					   height:(NSUInteger)height
						   cx:(NSUInteger)cx
						   cy:(NSUInteger)cy;

- (void) blank;

@end

// -----------------------------------------------------------------------------
// LCD цифра
// -----------------------------------------------------------------------------

@interface Digit : NSView
@property uint8_t segments;
@end

// -----------------------------------------------------------------------------
// Протокол контролера дисплея
// -----------------------------------------------------------------------------

@protocol CRT

@property Display* display;

@optional

- (unichar) charAtX:(unsigned)x
				  Y:(unsigned)y;

- (void) draw;

@end

// -----------------------------------------------------------------------------
// Протокол клавиатуры
// -----------------------------------------------------------------------------

@protocol KBD

- (void) flagsChanged:(NSEvent *)theEvent;
- (void) keyDown:(NSEvent *)theEvent;
- (void) keyUp:(NSEvent *)theEvent;

- (void) paste:(NSString *)string;

@property BOOL qwerty;

@end

