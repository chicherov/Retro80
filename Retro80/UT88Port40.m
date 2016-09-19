/*****
 
 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>
 
 Интерфейс RAM диска ПЭВМ «ЮТ-88»
 
 *****/

#import "UT88Port40.h"

@implementation UT88Port40

@synthesize cpu;

// -----------------------------------------------------------------------------

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
    cpu.RAMDISK = data & 0x08 ? data & 0x04 ? data & 0x02 ? data & 0x01 ? 0 : 4 : 5 : 6 : 7;
}

// -----------------------------------------------------------------------------

- (void) RESET:(uint64_t)clock
{
    cpu.RAMDISK = 0;
}

@end
