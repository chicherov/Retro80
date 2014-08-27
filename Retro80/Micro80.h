#import "Retro80.h"
#import "x8080.h"
#import "x8255.h"

#import "ram.h"
#import "rom.h"

#import "TextScreen.h"

#import "RKKeyboard.h"
#import "RKRecorder.h"

// -----------------------------------------------------------------------------
// Интерфейс сопряжения "Микро-80"
// -----------------------------------------------------------------------------

@interface Micro80Recorder : Sound <ReadWrite>

@end

// -----------------------------------------------------------------------------
// Интерфейс клавиатуры "Микро-80"
// -----------------------------------------------------------------------------

@interface Micro80Keyboard : RKKeyboard

@end

// -----------------------------------------------------------------------------
// ПЭВМ "Микро-80"
// -----------------------------------------------------------------------------

@interface Micro80 : NSObject <Computer, NSCoding>

@property (weak) Document *document;

@property X8080 *cpu;
@property RAM *ram;
@property ROM *rom;

@property TextScreen *crt;

@property Micro80Recorder *snd;
@property Micro80Keyboard *kbd;

@end
