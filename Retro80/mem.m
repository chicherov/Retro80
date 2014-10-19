#import "mem.h"

@implementation Memory
{
	NSMutableData *memory;
	uint8_t *mutableBytes;
	NSUInteger length;

	uint16_t mask;
	BOOL readOnly;
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
	if (!readOnly)
		mutableBytes[addr & mask] = data;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) initWithContentsOfResource:(NSString*)name mask:(uint16_t)m
{
	if (self = [super init])
	{
		if ((memory = [NSMutableData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:@"bin"]]) == nil)
			return self = nil;

		if ((length = memory.length) == 0)
			return self = nil;

		mutableBytes = memory.mutableBytes;
		readOnly = TRUE;
		mask = m;
	}

	return self;
}


- (id) initWithLength:(unsigned)l mask:(uint16_t)m
{
	if (self = [super init])
	{
		if ((memory = [[NSMutableData alloc] initWithLength:l]) == nil)
			return self = nil;

		if ((length = memory.length) == 0)
			return self = nil;

		mutableBytes = memory.mutableBytes;
		readOnly = FALSE;
		mask = m;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:memory forKey:@"dump"];
	[encoder encodeBool:readOnly forKey:@"ro"];
	[encoder encodeInt:mask forKey:@"mask"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super init])
	{
		if ((memory = [decoder decodeObjectForKey:@"dump"]) == nil)
			return self = nil;

		readOnly = [decoder decodeBoolForKey:@"ro"];
		mask = [decoder decodeIntForKey:@"mask"];

		if ((length = memory.length) == 0)
			return self = nil;

		mutableBytes = memory.mutableBytes;
	}

	return self;
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
