/*****
 
 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>
 
 Интерфейс RAM диска и прерывания ПЭВМ «ЮТ-88»
 
 *****/

#import "x8080.h"
#import "mem.h"

@interface UT88System : NSObject <RD, WR, IRQ, RESET>

- (MEM *) RAMDISK:(RAM *)ram;

@property (weak) X8080 *cpu;

@end
