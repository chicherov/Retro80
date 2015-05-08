#import "x8255.h"

@class F806;

@interface ROMDisk : X8255 <NSOpenSavePanelDelegate>

@property (readonly) const uint8_t* bytes;
@property (readonly) NSUInteger length;
@property NSURL* url;

@property (weak) F806 *recorder;
@property BOOL tapeEmulator;

@end
