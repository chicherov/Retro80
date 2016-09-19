/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Интерфейс сопряжения ПЭВМ «Микро-80»

 *****/

#import "Micro80Recorder.h"

@implementation Micro80Recorder

@synthesize sound;

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	*data = sound.input;
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	sound.output = data & 0x01;
}

@end
