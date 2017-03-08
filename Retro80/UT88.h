/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «ЮТ-88»

 *****/

#import "Micro80.h"
#import "x8253.h"

#import "UT88Keyboard.h"
#import "UT88Screen.h"
#import "UT88System.h"

// -----------------------------------------------------------------------------
// ПЭВМ «ЮТ-88»
// -----------------------------------------------------------------------------

@interface UT88: Computer

@property X8080 *cpu;

@property ROM *monitor0;
@property ROM *monitorF;
@property RAM *ram;

@property UT88Keyboard *kbd;
@property UT88Screen *crt;

@property UT88System *sys;

@property ROMDisk *ext;
@property X8253 *snd;

@property F806 *inpHook;
@property F80C *outHook;

@end
