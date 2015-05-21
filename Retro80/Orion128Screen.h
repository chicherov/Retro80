/*******************************************************************************
 * Интерфейс графического экрана ПЭВМ «Орион-128»
 ******************************************************************************/

#import "x8080.h"

@interface Orion128Screen : NSObject <DisplayController, NSCoding>

@property const uint8_t* memory;

@property uint8_t color;
@property uint8_t page;

@end
