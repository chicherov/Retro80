#import "Screen.h"
#import "Sound.h"

// -----------------------------------------------------------------------------
// Протокол готового компьютера
// -----------------------------------------------------------------------------

@protocol Computer <NSObject>

@property Screen *crt;
@property Sound *snd;

+ (NSString *) title;

- (void) start;
- (void) reset;
- (void) stop;

@end

// -----------------------------------------------------------------------------
// Документ, содержащий тот или иной компьютер
// -----------------------------------------------------------------------------

@interface Document : NSDocument

@property NSObject <Computer> *computer;

- (void) undoPoint:(NSString *)actionName;
- (void) undo:(NSData *)data;

@end

// -----------------------------------------------------------------------------
// DocumentController
// -----------------------------------------------------------------------------

@interface DocumentController : NSDocumentController

@end

// -----------------------------------------------------------------------------
// WindowController
// -----------------------------------------------------------------------------

@interface WindowController : NSWindowController

@property IBOutlet NSTextField *text1;
@property IBOutlet NSTextField *text2;
@property IBOutlet NSView *view;

@end
