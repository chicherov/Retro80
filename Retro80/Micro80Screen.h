/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Контроллер дисплея ПЭВМ «Микро-80»

 *****/

#import "x8080.h"
#import "mem.h"

@interface Micro80Screen : RAM <CRT>

- (void) setMem:(MEM *)mem;

@property NSData *font;

@end
