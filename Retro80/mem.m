#import "mem.h"

// =============================================================================
// MEM
// =============================================================================

@implementation MEM

@synthesize mutableBytes;
@synthesize length;
@synthesize mask;

// -----------------------------------------------------------------------------

- (MEM *) memoryAtOffest:(NSUInteger)offset length:(NSUInteger)len mask:(uint16_t)msk
{
	if (offset + len <= length)
		return [[MEM alloc] initWithMemory:mutableBytes + offset length:len mask:msk];
	else
		return nil;
}

// -----------------------------------------------------------------------------

- (uint8_t *) BYTE:(uint16_t)addr
{
	return (addr & mask) >= length ? NULL : mutableBytes + (addr & mask);
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if ((addr & mask) < length) *data = mutableBytes[addr & mask];
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	if ((addr & mask) < length) mutableBytes[addr & mask] = data;
}

// -----------------------------------------------------------------------------

- (id) initWithMemory:(uint8_t *)ptr length:(NSUInteger)len mask:(uint16_t)msk
{
	if (self = [super init])
	{
		mutableBytes = ptr; length = len; mask = msk;
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

// =============================================================================
// RAM
// =============================================================================

@implementation RAM
{
	NSMutableData *memory;
}

// -----------------------------------------------------------------------------

- (id) initWithLength:(unsigned)len mask:(uint16_t)msk
{
	if ((memory = [[NSMutableData alloc] initWithLength:len]) == nil || memory.length != len)
		return self = nil;

	return self = [super initWithMemory:memory.mutableBytes length:len mask:msk];
}

// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:memory forKey:@"dump"];
	[encoder encodeInt:self.mask forKey:@"mask"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if ((memory = [decoder decodeObjectForKey:@"dump"]) == nil)
		return self = nil;

	return self = [super initWithMemory:memory.mutableBytes length:memory.length mask:[decoder decodeIntForKey:@"mask"]];
}

@end

// =============================================================================
// ROM
// =============================================================================

@implementation ROM
{
	NSMutableData *memory;
}

@synthesize mutableBytes;
@synthesize length;
@synthesize mask;

// -----------------------------------------------------------------------------

- (uint8_t *) BYTE:(uint16_t)addr
{
	return (addr & mask) >= length ? NULL : mutableBytes + (addr & mask);
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	*data = (addr & mask) >= length ? 0xFF : mutableBytes[addr & mask];
}

// -----------------------------------------------------------------------------

- (id) initWithContentsOfResource:(NSString*)name mask:(uint16_t)msk
{
	if (self = [super init])
	{
		if ((memory = [NSMutableData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:@"bin"]]) == nil)
			return self = nil;

		if ((length = memory.length) == 0)
			return self = nil;

		mutableBytes = memory.mutableBytes;
		mask = msk;
	}

	return self;
}

// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:memory forKey:@"dump"];
	[encoder encodeInt:mask forKey:@"mask"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super init])
	{
		if ((memory = [decoder decodeObjectForKey:@"dump"]) == nil)
			return self = nil;

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
