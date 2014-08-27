#import "ram.h"

@implementation RAM
{
	NSMutableData *memory;
	uint8_t *mutableBytes;
	NSUInteger length;

	uint16_t mask;
}

- (id) initWithLength:(unsigned)len mask:(uint16_t)m
{
	if (self = [super init])
	{
		if ((memory = [[NSMutableData alloc] initWithLength:len]) == nil)
			return self = nil;

		mutableBytes = memory.mutableBytes;
		length = memory.length;
		mask = m;
	}

	return self;
}

- (id) initWithData:(NSData *)data mask:(uint16_t)m
{
	if (self = [super init])
	{
		if ((memory = [NSMutableData dataWithData:data]) == nil)
			return self = nil;

		if ((length = memory.length) == 0)
			return self = nil;

		mutableBytes = memory.mutableBytes;
		mask = m;
	}

	return self;
}

- (uint8_t *) mutableBytesAtAddress:(uint16_t)addr
{
	return mutableBytes + (addr & mask);
}

- (const uint8_t *) bytesAtAddress:(uint16_t)addr
{
	return mutableBytes + (addr & mask);
}

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	return mutableBytes[addr & mask];
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	mutableBytes[addr & mask] = data;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:memory forKey:@"dump"];
	[encoder encodeInt:mask forKey:@"mask"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	return [self initWithData:[decoder decodeObjectForKey:@"dump"]
						 mask:[decoder decodeIntForKey:@"mask"]];
}

// -----------------------------------------------------------------------------
// DEBUG: dealloc
// -----------------------------------------------------------------------------

#ifdef DEBUG
- (void) dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
