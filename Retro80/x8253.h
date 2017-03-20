/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Микросхема трехканального таймера КР580ВИ53 (8253)

 *****/

#import "Retro80.h"

@interface X8253 : NSResponder <SND, RD, WR, INTE, Enabled, NSCoding>

@property(nonatomic) BOOL channel0;
@property(nonatomic) BOOL channel1;
@property(nonatomic) BOOL channel2;

@property(nonatomic) BOOL rkmode;

- (void)setGate2:(BOOL)gate
		   clock:(uint64_t)clock;

- (void)setBeeper:(BOOL)beeper
			clock:(uint64_t)clock;

- (void)setOutput:(BOOL)output
			clock:(uint64_t)clock;

- (void)setTone:(unsigned)tone
		  clock:(uint64_t)clock;

@end
