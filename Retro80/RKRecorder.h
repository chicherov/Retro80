#import "Retro80.h"
#import "x8080.h"

// -----------------------------------------------------------------------------
// F806 - Ввод байта с магнитофона
// -----------------------------------------------------------------------------

@interface F806 : NSObject <Hook, Adjustment>

- (id) initWithSound:(Sound *)snd;

@property NSString *extension;
@property uint16_t readError;
@property unsigned type;
@property BOOL enabled;

@end

// -----------------------------------------------------------------------------
// F80C - Вывод байта на магнитофон
// -----------------------------------------------------------------------------

@interface F80C : NSObject <Hook, Adjustment>

@property NSString *extension;
@property BOOL Micro80;
@property BOOL enabled;

@end

