/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Специалист MX»

 *****/

#import "Specialist.h"
#import "ROMDisk.h"
#import "vg93.h"

#import "SpecialistMXKeyboard.h"
#import "SpecialistMXSystem.h"

// -----------------------------------------------------------------------------
// ПЭВМ "Специалист MX" с MXOS (Commander)
// -----------------------------------------------------------------------------

@interface SpecialistMX_Commander : Specialist

@property SpecialistMXSystem *sys;
@property ROMDisk *ext;

@end

// -----------------------------------------------------------------------------
// ПЭВМ "Специалист MX" с MXOS (RAMFOS)
// -----------------------------------------------------------------------------

@interface SpecialistMX_RAMFOS : SpecialistMX_Commander

@property SpecialistMXKeyboard *kbd;
@property VG93 *fdd;

@end

// -----------------------------------------------------------------------------
// ПЭВМ "Специалист MX2"
// -----------------------------------------------------------------------------

@interface SpecialistMX2 : SpecialistMX_RAMFOS

@property SpecialistMX2System *sys;

@end
