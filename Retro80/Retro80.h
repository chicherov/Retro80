#import "Display.h"
#import "Sound.h"
#import "Debug.h"

@class Document;

// -----------------------------------------------------------------------------
// Протокол объекта со свойством enabled (для хуков)
// -----------------------------------------------------------------------------

@protocol Adjustment
@property BOOL enabled;
@end

// -----------------------------------------------------------------------------
// Протокол центрального процессора
// -----------------------------------------------------------------------------

@protocol CentralProcessorUnit

- (BOOL) execute:(uint64_t)clock;
- (void) reset;

@property uint32_t quartz;
@property uint64_t CLK;

@end

// -----------------------------------------------------------------------------
// Базовый класс произвольного компьютера
// -----------------------------------------------------------------------------

@interface Computer : NSResponder

@property (weak) Document *document;

+ (NSArray<NSString*> *) extensions;
+ (NSString *) title;

@property NSObject <CentralProcessorUnit> *cpu;

@property NSObject <DisplayController> *crt;
@property NSObject <SoundController> *snd;
@property NSObject <Keyboard> *kbd;

- (BOOL) createObjects;
- (BOOL) mapObjects;

- (void) encodeWithCoder:(NSCoder *)encoder;
- (BOOL) decodeWithCoder:(NSCoder *)decoder;
- (id) initWithCoder:(NSCoder *)decoder;

- (id) initWithData:(NSData *)data URL:(NSURL *)url;
- (id) initWithType:(NSInteger)type;

- (void) start;
- (void) stop;

@property NSObject <Adjustment> *inpHook;
@property NSObject <Adjustment> *outHook;

- (IBAction) reset:(id)sender;
- (IBAction) debug:(id)sender;

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
@property IBOutlet Debug *debug;

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

- (Computer *) computerByFileExtension:(NSURL *)url
								  data:(NSData *)data;

@end

// -----------------------------------------------------------------------------
// WindowController
// -----------------------------------------------------------------------------

@interface WindowController : NSWindowController <NSWindowDelegate>

@property (weak) Document *document;

@end
