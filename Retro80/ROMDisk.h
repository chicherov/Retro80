#import "x8255.h"

@class F806;

@interface ROMDisk : X8255 <NSOpenSavePanelDelegate>

@property NSData* ROM;
@property NSURL* URL;

@property (weak) F806 *recorder;
@property BOOL tapeEmulator;

@property BOOL specialist;
@property BOOL flashDisk;
@property uint8_t LSB;

@end
