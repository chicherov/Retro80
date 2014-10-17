/*******************************************************************************
 ПЭВМ «Радио-86РК»
 ******************************************************************************/

#import "Retro80.h"

#import "x8080.h"
#import "x8275.h"
#import "x8257.h"
#import "x8253.h"

#import "ram.h"
#import "rom.h"

#import "RKKeyboard.h"
#import "RKRecorder.h"

// -----------------------------------------------------------------------------

@interface RK86Base : Computer

@property X8080 *cpu;
@property X8275 *crt;
@property X8257 *dma;
@property X8253 *snd;

@property RKKeyboard *kbd;
@property X8255 *ext;

@property RAM *ram;
@property ROM *rom;

- (BOOL) decodeObjects:(NSCoder *)decoder;
- (BOOL) createObjects;
- (BOOL) mapObjects;

@property F81B *kbdHook;
@property F806 *inpHook;
@property F80C *outHook;

@property BOOL isColor;

- (void) reset;

@end

// -----------------------------------------------------------------------------
