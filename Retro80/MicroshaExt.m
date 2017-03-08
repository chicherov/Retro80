/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Второй интерфейс ВВ55 ПЭВМ «Микроша», управление знакогенератором

 *****/

#import "MicroshaExt.h"

@implementation MicroshaExt

@synthesize crt;

- (void) setB:(uint8_t)data
{
    [crt selectFont:data & 0x80 ? 0x2800 : 0x0C00];
}

// -----------------------------------------------------------------------------

- (uint8_t) A
{
    return 0x00;
}

- (uint8_t) B
{
    return 0x00;
}

- (uint8_t) C
{
    return 0x00;
}

@end
