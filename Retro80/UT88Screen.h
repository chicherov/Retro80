/*****
 
 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>
 
 Контроллер дисплея ПЭВМ «ЮТ-88» и lcd
 
 *****/

#import "Micro80Screen.h"

@interface UT88Screen : Micro80Screen <IRQ, RESET>
@end
