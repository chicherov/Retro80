/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Центральные процессоры КР580ВМ80А (Intel 8080A) и Zilog Z80

 *****/

#import "Retro80.h"

// -----------------------------------------------------------------------------

@protocol RD
- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock;
@end

// -----------------------------------------------------------------------------

@protocol WR
- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock;
@end

// -----------------------------------------------------------------------------

@protocol BYTE
- (uint8_t *) BYTE:(uint16_t)addr;
@end

// -----------------------------------------------------------------------------

@protocol RESET
- (void) RESET:(uint64_t)clock;
@end

// -----------------------------------------------------------------------------

@protocol HLDA
- (unsigned) HLDA:(uint64_t)clock;
@end

// -----------------------------------------------------------------------------

@protocol IRQ
- (BOOL) IRQ:(uint64_t)clock;
@end

// -----------------------------------------------------------------------------

@protocol INTE
- (void) INTE:(BOOL)IF clock:(uint64_t)clock;
@end

// -----------------------------------------------------------------------------

@interface X8080 : NSObject <CPU, NSCoding, BYTE>

@property uint32_t quartz;
@property BOOL Z80, WAIT;

@property uint64_t CLK;
@property uint8_t PAGE;

@property uint16_t PC;
@property uint16_t SP;

@property uint16_t AF, AF1;
@property uint16_t BC, BC1;
@property uint16_t DE, DE1;
@property uint16_t HL, HL1;
@property uint16_t IX, IY;

@property uint8_t A, A1;
@property uint8_t F, F1;
@property uint8_t B, B1;
@property uint8_t C, C1;
@property uint8_t D, D1;
@property uint8_t E, E1;
@property uint8_t H, H1;
@property uint8_t L, L1;

@property uint8_t IXH, IXL;
@property uint8_t IYH, IYL;

@property uint8_t I;
@property uint8_t R;

@property NSObject<IRQ> *NMI;
@property NSObject<IRQ> *IRQ;
@property uint8_t RST;
@property uint8_t IM;

@property NSObject<INTE> *INTE;
@property BOOL IF, IFF2;

@property NSObject<HLDA> *HLDA;

// -----------------------------------------------------------------------------

@property uint8_t RAMDISK;
@property BOOL M1;

@property BOOL MEMIO;
@property BOOL FF;

// -----------------------------------------------------------------------------

- (id) initZ80WithQuartz:(unsigned)quartz wait:(BOOL)wait start:(uint32_t)start;

- (id) initWithQuartz:(unsigned)quartz start:(uint32_t)start;

// -----------------------------------------------------------------------------

- (void) mapObject:(NSObject<RD, WR>*)object
			atPage:(uint8_t)page
			  from:(uint16_t)from
				to:(uint16_t)to;

- (void) mapObject:(NSObject<RD, WR>*)object
			  from:(uint16_t)from
				to:(uint16_t)to;

- (void) mapObject:(NSObject<RD>*)rd
			atPage:(uint8_t)page
			  from:(uint16_t)from
				to:(uint16_t)to
				WR:(NSObject<WR>*)wr;

- (void) mapObject:(NSObject<RD>*)rd
			  from:(uint16_t)from
				to:(uint16_t)to
				WR:(NSObject<WR>*)wr;

- (void) mapObject:(NSObject<WR>*)wr
			atPage:(uint8_t)page
			  from:(uint16_t)from
				to:(uint16_t)to
				RD:(NSObject<RD>*)rd;

- (void) mapObject:(NSObject<WR>*)wr
			  from:(uint16_t)from
				to:(uint16_t)to
				RD:(NSObject<RD>*)rd;

// -----------------------------------------------------------------------------

void MEMW(X8080 *cpu, uint16_t addr, uint8_t data, uint64_t clock, uint8_t status);
uint8_t MEMR(X8080 *cpu, uint16_t addr, uint64_t clock, uint8_t status);

// -----------------------------------------------------------------------------

- (void) mapObject:(NSObject<RD, WR>*)object
			atPort:(uint8_t)port
			 count:(unsigned)count;

- (void) mapObject:(NSObject<RD, WR>*)object
			atPort:(uint8_t)port;

// -----------------------------------------------------------------------------

void IOW(X8080 *cpu, uint16_t addr, uint8_t data, uint64_t clock, uint8_t status);
uint8_t IOR(X8080 *cpu, uint16_t addr, uint64_t clock, uint8_t status);

// -----------------------------------------------------------------------------

@property uint8_t *breakpoints;
@property uint64_t BREAK;

@end
