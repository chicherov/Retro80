/*******************************************************************************
 Микропроцессор КР580ВМ80А (8080A)
 ******************************************************************************/

#import "Retro80.h"

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

@protocol HLDA
- (unsigned) HLDA:(uint64_t)clock;
@end

@protocol IRQ
- (BOOL) IRQ:(uint64_t)clock;
@end

@protocol INTE
- (void) INTE:(BOOL)IF clock:(uint64_t)clock;
@end

// -----------------------------------------------------------------------------
// X8080 - Базовый класс компьютера с процесором i8080
// -----------------------------------------------------------------------------

@interface X8080 : NSObject <CentralProcessorUnit, Debug, NSCoding>
{
	unsigned quartz;
	BOOL Z80, WAIT;
	uint64_t CLK;

	uint8_t PAGE;

	// -------------------------------------------------------------------------
	// Регистры процессора
	// -------------------------------------------------------------------------

	uint16_t PC;
	uint16_t SP;

	union
	{
		uint16_t AF; struct
		{
			uint8_t F;
			uint8_t A;
		};

	} AF, AF1;

	union
	{
		uint16_t BC; struct
		{
			uint8_t C;
			uint8_t B;
		};

	} BC, BC1;

	union
	{
		uint16_t DE; struct
		{
			uint8_t E;
			uint8_t D;
		};

	} DE, DE1;

	union HL
	{
		uint16_t HL; struct
		{
			uint8_t L;
			uint8_t H;
		};
		
	} HL, HL1, IX, IY;

	uint8_t IR_R;
	uint8_t IR_I;

	// -------------------------------------------------------------------------
	// Сигналы NMI/IRQ
	// -------------------------------------------------------------------------

	BOOL (*CallNMI) (id, SEL, uint64_t);
	NSObject<IRQ> *NMI;

	BOOL (*CallIRQ) (id, SEL, uint64_t);
	NSObject<IRQ> *IRQ;
	uint8_t RST;
	uint8_t IM;

	// -------------------------------------------------------------------------
	// Сигнал INTE
	// -------------------------------------------------------------------------

	void (*CallINTE) (id, SEL, BOOL, uint64_t);
	NSObject<INTE> *INTE;
	BOOL IF, IFF2;

	// -------------------------------------------------------------------------
	// Сигнал HLDA
	// -------------------------------------------------------------------------

	unsigned (*CallHLDA) (id, SEL, uint64_t);
	NSObject<HLDA> *HLDA;
}

@property unsigned quartz;
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

@property NSObject<IRQ> *NMI;
@property NSObject<IRQ> *IRQ;
@property uint8_t RST;
@property uint8_t IM;

@property NSObject<INTE> *INTE;
@property BOOL IF, IFF2;

@property NSObject<HLDA> *HLDA;

// -----------------------------------------------------------------------------

- (id) initWithQuartz:(unsigned)quartz start:(uint32_t)start;
- (id) initZ80WithQuartz:(unsigned)quartz wait:(BOOL)wait start:(uint32_t)start;

// -----------------------------------------------------------------------------

@property uint8_t RAMDISK;
@property BOOL M1;

@property BOOL MEMIO;
@property BOOL FF;

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

@end
