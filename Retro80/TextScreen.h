#import "Screen.h"
#import "x8080.h"

@interface TextScreen : Screen <ReadWrite, HLDA, NSCoding>

@property NSObject <ReadWrite> *WR;

@end
