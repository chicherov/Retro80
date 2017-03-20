/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Контроллер дисплея ПЭВМ «Микро-80»

 *****/

#import "Retro80.h"
#import "Display.h"
#import "mem.h"

@interface Micro80Screen : RAM<CRT, TextScreen>
- (void)setMem:(MEM *)mem;
@end
