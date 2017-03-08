/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>
 
 Модули ОЗУ и ПЗУ
 
 *****/

#import "x8080.h"

// -----------------------------------------------------------------------------
// MEM - базовый класс для RAM/ROM, так же часть памяти RAM
// -----------------------------------------------------------------------------

@interface MEM : NSObject <RD, WR, BYTE>
{
    uint8_t **pMutableBytes;
	NSUInteger *pLength;
    
    NSUInteger offset;
    uint16_t mask;
}

- (MEM *) memoryAtOffest:(NSUInteger)offset mask:(uint16_t)mask;
- (MEM *) memoryAtOffest:(NSUInteger)offset;

@property (readonly) uint8_t **pMutableBytes;
@property (readonly) NSUInteger *pLength;

@property NSUInteger offset;

@end

// -----------------------------------------------------------------------------
// RAM
// -----------------------------------------------------------------------------

@interface RAM : MEM <NSCoding>
{
    NSMutableData *mutableData;

    uint8_t *mutableBytes;
    NSUInteger length;
}

- (id) initWithLength:(unsigned)length mask:(uint16_t)mask;
- (id) initWithLength:(unsigned)length;

@property (readonly) uint8_t *mutableBytes;
@property NSUInteger length;

@end

// -----------------------------------------------------------------------------
// ROM
// -----------------------------------------------------------------------------

@interface ROM : RAM

- (id) initWithContentsOfResource:(NSString *)name mask:(uint16_t)mask;
- (id) initWithData:(NSData *)data mask:(uint16_t)mask;

@end
