#import "ram.h"

@interface ROM : RAM

- (id) initWithContentsOfResource:(NSString *)name mask:(uint16_t)mask;

- (void) mapObject:(NSObject<ReadWrite>*)object
			atPage:(uint8_t)page;

@end
