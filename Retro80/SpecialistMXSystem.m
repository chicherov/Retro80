/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Системные регистры ПЭВМ «Специалист MX»

 *****/

#import "SpecialistMXSystem.h"
#import "mem.h"

// -----------------------------------------------------------------------------
// Системные регистры Специалист MX
// -----------------------------------------------------------------------------

@implementation SpecialistMXSystem

@synthesize cpu;
@synthesize ram;
@synthesize crt;
@synthesize fdd;

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
    switch (addr & 0x1F)
    {
        case 0x10:	// D3.1 (pF0 - захват)

            fdd.HOLD = TRUE;
            break;

        case 0x11:	// D3.2	(pF1 - мотор)

            break;

        case 0x12:	// D4.2	(pF2 - сторона)

            if (fdd.selected == 0)
                fdd.selected = 1;

            fdd.head = data & 1;
            break;

        case 0x13:	// D4.1	(pF3 - дисковод)

            fdd.selected = (data & 1) + 1;
            break;

        case 0x18:	// Регистр цвета
        case 0x19:
        case 0x1A:
        case 0x1B:

            crt.color = data;
            break;

        case 0x1C:	// Выбрать RAM

            cpu.PAGE = 0;
            break;

        case 0x1D:	// Выбрать RAM-диск

            if (ram.length != 0x20000)
                ram.offset = ((data & 7) + 1) << 16;

            cpu.PAGE = 1;
            break;

        case 0x1E:	// Выбрать ROM-диск
        case 0x1F:
            
            cpu.PAGE = 2;
            break;
    }
}

- (void) RESET:(uint64_t)clock
{
    fdd.selected = 1;
}

// -----------------------------------------------------------------------------
// DEBUG: dealloc
// -----------------------------------------------------------------------------

#ifdef DEBUG
- (void) dealloc
{
    NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end

// -----------------------------------------------------------------------------
// Системные регистры Специалист MX2
// -----------------------------------------------------------------------------

@implementation SpecialistMX2System

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
    switch (addr & 0x1F)
    {
        case 0x18:
        case 0x19:
        case 0x1A:
        case 0x1B:

            if ((self.cpu.PAGE & ~1) == 4)
            {
                self.cpu.PAGE = 4 | (data & 1);
                self.kbd.four = (data & 2) == 0;
            }
            else
            {
                self.crt.color = data;
            }

            break;

        case 0x1C:	// Выбрать RAM

            self.cpu.PAGE = 0;
            self.kbd.crt = nil;
            break;

        case 0x1D:	// Выбрать RAM-диск

            if (self.ram.length != 0x20000)
                self.ram.offset = ((data & 7) + 1) << 16;

            self.cpu.PAGE = 1;
            self.kbd.crt = nil;
            break;

        case 0x1E:	// Выбрать ROM-диск

            self.cpu.PAGE = 2;
            self.kbd.crt = nil;
            break;
            
        case 0x1F:	// Выбрать STD
            
            self.kbd.crt = self.crt;
            self.cpu.PAGE = 4;
            break;
            
        default:
            
            [super WR:addr data:data CLK:clock];
            
    }
}

- (void) RESET:(uint64_t)clock
{
    self.kbd.crt = self.crt;
    [super RESET:clock];
}

@end
