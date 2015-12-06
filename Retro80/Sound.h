@protocol CentralProcessorUnit;
@protocol DisplayController;
@protocol SoundController;
@class Document;

// -----------------------------------------------------------------------------
// Sound - Поддеркжа звукового ввода/вывода
// -----------------------------------------------------------------------------

@interface Sound : NSResponder

@property (weak) IBOutlet Document* document;
@property IBOutlet NSTextField *textField;

@property (weak) NSObject <CentralProcessorUnit> *cpu;
@property (weak) NSObject <DisplayController> *crt;
@property (weak) NSObject <SoundController> *snd;

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

// -----------------------------------------------------------------------------
// Протокол звукового процессора
// -----------------------------------------------------------------------------

@protocol SoundController

@property Sound* sound;

@optional

- (SInt8) sample:(uint64_t)clock;

@end

