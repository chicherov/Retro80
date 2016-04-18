/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Интерфейс графического экрана ПЭВМ «Орион-128»

 *****/

#import "x8080.h"

@interface Orion128Screen : NSObject <CRT, IRQ, WR, RESET, NSCoding>

@property const uint8_t* memory;

@property uint8_t color;
@property uint8_t page;

@property BOOL IE;

@end
