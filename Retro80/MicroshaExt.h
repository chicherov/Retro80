/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Второй интерфейс ВВ55 ПЭВМ «Микроша», управление знакогенератором

 *****/

#import "x8255.h"
#import "x8275.h"

@interface MicroshaExt : X8255

@property (weak) X8275 *crt;

@end

