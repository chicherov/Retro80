/*****
 
 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>
 
 Контроллер дисплея ПЭВМ «ЮТ-88» и lcd
 
 *****/

#import "UT88Screen.h"

@implementation UT88Screen
{
    uint8_t lcd[3];
    uint64_t IRQ;
    BOOL update;
}

// -----------------------------------------------------------------------------

- (void) setDisplay:(Display *)display
{
    display.digit1.hidden = FALSE;
    display.digit2.hidden = FALSE;
    display.digit3.hidden = FALSE;
    display.digit4.hidden = FALSE;
    display.digit5.hidden = FALSE;
    display.digit6.hidden = FALSE;

    [super setDisplay:display];
}

// -----------------------------------------------------------------------------

- (void) draw
{
    if (update)
    {
        static uint8_t mask[] =
        {
            0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71
        };
        
        self.display.digit1.segments = mask[lcd[2] >> 4];
        self.display.digit2.segments = mask[lcd[2] & 15];
        self.display.digit3.segments = mask[lcd[1] >> 4];
        self.display.digit4.segments = mask[lcd[1] & 15];
        self.display.digit5.segments = mask[lcd[0] >> 4];
        self.display.digit6.segments = mask[lcd[0] & 15];
    }
    
    [super draw];
}

// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
    if (addr >= 0x9000 && addr <= 0x9FFF)
    {
        lcd[addr & 2 ? 2 : addr & 1] = data; update = TRUE;
    }
    
    else
    {
        mutableBytes[addr & 0x7FF] = data;
    }
    
    [self.ram WR:addr data:data CLK:clock];
}

// -----------------------------------------------------------------------------

- (BOOL) IRQ:(uint64_t)clock
{
    if (IRQ <= clock)
    {
        IRQ += 16000000;
        return TRUE;
    }
    
    return FALSE;
}

// -----------------------------------------------------------------------------

- (void) RESET:(uint64_t)clock
{
    lcd[0] = 0xFF;
    lcd[1] = 0xFF;
    lcd[2] = 0xFF;
    update = TRUE;
}

// -----------------------------------------------------------------------------

- (id) init
{
    if (self = [super init])
        [self RESET:0];
    
    return self;
}

// -----------------------------------------------------------------------------

- (id) initWithCoder:(NSCoder *)decoder
{
    if (self = [super initWithCoder:decoder])
    {
        [decoder decodeValueOfObjCType:@encode(uint8_t[3]) at:&lcd];
        IRQ = [decoder decodeInt64ForKey:@"IRQ"];
    }
    
    return self;
}

// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeValueOfObjCType:@encode(uint8_t[3]) at:&lcd];
    [coder encodeInt64:IRQ forKey:@"IRQ"];
}

@end
