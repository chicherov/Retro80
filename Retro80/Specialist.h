/*******************************************************************************
 ПЭВМ «Специалист»
 ******************************************************************************/

#import "x8080.h"
#import "x8255.h"
#import "x8253.h"
#import "mem.h"

#import "SpecialistScreen.h"
#import "SpecialistKeyboard.h"

#import "RKRecorder.h"
#import "ROMDisk.h"

// -----------------------------------------------------------------------------
// ПЭВМ "Специалист"
// -----------------------------------------------------------------------------

@interface Specialist : Computer

@property X8080 *cpu;
@property ROM *rom;
@property RAM *ram;

@property SpecialistScreen *crt;

@property SpecialistKeyboard *kbd;
@property X8255* ext;
@property X8253* snd;

@property F806 *inpHook;
@property F80C *outHook;

- (BOOL) decodeWithCoder:(NSCoder *)decoder;
- (BOOL) createObjects;
- (BOOL) mapObjects;

@end
