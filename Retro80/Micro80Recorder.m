/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Интерфейс сопряжения ПЭВМ «Микро-80»

 *****/

#import "Micro80Recorder.h"
#import "Sound.h"

@implementation Micro80Recorder

@synthesize sound;

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	*data = [sound input:clock];
}

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	BOOL output = data & 0x01;
	[sound update:clock output:output left:output ? 8192 : 0 right:output ? 8192 : 0];
}

@end
