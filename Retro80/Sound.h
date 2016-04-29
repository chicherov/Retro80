/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 *****/

@protocol CRT;
@protocol SND;
@protocol CPU;

@class Document;

// -----------------------------------------------------------------------------
// Sound - Поддеркжа звукового ввода/вывода
// -----------------------------------------------------------------------------

@interface Sound : NSResponder

@property (weak) IBOutlet NSResponder *nextResponder;
@property (weak) IBOutlet Document* document;
@property IBOutlet NSTextField *textField;

@property (weak) NSObject<CPU> *cpu;
@property (weak) NSObject<CRT> *crt;
@property (weak) NSObject<SND> *snd;

@property BOOL debug;

@property (readonly) BOOL isOutput;
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

@protocol SND

@property Sound* sound;

@optional

- (uint16_t) sample:(uint64_t)clock;

@end

