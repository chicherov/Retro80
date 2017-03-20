/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Базовый класс ретрокомпьютера с процессором КР580ВМ80А/Z80

 *****/

#import "Computer.h"
#import "x8080.h"
#import "mem.h"

// Протокол контролера дисплея
@protocol CRT
@property(assign, nonatomic) Display *display;

@optional
- (void)draw;
@end

// Протокол звукового процессора
@protocol SND
@property(nonatomic, assign) Sound *sound;

@optional
- (void)flush:(uint64_t)clock;
- (void)setOutput:(BOOL)output
			clock:(uint64_t)clock;
@end

@interface Retro80 : Computer
@property(nonatomic, strong) X8080 *cpu;
@property(nonatomic, strong) ROM *rom;
@property(nonatomic, strong) RAM *ram;
@property(nonatomic, strong, readonly) NSObject<CRT> *crt;
@property(nonatomic, strong, readonly) NSObject<SND> *snd;
@end
