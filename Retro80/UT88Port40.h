/*****
 
 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>
 
 Интерфейс RAM диска ПЭВМ «ЮТ-88»
 
 *****/

#import "x8080.h"

@interface UT88Port40 : NSObject <RD, WR, RESET>
@property (weak) X8080 *cpu;
@end
