/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Микро-80»

 *****/

#import "x8080.h"
#import "mem.h"

#import "RKKeyboard.h"
#import "RKRecorder.h"
#import "Display.h"

// -----------------------------------------------------------------------------
// Дисплей "Микро-80"
// -----------------------------------------------------------------------------

@interface Micro80Screen : NSObject <CRT>

@property const uint8_t* memory;
@property const uint8_t* cursor;
@property unsigned rows;

@end

// -----------------------------------------------------------------------------
// Интерфейс сопряжения "Микро-80"
// -----------------------------------------------------------------------------

@interface Micro80Recorder : NSObject <SND, RD, WR>

@end

// -----------------------------------------------------------------------------
// Интерфейс клавиатуры "Микро-80"
// -----------------------------------------------------------------------------

@interface Micro80Keyboard : RKKeyboard

@end

// -----------------------------------------------------------------------------
// ПЭВМ "Микро-80"
// -----------------------------------------------------------------------------

@interface Micro80 : Computer

@property X8080 *cpu;
@property ROM *rom;
@property RAM *ram;

@property Micro80Screen *crt;

@property Micro80Recorder *snd;
@property Micro80Keyboard *kbd;

@property F806 *inpHook;
@property F80C *outHook;

@end
