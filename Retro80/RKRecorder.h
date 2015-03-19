#import "x8080.h"

// -----------------------------------------------------------------------------
// F806 - Ввод байта с магнитофона
// -----------------------------------------------------------------------------

@interface F806 : NSObject <Hook, Adjustment>

@property BOOL enabled;

- (id) initWithSound:(NSObject<SoundController> *)snd;
- (void) setData:(NSData *)data;

@property NSString *extension;
@property unsigned type;

@end

// -----------------------------------------------------------------------------
// F80C - Вывод байта на магнитофон
// -----------------------------------------------------------------------------

@interface F80C : NSObject <Hook, Adjustment>

@property BOOL enabled;

@property NSString *extension;
@property unsigned type;

@end
