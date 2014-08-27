#import "rom.h"

@implementation ROM
{
	NSObject<ReadWrite> *WR[256];
}

- (void) mapObject:(NSObject<ReadWrite> *)object atPage:(uint8_t)page
{
	WR[page] = object;
}

- (id) initWithContentsOfResource:(NSString*)name mask:(uint16_t)mask
{
	return self = [super initWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:@"rom"]] mask:mask];
}

- (uint8_t*) mutableBytesAtAddress:(uint16_t)addr
{
	return 0;
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	uint8_t page = addr >> 8; if (WR[page])
		[WR[page] WR:addr byte:data CLK:clock];
}

@end
