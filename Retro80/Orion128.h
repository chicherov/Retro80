/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Орион 128»

 *****/

#import "Retro80.h"
#import "x8253.h"
#import "mem.h"

#import "Orion128Screen.h"
#import "Orion128Floppy.h"
#import "SystemROMDisk.h"

#import "RKKeyboard.h"
#import "RKRecorder.h"

@class Orion128System;
@class Z80CardII;

@interface Orion128 : Retro80

@property(nonatomic, strong) Orion128Screen *crt;
@property(nonatomic, strong) X8253 *snd;

@property(nonatomic, strong) RKKeyboard *kbd;
@property(nonatomic, strong) SystemROMDisk *ext;
@property(nonatomic, strong) X8255 *prn;

@property(nonatomic, strong) Orion128Floppy *fdd;

@property(nonatomic, strong) MEM *mem;

@property(nonatomic, strong) Orion128System *sys;

@property(nonatomic, strong) F806 *inpHook;
@property(nonatomic, strong) F80C *outHook;

- (instancetype)initWithData:(NSData *)data;
- (instancetype)init;

@end

// ПЭВМ «Орион-128» с Монитором 1

@interface Orion128M1 : Orion128
@end

// ПЭВМ «Орион-128» с Монитором 3

@interface Orion128M3 : Orion128
@end

// ПЭВМ «Орион-128» с Z80 Card V3.1

@interface Orion128Z80V31 : Orion128
@end

// ПЭВМ «Орион-128» с Z80 Card V3.2

@interface Orion128Z80V32 : Orion128Z80V31
@end

// Системные регистры ПЭВМ «Орион 128»

@interface Orion128System : NSObject<WR>
@property(nonatomic, assign) Orion128 *orion;
@end

// ПЭВМ «Орион-128» с Z80 Card II

@interface Orion128Z80II : Orion128
@property(nonatomic, strong) Z80CardII *card;
@end

// Z80 Card II

@interface Z80CardII : NSObject<RD, WR, RESET>
@property(nonatomic, assign) Orion128Z80II *orion;
@end
