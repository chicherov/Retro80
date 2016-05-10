/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Контроллер прямого доступа к памяти КР580ВТ57 (8257)

 *****/

#import "x8080.h"

// -----------------------------------------------------------------------------

@protocol DMA <NSObject>

- (void) RD:(uint8_t *)data clock:(uint64_t)clock;
- (void) WR:(uint8_t)data clock:(uint64_t)clock;

- (uint64_t *) DRQ;

@end

// -----------------------------------------------------------------------------

@interface X8257 : NSObject <RD, WR, HLDA, NSCoding>

- (void) setHLDA:(NSObject<HLDA> *)object;

- (void) setDMA0:(NSObject<DMA> *)object;
- (void) setDMA1:(NSObject<DMA> *)object;
- (void) setDMA2:(NSObject<DMA> *)object;
- (void) setDMA3:(NSObject<DMA> *)object;

@property (weak) X8080* cpu;
@property unsigned tick;

@end
