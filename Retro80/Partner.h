/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Партнер 01.01»

 *****/

#import "RK86Base.h"
#import "vg93.h"

@class Partner;

// -----------------------------------------------------------------------------
// Системнный регистр 1 - выбор станицы адресного простарнства
// -----------------------------------------------------------------------------

@interface PartnerSystem1 : NSObject <WR>

@property (weak) X8080 *cpu;

@end

// -----------------------------------------------------------------------------
// Системнный регистр 2 и внешние устройства
// -----------------------------------------------------------------------------

@interface PartnerSystem2 : NSObject <RD, WR, NSCoding>

@property (weak) Partner *partner;
@property uint8_t slot;
@property BOOL mcpg;

@end

// -----------------------------------------------------------------------------
// Окно внешнего устройства
// -----------------------------------------------------------------------------

@interface PartnerExternal : NSObject <RD, WR, BYTE>

@property NSObject <RD, BYTE> *object;

@end

// -----------------------------------------------------------------------------
// Вариант клавиатуры РК86 для Партнера
// -----------------------------------------------------------------------------

@interface PartnerKeyboard : RKKeyboard

@end

// -----------------------------------------------------------------------------
// ПЭВМ «Партнер 01.01»
// -----------------------------------------------------------------------------

@interface Partner : RK86Base

@property PartnerKeyboard *kbd;

@property PartnerExternal *win1;
@property PartnerExternal *win2;

@property PartnerSystem1 *sys1;
@property PartnerSystem2 *sys2;

@property ROM *basic;

@property BOOL isFloppy;
@property ROM *fddbios;
@property VG93 *floppy;

@property ROM *mcpgbios;
@property RAM *mcpgfont;

@end
