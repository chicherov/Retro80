/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Поддеркжа звукового ввода/вывода

 *****/

@class Computer;

@interface Sound : NSResponder

@property(nonatomic, assign) Computer *computer;

@property(nonatomic, readonly) BOOL isOutput;
@property(nonatomic, readonly) BOOL isInput;

- (void)openWave:(NSURL *)URL;

- (BOOL)start;
- (void)stop;

- (void)update:(uint64_t)clock output:(BOOL)output
		  left:(int16_t)left right:(int16_t)right;

- (void)flush:(uint64_t)clock;

- (BOOL)input:(uint64_t)clock;

@end
