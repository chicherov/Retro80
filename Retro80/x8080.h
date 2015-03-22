/*******************************************************************************
 Микропроцессор КР580ВМ80А (8080A)
 ******************************************************************************/

#import "Retro80.h"

@protocol ReadWrite <NSObject>
- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status;
- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock;
@end

@protocol Reset <NSObject>
- (void) RESET;
@end

@protocol Bytes <NSObject>
- (uint8_t *) mutableBytesAtAddress:(uint16_t)addr;
- (const uint8_t *) bytesAtAddress:(uint16_t)addr;
@end

@class X8080;

@protocol Hook <NSObject>
- (int) execute:(X8080*)cpu;
@end

@protocol HLDA <NSObject>
- (unsigned) HLDA:(uint64_t)clock WR:(BOOL)wr;
@end

@protocol INTE <NSObject>
- (void) INTE:(BOOL)IF;
@end

@protocol INTA <NSObject>
- (uint8_t) INTA;
@end

// -----------------------------------------------------------------------------
// X8080 - Базовый класс компьютера с процесором i8080
// -----------------------------------------------------------------------------

@interface X8080 : NSObject <Processor, NSCoding>

@property (weak) NSObject<HLDA> *HLDA;
@property (weak) NSObject<INTE> *INTE;
@property (weak) NSObject<INTA> *INTA;
@property BOOL INTR;

@property uint32_t quartz;
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

- (id) initWithQuartz:(uint32_t)quartz;

// -----------------------------------------------------------------------------

- (void) mapObject:(NSObject<ReadWrite>*)object
			atPage:(uint8_t)page
			  from:(uint16_t)from
				to:(uint16_t)to;

- (void) mapObject:(NSObject<ReadWrite>*)object
			atPage:(uint8_t)page
			  from:(uint16_t)from
				to:(uint16_t)to
				RO:(BOOL)ro;

- (void) mapObject:(NSObject<ReadWrite>*)object
			atPage:(uint8_t)page
			  from:(uint16_t)from
				to:(uint16_t)to
				WO:(BOOL)wo;

// -----------------------------------------------------------------------------

- (void) mapObject:(NSObject<ReadWrite>*)object
				from:(uint16_t)from
				to:(uint16_t)to;

- (void) mapObject:(NSObject<ReadWrite>*)object
			  from:(uint16_t)from
				to:(uint16_t)to
				RO:(BOOL)ro;

- (void) mapObject:(NSObject<ReadWrite>*)object
			  from:(uint16_t)from
				to:(uint16_t)to
				WO:(BOOL)ro;

// -----------------------------------------------------------------------------

uint8_t MEMR(X8080 *cpu, uint16_t addr, uint8_t status);
void MEMW(X8080 *cpu, uint16_t addr, uint8_t data);

// -----------------------------------------------------------------------------

- (void) mapObject:(NSObject<ReadWrite>*)object
			atPort:(uint8_t)port
			 count:(unsigned)count;

- (void) mapObject:(NSObject<ReadWrite>*)object
			atPort:(uint8_t)port;

// -----------------------------------------------------------------------------

uint8_t IOR(X8080 *cpu, uint16_t addr, uint8_t status);
void IOW(X8080 *cpu, uint16_t addr, uint8_t data);

// -----------------------------------------------------------------------------

- (void) mapHook:(NSObject<Hook> *)object
	   atAddress:(uint16_t)addr;

// -----------------------------------------------------------------------------

- (void) execute:(uint64_t)clock;

@end
