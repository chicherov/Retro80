/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Микроша»

 *****/

#import "RK86Base.h"
#import "Floppy.h"

#import "MicroshaKeyboard.h"
#import "MicroshaExt.h"

// -----------------------------------------------------------------------------
// Вывод байта на магнитофон (Микроша)
// -----------------------------------------------------------------------------

@interface MicroshaF80C : F80C

@end

// -----------------------------------------------------------------------------
// ПЭВМ «Микроша»
// -----------------------------------------------------------------------------

@interface Microsha : RK86Base

@property MicroshaKeyboard *kbd;
@property MicroshaExt *ext;

@property MicroshaF80C *outHook;

@property Floppy *fdd;
@property ROM *dos;

@end
