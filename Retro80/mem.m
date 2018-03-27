/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Модули ОЗУ и ПЗУ
 
 *****/

#import "mem.h"

// =============================================================================
// MEM
// =============================================================================

@implementation MEM

@synthesize pMutableBytes;
@synthesize pLength;
@synthesize offset;

// -----------------------------------------------------------------------------

- (MEM *) memoryAtOffest:(NSUInteger)off mask:(uint16_t)msk
{
    MEM *mem; if ((mem = [[MEM alloc] init]))
    {
        mem->pMutableBytes = pMutableBytes;
        mem->pLength = pLength;
        
        mem->offset = off;
        mem->mask = msk;
    }

    return mem;
}

- (MEM *) memoryAtOffest:(NSUInteger)off
{
    return [self memoryAtOffest:off mask:0xFFFF];
}

// -----------------------------------------------------------------------------

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
    if (offset + (addr & mask) < *pLength)
        *data = (*pMutableBytes) [offset + (addr & mask)];
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
    if (offset + (addr & mask) < *pLength)
        (*pMutableBytes) [offset + (addr & mask)] = data;
}

- (uint8_t *) BYTE:(uint16_t)addr
{
    if (offset + (addr & mask) < *pLength)
        return *pMutableBytes + offset + (addr & mask);
    else
        return NULL;
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

@synthesize mutableBytes;

// -----------------------------------------------------------------------------

- (id) initWithLength:(unsigned)len mask:(uint16_t)msk
{
    if (self = [super init])
    {
        if ((mutableData = [[NSMutableData alloc] initWithLength:len]) == nil)
            return self = nil;
        
        if ((mutableBytes = mutableData.mutableBytes) == nil)
            return self = nil;

        if ((length = mutableData.length) != len)
            return self = nil;
        
        pMutableBytes = &mutableBytes;
        pLength = &length;
        
        offset = 0;
        mask = msk;
    }
    
    return self;
}

- (id) initWithLength:(unsigned)len
{
    return [self initWithLength:len mask:0xFFFF];
}

// -----------------------------------------------------------------------------

- (void) setLength:(NSUInteger)newLength
{
    length = mutableData.length = newLength;
    mutableBytes = mutableData.mutableBytes;
}

- (NSUInteger) length
{
    return length;
}

// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:mutableData forKey:@"dump"];
    [encoder encodeInteger:offset forKey:@"offset"];
    [encoder encodeInt:mask forKey:@"mask"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
    if (self = [self init])
    {
        if ((mutableData = [decoder decodeObjectForKey:@"dump"]) == nil)
            return self = nil;
        
        if ((mutableBytes = mutableData.mutableBytes) == nil)
            return self = nil;
        
        length = mutableData.length;
        
        pMutableBytes = &mutableBytes;
        pLength = &length;

        offset = [decoder decodeIntegerForKey:@"offset"];
        mask = [decoder decodeIntForKey:@"mask"];
    }
    
    return self;
}

@end

// =============================================================================
// ROM
// =============================================================================

@implementation ROM

- (id) initWithContentsOfResource:(NSString*)name mask:(uint16_t)msk
{
	return [self initWithData:[NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:@"bin"]] mask:msk];
}

- (id) initWithData:(NSData *)data mask:(uint16_t)msk
{
	if (self = [super init])
	{
		if ((mutableData = [NSMutableData dataWithData:data]) == nil)
			return self = nil;

        if ((mutableBytes = mutableData.mutableBytes) == nil)
            return self = nil;
        
        if ((length = mutableData.length) == 0)
            return self = nil;
        
        pMutableBytes = &mutableBytes;
        pLength = &length;
        
        offset = 0;
        mask = msk;
	}

	return self;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	*data = 0xFF; [super RD:addr data:data CLK:clock];
}

@end
