#import "Display.h"
#import "x8080.h"

@interface TextScreen : NSObject <DisplayController, ReadWrite, HLDA, NSCoding>

@property NSObject <ReadWrite> *WR;
@property Display *display;

@end
