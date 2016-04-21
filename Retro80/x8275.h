/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Контроллер отображения видеоинформации КР580ВГ75 (8275)

 *****/

#import "x8080.h"
#import "x8257.h"

@interface X8275 : NSObject <CRT, RD, WR, HLDA, DMA, INTE, IRQ, NSCoding>

- (void) setColors:(const uint32_t *)colors
	attributesMask:(uint8_t)attributesMask
		 shiftMask:(uint8_t)shiftMask;

- (void) setFonts:(const uint16_t *)fonts;
- (void) setMcpg:(const uint8_t *)mcpg;

- (void) selectFont:(unsigned)offset;

@end
