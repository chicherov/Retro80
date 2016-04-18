/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «ЮТ-88»

 *****/

#import "Micro80.h"

// -----------------------------------------------------------------------------
// UT88Screen - экран ПЭВМ «ЮТ-88» + LCD + таймер
// -----------------------------------------------------------------------------

@interface UT88Screen : Micro80Screen <RD, WR, IRQ, RESET>
@property NSObject<RD, WR> *mem;
@end

// -----------------------------------------------------------------------------
// UT88Keyboard - обе клавиатуры ПЭВМ «ЮТ-88»
// -----------------------------------------------------------------------------

@interface UT88Keyboard : Micro80Keyboard
@end

// -----------------------------------------------------------------------------
// RAM диск ПЭВМ «ЮТ-88»
// -----------------------------------------------------------------------------

@interface UT88Port40 : NSObject <RD, WR, RESET>
@property (weak) X8080 *cpu;
@end

// -----------------------------------------------------------------------------
// ПЭВМ «ЮТ-88»
// -----------------------------------------------------------------------------

@interface UT88: Computer

@property X8080 *cpu;
@property RAM *ram;

@property UT88Keyboard *kbd;
@property UT88Screen *crt;

@property RAM *ramE800;
@property BOOL isExxx;

@property ROM *monitor0;
@property BOOL is0xxx;

@property ROM *monitorF;
@property BOOL isFxxx;

@property Micro80Recorder *snd;
@property UT88Port40 *sys;

@property F806 *inpHook;
@property F80C *outHook;

@end
