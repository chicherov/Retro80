@protocol DisplayController;
@protocol SoundController;
@protocol Processor;
@class Document;

// -----------------------------------------------------------------------------
// Sound - Поддеркжа звукового ввода/вывода
// -----------------------------------------------------------------------------

@interface Sound : NSResponder

@property (weak) IBOutlet Document* document;
@property IBOutlet NSTextField *textField;

@property (weak) NSObject <DisplayController> *crt;
@property (weak) NSObject <SoundController> *snd;
@property (weak) NSObject <Processor> *cpu;

@property BOOL debug;

@property (readonly) BOOL isOutput;
@property uint16_t beeper;
@property BOOL output;

@property (readonly) BOOL isInput;
@property (readonly) BOOL input;

- (void) start:(NSURL *)URL;
- (void) start;
- (void) stop;

@end
