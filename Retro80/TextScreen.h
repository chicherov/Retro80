#import "Display.h"
#import "x8080.h"

@interface TextScreen : NSObject <DisplayController, WR, HLDA, NSCoding>

@property NSObject <WR> *WR;
@property Display *display;

@end
