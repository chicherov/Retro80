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

@interface Orion128Beeper : NSObject<SoundController, INTE>
@end

@interface Orion128SystemF8 : NSObject<RD, WR>
- (id) initWithCRT:(Orion128Screen *)crt;
@end

@interface Orion128SystemF9 : NSObject<RD, WR>
- (id) initWithCPU:(X8080 *)cpu;
@end

@interface Orion128SystemFA : NSObject<RD, WR>
- (id) initWithCRT:(Orion128Screen *)crt;
@end

// -----------------------------------------------------------------------------
// ПЭВМ "Орион 128"
// -----------------------------------------------------------------------------

@interface Orion128 : Computer
{
	MEM *mem[4];
}

@property X8080 *cpu;
@property ROM *rom;
@property RAM *ram;

@property Orion128SystemF8 *sysF8;
@property Orion128SystemF9 *sysF9;
@property Orion128SystemFA *sysFA;

@property Orion128Screen *crt;
@property Orion128Floppy *fdd;

@property RKKeyboard *kbd;
@property ROMDisk *ext;
@property X8255 *prn;

@property Orion128Beeper *snd;

@property F806 *inpHook;
@property F80C *outHook;

@end

// -----------------------------------------------------------------------------
// Системные регистры Z80Card-II
// -----------------------------------------------------------------------------

@interface Orion128RAM : RAM
@property uint32_t offset;
@end

@interface Orion128SystemFB : NSObject<RD, WR>
- (id) initWithCPU:(X8080 *)cpu RAM:(Orion128RAM *)ram CRT:(Orion128Screen *)crt;
@end

@interface Orion128SystemFE : NSObject <RD, WR>
- (id) initWithSND:(NSObject<SoundController> *)snd EXT:(ROMDisk *)ext;
@end

@interface Orion128SystemFF : NSObject <RD, WR>
- (id) initWithSND:(NSObject<SoundController> *)snd;
@end

// -----------------------------------------------------------------------------
// ПЭВМ "Орион 128" + Z80Card-II
// -----------------------------------------------------------------------------

@interface Orion128Z80CardII : Orion128

@property Orion128RAM *ram;

@property Orion128SystemFB *sysFB;
@property Orion128SystemFE *sysFE;
@property Orion128SystemFF *sysFF;

@end
