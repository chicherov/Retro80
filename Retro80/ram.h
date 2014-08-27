#import "x8080.h"

@interface RAM : NSObject <ReadWrite, Bytes, NSCoding>

- (id) initWithLength:(unsigned)length mask:(uint16_t)mask;
- (id) initWithData:(NSData *)data mask:(uint16_t)mask;

@end
