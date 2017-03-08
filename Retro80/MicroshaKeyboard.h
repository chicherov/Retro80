/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Клавиатура ПЭВМ «Микроша»

 *****/

#import "RKKeyboard.h"
#import "x8253.h"

@interface MicroshaKeyboard : RKKeyboard

@property (weak) X8253* snd;

@end
