#import "RK86Base.h"
#import "ROMDisk.h"
#import "Floppy.h"

@interface Radio86RK : RK86Base <INTE>

@property ROMDisk *ext;

@property Floppy *floppy;
@property ROM *dos29;

@end
