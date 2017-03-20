/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Партнер 01.01»

 *****/

#import "RK86Base.h"
#import "vg93.h"

@class Partner;

// Системнный регистр 1 - выбор станицы адресного простарнства
@interface PartnerSystem1 : NSObject<WR, DMA>
@property(nonatomic, assign) Partner *partner;
@end

// Системнный регистр 2 и внешние устройства
@interface PartnerSystem2 : NSObject<RD, WR, RESET, NSCoding>
@property(nonatomic, assign) Partner *partner;
@property(nonatomic) uint8_t slot;
@property(nonatomic) BOOL mcpg;
@end

// Окно внешнего устройства
@interface PartnerExternal : NSObject<RD, WR, BYTE>
@property(nonatomic, assign) NSObject<RD, BYTE> *object;
@end

// Вариант клавиатуры РК86 для Партнера
@interface PartnerKeyboard : RKKeyboard
@end

// ПЭВМ «Партнер 01.01»
@interface Partner : RK86Base

@property(nonatomic, strong) PartnerExternal *win1;
@property(nonatomic, strong) PartnerExternal *win2;

@property(nonatomic, strong) PartnerSystem1 *sys1;
@property(nonatomic, strong) PartnerSystem2 *sys2;

@property(nonatomic, strong) ROM *basic;

@property(nonatomic, strong) ROM *mcpgbios;
@property(nonatomic, strong) RAM *mcpgfont;

@property(nonatomic, strong) ROM *fddbios;
@property(nonatomic, strong) VG93 *fdd;

@end
