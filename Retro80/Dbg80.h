/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>
 
 Отладчик для центрального процессора из класса X8080

 *****/

#import "x8080.h"
#import "Debug.h"

@interface Dbg80 : NSObject <DebugDelegate>
@property(nonatomic, assign) Debug *debug;
@property(nonatomic, assign) X8080 *cpu;
- (void)run;

+ (instancetype)dbg80WithDebug:(Debug *)debug;
- (instancetype)initWithDebug:(Debug *)debug;

@end
