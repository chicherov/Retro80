/*******************************************************************************
 ПЭВМ «Орион 128»
 ******************************************************************************/

#import "x8080.h"
#import "mem.h"

#import "Orion128Screen.h"
#import "Orion128Floppy.h"

#import "RKKeyboard.h"
#import "RKRecorder.h"
#import "ROMDisk.h"

// -----------------------------------------------------------------------------
// Системные регистры ПЭВМ "Орион 128"
// -----------------------------------------------------------------------------

@interface Orion128System : NSObject <WR, SoundController, INTE>

@property Orion128Screen *crt;
@property (weak) X8080 *cpu;

@end

// -----------------------------------------------------------------------------
// ПЭВМ "Орион 128"
// -----------------------------------------------------------------------------

@interface Orion128 : Computer

@property X8080 *cpu;
@property ROM *rom;
@property RAM *ram;

@property Orion128System *sys;
@property Orion128Screen *crt;

@property RKKeyboard *kbd;
@property ROMDisk *ext;

@property BOOL isFloppy;
@property Orion128Floppy *fdd;

@property F806 *inpHook;
@property F80C *outHook;

@end
