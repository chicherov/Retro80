@class X8080;

// -----------------------------------------------------------------------------
// Sound - Поддеркжа звукового ввода/вывода
// -----------------------------------------------------------------------------

@interface Sound : NSResponder

@property NSTextField *textField;

@property (weak) X8080 *cpu;

@property (readonly) BOOL isInput;
@property (readonly) BOOL input;

@property BOOL output;
@property BOOL beeper;

- (SInt8) sample:(uint64_t)clock;

- (BOOL) open:(NSURL *)url;
- (void) close;

- (void) start;
- (void) stop;

@end
