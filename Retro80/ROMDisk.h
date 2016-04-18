/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 *****/

#import "x8255.h"

@class F806;

@interface ROMDisk : X8255 <NSOpenSavePanelDelegate>

@property NSData* ROM;
@property NSURL* URL;

@property (weak) F806 *recorder;
@property BOOL tapeEmulator;

@property BOOL specialist;
@property BOOL flashDisk;
@property uint8_t MSB;

@end
