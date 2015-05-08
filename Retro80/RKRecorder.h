#import "x8080.h"

// -----------------------------------------------------------------------------
// F806 - Ввод байта с магнитофона
// -----------------------------------------------------------------------------

@interface F806 : NSObject <Adjustment, RD>
{
	NSOpenPanel *panel;
	BOOL cancel;
}

- (id) initWithX8080:(X8080 *)cpu;

- (void) openPanel;
- (void) open;

@property (weak) X8080 *cpu;
@property NSObject<RD> *mem;
@property NSObject<SoundController> *snd;

@property NSString *extension;
@property unsigned type;

@property NSData *buffer;
@property NSUInteger pos;

@end

// -----------------------------------------------------------------------------
// F80C - Вывод байта на магнитофон
// -----------------------------------------------------------------------------

@interface F80C : NSObject <Adjustment, RD>
{
	NSTimeInterval last;
}

- (id) initWithX8080:(X8080 *)cpu;

- (void) save;

@property (weak) X8080 *cpu;
@property NSObject<RD> *mem;

@property NSString *extension;
@property unsigned type;

@property NSMutableData *buffer;

@end
