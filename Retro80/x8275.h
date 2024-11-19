/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Контроллер отображения видеоинформации КР580ВГ75 (8275)

 *****/

#import "Retro80.h"
#import "Display.h"
#import "x8257.h"

@interface X8275 : NSObject <CRT, TextScreen, RD, WR, HLDA, DMA, INTE, NSCoding>

@property (weak) X8080 *cpu;

- (void) setColors:(const uint32_t *)colors
	attributesMask:(uint8_t)attributesMask
		 shiftMask:(uint8_t)shiftMask;

- (void) setFonts:(const uint16_t *)fonts;
- (void) setMcpg:(const uint8_t *)mcpg;

- (void) selectFont:(unsigned)offset;

@end
