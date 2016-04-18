/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Интерфейс графического экрана ПЭВМ «Специалист»

 *****/

#import "x8080.h"

@interface SpecialistScreen : NSObject <CRT, WR, NSCoding>

@property uint8_t* screen;

@property BOOL isColor;
@property uint8_t color;

@end
