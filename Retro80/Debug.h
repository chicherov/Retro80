@class Debug;

// -----------------------------------------------------------------------------
// Протокол отладчика
// -----------------------------------------------------------------------------

@protocol Debug

- (NSString *) debugCommand:(NSString *)command;

@end

// -----------------------------------------------------------------------------
// Панель отладчика
// -----------------------------------------------------------------------------

@interface Debug : NSObject

@property IBOutlet NSTextView *textView;
@property IBOutlet NSPanel *panel;

- (void) run:(NSObject *)debug;

@end
