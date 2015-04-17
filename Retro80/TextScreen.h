#import "Display.h"
#import "x8080.h"

@interface TextScreen : NSObject <DisplayController, WR, NSCoding>

@property NSObject <WR> *WR;
@property Display *display;

@end
