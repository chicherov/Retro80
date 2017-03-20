/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Специалист MX»

 *****/

#import "Specialist.h"
#import "vg93.h"

@class SpecialistMXSystem;

// ПЭВМ "Специалист MX" с RAMFOS
@interface SpecialistMX : Specialist
@property(nonatomic, strong) SpecialistMXSystem *sys;
@property(nonatomic, strong) VG93 *fdd;
@end

// ПЭВМ "Специалист MX" с MXOS (Commander)
@interface SpecialistMX_MXOS : SpecialistMX
@end

// ПЭВМ "Специалист MX2"
@interface SpecialistMX2 : SpecialistMX
@end

// Системные регистры Специалист MX
@interface SpecialistMXSystem : NSObject<RD, WR, RESET>
@property(nonatomic, assign) SpecialistMX *specialist;
@end

// Системные регистры Специалист MX2
@interface SpecialistMX2System : SpecialistMXSystem
@end
