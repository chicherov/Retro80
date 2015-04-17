/*******************************************************************************
 * Интерфейс графического экрана ПЭВМ «Специалист»
 ******************************************************************************/

#import "x8080.h"

@interface SpecialistScreen : NSObject <DisplayController, WR, NSCoding>

@property uint8_t* screen;

@property BOOL isColor;
@property uint8_t color;

@end
