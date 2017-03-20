/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Экран компьютера

 *****/

#import <OpenGL/gl.h>
#import "Digit.h"

@protocol TextScreen
- (unichar)unicharAtX:(unsigned)x Y:(unsigned)y;
@end

@interface Display : NSOpenGLView

@property IBOutlet Digit *digit1;
@property IBOutlet Digit *digit2;
@property IBOutlet Digit *digit3;
@property IBOutlet Digit *digit4;
@property IBOutlet Digit *digit5;
@property IBOutlet Digit *digit6;

- (uint32_t *)setupGraphicsWidth:(NSUInteger)width
						  height:(NSUInteger)height;

- (uint32_t *)setupOverlayWidth:(NSUInteger)width
						 height:(NSUInteger)height;

- (uint32_t *)setupTextWidth:(NSUInteger)width
					  height:(NSUInteger)height
						  cx:(NSUInteger)cx
						  cy:(NSUInteger)cy
				  textScreen:(NSObject<TextScreen> *)textScreen;

- (void)draw:(BOOL)page;

- (NSSize)size;

@end
