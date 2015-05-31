/*******************************************************************************
 ПЭВМ «ЮТ-88»
 ******************************************************************************/

#import "Micro80.h"

@interface UT88RAM : RAM
@property uint8_t page;
@end

@interface UT88Port40 : NSObject <RD, WR>
@property UT88RAM *ram;
@end

@interface UT88: Micro80

@property UT88Port40 *sys;
@property UT88RAM *ram;

@property BOOL isMonitor;

@end
