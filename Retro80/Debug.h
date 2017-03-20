/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Панель отладчика

 *****/

@class Debug;

@protocol DebugDelegate
- (BOOL)Debugger:(NSString *)command;
@end

@interface Debug : NSResponder <NSTextViewDelegate, NSWindowDelegate>

@property(nonatomic, strong) NSObject <DebugDelegate> *delegate;

- (void)print:(NSString *)format, ...;
- (void)flush;
- (void)clear;

- (void)run;

@end
