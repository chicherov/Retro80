/*******************************************************************************
 ПЭВМ «Специалист»
 ******************************************************************************/

#import "x8080.h"
#import "x8255.h"
#import "x8253.h"
#import "mem.h"

#import "RKKeyboard.h"
#import "RKRecorder.h"
#import "ROMDisk.h"

// -----------------------------------------------------------------------------
// Интерфейс графического экрана ПЭВМ "Специалист"
// -----------------------------------------------------------------------------

@interface SpecialistScreen : NSObject <DisplayController, WR, HLDA, NSCoding>

@property uint8_t* screen;

@property uint8_t color;
@property BOOL isColor;

@end

// -----------------------------------------------------------------------------
// Интерфейс клавиатуры ПЭВМ "Специалист"
// -----------------------------------------------------------------------------

@interface SpecialistKeyboard : RKKeyboard

@property SpecialistScreen *crt;

@end

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

@end

// -----------------------------------------------------------------------------
// ПЭВМ "Специалист SP580"
// -----------------------------------------------------------------------------

@interface SpecialistSP580 : Specialist

@end

// -----------------------------------------------------------------------------
// Интерфейс клавиатуры ПЭВМ "Специалист MX"
// -----------------------------------------------------------------------------

@interface SpecialistMXKeyboard : SpecialistKeyboard

@end

// -----------------------------------------------------------------------------
// Системные регистры ПЭВМ "Специалист MX"
// -----------------------------------------------------------------------------

@interface SpecialistMXSystem : NSObject <WR>

@property SpecialistScreen *crt;
@property (weak) X8080 *cpu;

@end

// -----------------------------------------------------------------------------
// ПЭВМ "Специалист MX"
// -----------------------------------------------------------------------------

@interface SpecialistMX : Specialist

@property SpecialistMXKeyboard *kbd;
@property SpecialistMXSystem *sys;

@end
