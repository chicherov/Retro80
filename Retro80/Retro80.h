#import "Display.h"
#import "Sound.h"

@class Document;

// -----------------------------------------------------------------------------
// Протокол объекта со свойством enabled (для хуков)
// -----------------------------------------------------------------------------

@protocol Adjustment <NSObject>
@property BOOL enabled;
@end

// -----------------------------------------------------------------------------
// Протокол центрального процессора
// -----------------------------------------------------------------------------

@protocol Processor <NSObject>

- (void) execute:(uint64_t)clock;

@property uint32_t quartz;
@property uint64_t CLK;

@end

// -----------------------------------------------------------------------------
// Протокол контролера дисплея
// -----------------------------------------------------------------------------

@protocol DisplayController <NSObject>

@property Display* display;

- (unichar) charAtX:(unsigned)x Y:(unsigned)y;

@end

// -----------------------------------------------------------------------------
// Протокол контролера дисплея
// -----------------------------------------------------------------------------

@protocol SoundController <NSObject>

@property Sound* sound;

- (SInt8) sample:(uint64_t)clock;

@end

// -----------------------------------------------------------------------------
// Протокол клавиатуры
// -----------------------------------------------------------------------------

@protocol Keyboard <NSObject>

- (void) flagsChanged:(NSEvent *)theEvent;
- (void) keyDown:(NSEvent *)theEvent;
- (void) keyUp:(NSEvent *)theEvent;

- (void) paste:(NSString *)string;

@end

// -----------------------------------------------------------------------------
// Базовый класс произвольного компьютера
// -----------------------------------------------------------------------------

@interface Computer : NSResponder

@property Document *document;

@property NSObject <Processor> *cpu;

@property NSObject <DisplayController> *crt;
@property NSObject <SoundController> *snd;
@property NSObject <Keyboard> *kbd;

+ (NSString *) title;

- (void) start;
- (void) stop;

@property NSObject <Adjustment> *kbdHook;
@property NSObject <Adjustment> *inpHook;
@property NSObject <Adjustment> *outHook;

- (IBAction) colorModule:(id)sender;
- (IBAction) extraMemory:(id)sender;
- (IBAction) ROMDisk:(id)sender;
- (IBAction) floppy:(id)sender;

@end

// -----------------------------------------------------------------------------
// Документ, содержащий тот или иной компьютер
// -----------------------------------------------------------------------------

@interface Document : NSDocument

@property Computer *computer;

@property IBOutlet Display *display;
@property IBOutlet Sound *sound;

- (void) registerUndoWitString:(NSString *)string type:(NSInteger)type;
- (void) registerUndoWithMenuItem:(NSMenuItem *)menuItem;
- (void) performUndo:(NSData *)data;

- (id) initWithComputer:(Computer *)computer
				   type:(NSString *)typeName
				  error:(NSError **)outError;

@end

// -----------------------------------------------------------------------------
// DocumentController
// -----------------------------------------------------------------------------

@interface DocumentController : NSDocumentController

@end

// -----------------------------------------------------------------------------
// WindowController
// -----------------------------------------------------------------------------

@interface WindowController : NSWindowController <NSWindowDelegate>

@property (weak) Document *document;

@end
