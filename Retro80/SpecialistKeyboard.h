/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Интерфейс клавиатуры ПЭВМ «Специалист»

 *****/

#import "SpecialistScreen.h"
#import "RKKeyboard.h"
#import "x8253.h"

@interface SpecialistKeyboard : RKKeyboard

@property SpecialistScreen *crt;
@property BOOL four;

@property (weak) X8253* snd;

@end
