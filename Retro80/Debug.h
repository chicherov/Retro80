/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 *****/

// -----------------------------------------------------------------------------
// Панель отладчика
// -----------------------------------------------------------------------------

@interface Debug : NSObject

@property (weak) IBOutlet Document* document;

@property IBOutlet NSTextView *textView;
@property IBOutlet NSPanel *panel;

- (IBAction) debug:(id)sender;

- (void) print:(NSString *)format, ...;
- (void) flush;
- (void) clear;

@end

// -----------------------------------------------------------------------------
// Протокол отладчика
// -----------------------------------------------------------------------------

@protocol Debug

- (BOOL) Debugger:(NSString *)command;

- (void) attach:(NSObject<CPU> *)cpu
		  debug:(Debug *)debug;

@end
