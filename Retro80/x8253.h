/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Микросхема трехканального таймера КР580ВИ53 (8253)

 *****/

#import "Sound.h"
#import "x8080.h"

@interface X8253 : NSObject <SND, RD, WR, INTE, NSCoding>

@property BOOL channel0;
@property BOOL channel1;
@property BOOL channel2;

@property BOOL rkmode;

- (void) setGate2:(BOOL)gate
			clock:(uint64_t)clock;

- (void) setBeeper:(BOOL)beeper
			 clock:(uint64_t)clock;

- (void) setTone:(unsigned)tone
		   clock:(uint64_t)clock;

@end
