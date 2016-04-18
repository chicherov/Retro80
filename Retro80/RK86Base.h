/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Базовый вариант РК86 без ПЗУ и распределения памяти

 *****/

#import "x8080.h"
#import "x8275.h"
#import "x8257.h"
#import "x8253.h"

#import "RKKeyboard.h"
#import "RKRecorder.h"

#import "mem.h"

// -----------------------------------------------------------------------------

@interface RK86Base : Computer

@property X8080 *cpu;
@property X8275 *crt;
@property X8257 *dma;
@property X8253 *snd;

@property RKKeyboard *kbd;
@property X8255 *ext;

@property ROM *rom;
@property RAM *ram;

@property F806 *inpHook;
@property F80C *outHook;

@property BOOL isColor;

@end

// -----------------------------------------------------------------------------
