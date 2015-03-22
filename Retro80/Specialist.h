/*******************************************************************************
 ПЭВМ «Специалист»
 ******************************************************************************/

#import "x8080.h"
#import "x8255.h"
#import "x8253.h"
#import "mem.h"

#import "RKKeyboard.h"
#import "RKRecorder.h"

// -----------------------------------------------------------------------------
// Интерфейс графического экрана ПЭВМ "Специалист"
// -----------------------------------------------------------------------------

@interface SpecialistScreen : NSObject <DisplayController, ReadWrite, Bytes, HLDA, NSCoding>

@property Display *display;
@property uint8_t* screen;

@property uint8_t color;
@property BOOL isColor;

@end

// -----------------------------------------------------------------------------
// Интерфейс клавиатуры ПЭВМ "Специалист"
// -----------------------------------------------------------------------------

@interface SpecialistKeyboard : RKKeyboard

@property SpecialistScreen *crt;
@property (weak) X8253* snd;

@end

// -----------------------------------------------------------------------------
// ПЭВМ "Специалист"
// -----------------------------------------------------------------------------

@interface Specialist : Computer

@property X8080 *cpu;
@property Memory *rom;
@property Memory *ram;

@property SpecialistScreen *crt;

@property SpecialistKeyboard *kbd;
@property X8255 *ext;
@property X8253* snd;

@property F806 *inpHook;
@property F80C *outHook;

@end

// -----------------------------------------------------------------------------
// ПЭВМ "Специалист SP580"
// -----------------------------------------------------------------------------

@interface SpecialistSP580 : Specialist

@property F81B *kbdHook;

@end

// -----------------------------------------------------------------------------
// Интерфейс клавиатуры ПЭВМ "Специалист MX"
// -----------------------------------------------------------------------------

@interface SpecialistMXKeyboard : SpecialistKeyboard

@end

// -----------------------------------------------------------------------------
// Системный регистр ПЭВМ "Специалист MX"
// -----------------------------------------------------------------------------

@interface SpecialistMXSystem : NSObject <ReadWrite>

@property (weak) X8080 *cpu;

@end

// -----------------------------------------------------------------------------
// Регистр цвета ПЭВМ "Специалист MX"
// -----------------------------------------------------------------------------

@interface SpecialistMXColor : NSObject <ReadWrite>

@property SpecialistScreen *crt;

@end


// -----------------------------------------------------------------------------
// ПЭВМ "Специалист MX"
// -----------------------------------------------------------------------------


@interface SpecialistMX : Specialist

@property SpecialistMXKeyboard *kbd;
@property SpecialistMXSystem *sys1;
@property SpecialistMXColor *sys2;

@property NSMutableArray *quasi;

@end
