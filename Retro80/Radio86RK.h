/*******************************************************************************
 ПЭВМ «Радио-86РК»
 ******************************************************************************/

#import "RK86Base.h"
#import "ROMDisk.h"
#import "Floppy.h"

@interface Radio86RK8253 : X8253

@property X8255 *ext;

@end

@interface Radio86RK : RK86Base

@property Radio86RK8253 *snd;
@property ROMDisk *ext;

@property BOOL isFloppy;

@property Floppy *floppy;
@property ROM *dos29;

@end
