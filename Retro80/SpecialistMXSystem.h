/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Системные регистры ПЭВМ «Специалист MX»

 *****/

#import "SpecialistScreen.h"
#import "SpecialistMXKeyboard.h"
#import "vg93.h"
#import "mem.h"

// -----------------------------------------------------------------------------
// Системные регистры Специалист MX
// -----------------------------------------------------------------------------

@interface SpecialistMXSystem : NSObject <RD, WR, RESET>

@property SpecialistScreen *crt;
@property (weak) X8080 *cpu;
@property VG93 *fdd;
@property RAM *ram;

@end

// -----------------------------------------------------------------------------
// Системные регистры Специалист MX2
// -----------------------------------------------------------------------------

@interface SpecialistMX2System : SpecialistMXSystem

@property SpecialistMXKeyboard *kbd;

@end
