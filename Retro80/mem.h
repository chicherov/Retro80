#import "x8080.h"

@interface Memory : NSObject <ReadWrite, Bytes, NSCoding>

- (id) initWithContentsOfResource:(NSString *)name mask:(uint16_t)mask;
- (id) initWithLength:(unsigned)length mask:(uint16_t)mask;

@end
