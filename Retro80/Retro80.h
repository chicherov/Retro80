#import "Screen.h"
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
// Протокол клавиатуры
// -----------------------------------------------------------------------------

@protocol Keyboard <NSObject>

- (void) flagsChanged:(NSEvent *)theEvent;
- (void) keyDown:(NSEvent *)theEvent;
- (void) keyUp:(NSEvent *)theEvent;

- (void) paste:(NSString *)string;

@end

// -----------------------------------------------------------------------------
// Бащовый класс произвольного компьютера
// -----------------------------------------------------------------------------

@interface Computer : NSResponder

@property (weak) Document *document;

@property Screen *crt;
@property Sound *snd;

@property NSObject <Processor> *cpu;
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

- (void) registerUndoWitString:(NSString *)string type:(NSInteger)type;
- (void) registerUndoWithMenuItem:(NSMenuItem *)menuItem;
- (void) performUndo:(NSData *)data;

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

@property IBOutlet NSLayoutConstraint *constraint;
@property IBOutlet NSTextField *text1;
@property IBOutlet NSTextField *text2;
@property IBOutlet NSView *view;

@end
