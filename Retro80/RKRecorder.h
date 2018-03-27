/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 *****/

#import "Retro80.h"

// -----------------------------------------------------------------------------
// F806 - Ввод байта с магнитофона
// -----------------------------------------------------------------------------

@interface F806 : NSObject <Enabled, RD, BYTE>
{
	NSOpenPanel *panel;
	BOOL cancel;
}

- (id) initWithX8080:(X8080 *)cpu;

- (void) openPanel;
- (void) open;

@property (weak) X8080 *cpu;
@property NSObject<RD, BYTE> *mem;
@property NSObject<SND> *snd;

@property NSString *extension;
@property unsigned type;

@property NSData *buffer;
@property NSUInteger pos;

@end

// -----------------------------------------------------------------------------
// F80C - Вывод байта на магнитофон
// -----------------------------------------------------------------------------

@interface F80C : NSObject <Enabled, RD, BYTE>
{
	NSTimeInterval last;
}

- (id) initWithX8080:(X8080 *)cpu;

- (void) save;

@property (weak) X8080 *cpu;
@property NSObject<RD, BYTE> *mem;
@property NSObject<SND> *snd;

@property NSString *extension;
@property unsigned type;

@property NSMutableData *buffer;

@end
