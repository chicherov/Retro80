/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Микро-80»

 *****/

#import "x8080.h"
#import "mem.h"

#import "Micro80Keyboard.h"
#import "Micro80Recorder.h"
#import "Micro80Screen.h"

#import "RKRecorder.h"
#import "ROMDisk.h"

// -----------------------------------------------------------------------------
// Оригинальный Микро-80
// -----------------------------------------------------------------------------

@interface Micro80 : Computer

@property X8080 *cpu;

@property ROM *rom;

@property RAM *ram;

@property Micro80Screen *crt;

@property Micro80Keyboard *kbd;

@property Micro80Recorder *snd;

@property F806 *inpHook;
@property F80C *outHook;

@end

// -----------------------------------------------------------------------------
// Микро-80 с доработками
// -----------------------------------------------------------------------------

@interface Micro80II : Micro80

@property ROMDisk *ext;

@end
