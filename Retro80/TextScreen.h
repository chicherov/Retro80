#import "Screen.h"
#import "x8080.h"

@interface TextScreen : Screen <ReadWrite, HOLD, NSCoding>

- (void) mapObject:(NSObject<ReadWrite>*)object
			atPage:(uint8_t)page;

@end
