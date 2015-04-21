/*******************************************************************************
 Микропроцессор КР580ВМ80А (8080A)
 ******************************************************************************/

#import "Retro80.h"

@protocol SYNC
- (void) SYNC:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock;
@end

@protocol RD
- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock;
@end

@protocol WR
- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock;
@end

@protocol BYTE
- (uint8_t *) BYTE:(uint16_t)addr;
@end

@protocol RESET
- (void) RESET;
@end

@class X8080;

@protocol Hook
- (int) execute:(X8080*)cpu;
@end

@protocol HLDA
- (unsigned) HLDA:(uint64_t)clock;
@end

@protocol INTE
- (void) INTE:(BOOL)IF clock:(uint64_t)clock;
@end

@protocol INTR
- (BOOL) INTR:(uint64_t)clock;
@end

@protocol INTA
- (uint8_t) INTA:(uint64_t)clock;
@end

// -----------------------------------------------------------------------------
// X8080 - Базовый класс компьютера с процесором i8080
// -----------------------------------------------------------------------------

@interface X8080 : NSObject <Processor, Debug, NSCoding>

- (void) setHLDA:(NSObject<HLDA> *)object;
- (void) setINTE:(NSObject<INTE> *)object;
- (void) setINTR:(NSObject<INTR> *)object;
- (void) setINTA:(NSObject<INTA> *)object;

@property unsigned quartz;
@property uint64_t CLK;

@property uint8_t PAGE;

@property uint16_t PC;
@property uint16_t SP;
@property uint16_t AF;
@property uint16_t BC;
@property uint16_t DE;
@property uint16_t HL;

@property uint8_t A;
@property uint8_t F;
@property uint8_t B;
@property uint8_t C;
@property uint8_t D;
@property uint8_t E;
@property uint8_t H;
@property uint8_t L;

@property BOOL IF;

// -----------------------------------------------------------------------------

- (id) initWithQuartz:(unsigned)quartz start:(unsigned)start;

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

- (void) addObjectToRESET:(NSObject<RESET>*)object;

@property BOOL RESET;
@property BOOL MEMIO;

// -----------------------------------------------------------------------------

uint8_t MEMR(X8080 *cpu, uint16_t addr, uint64_t clock, uint8_t data);
void MEMW(X8080 *cpu, uint16_t addr, uint8_t data, uint64_t clock);

// -----------------------------------------------------------------------------

- (void) mapObject:(NSObject<RD, WR>*)object
			atPort:(uint8_t)port
			 count:(unsigned)count;

- (void) mapObject:(NSObject<RD, WR>*)object
			atPort:(uint8_t)port;

// -----------------------------------------------------------------------------

uint8_t IOR(X8080 *cpu, uint16_t addr, uint64_t clock, uint8_t data);
void IOW(X8080 *cpu, uint16_t addr, uint8_t data, uint64_t clock);

// -----------------------------------------------------------------------------

- (void) mapHook:(NSObject<Hook> *)object
	   atAddress:(uint16_t)addr;

@end
