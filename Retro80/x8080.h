/*****

Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2024 Andrey Chicherov <andrey@chicherov.ru>

 *****/

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
- (unsigned) HLDA:(uint64_t)clock clk:(unsigned)clk;
@end

// -----------------------------------------------------------------------------

@protocol INTE
- (void) INTE:(BOOL)IF clock:(uint64_t)clock;
@end

// -----------------------------------------------------------------------------

@interface X8080 : NSObject <NSCoding, BYTE>

@property BOOL Z80;

@property uint64_t CLK;
@property uint8_t PAGE;

@property uint32_t START;

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

@property uint8_t RST;
@property uint8_t IM;

@property uint64_t NMI;
@property uint64_t IRQ;
@property uint32_t IRQLoop;

@property NSObject<INTE> *INTE;
@property BOOL IF, IFF2;

@property NSObject<HLDA> *HLDA;
@property uint64_t HOLD;

// -----------------------------------------------------------------------------

@property uint8_t RAMDISK;
@property BOOL M1;

@property BOOL MEMIO;
@property BOOL FF;

// -----------------------------------------------------------------------------

- (instancetype)init8080:(uint32_t)start NS_DESIGNATED_INITIALIZER;
- (instancetype)initZ80:(uint32_t)start;

#ifndef GNUSTEP
- (instancetype)init NS_UNAVAILABLE;
#endif

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

#ifdef __cplusplus
	extern "C"
	{
#endif
		void MEMW(X8080 *cpu, uint16_t addr, uint8_t data, uint64_t clock, uint8_t status);
		uint8_t MEMR(X8080 *cpu, uint16_t addr, uint64_t clock, uint8_t status);
#ifdef __cplusplus
	};
#endif

// -----------------------------------------------------------------------------

- (void) mapObject:(NSObject<RD, WR>*)object
			atPort:(uint8_t)port
			 count:(unsigned)count;

- (void) mapObject:(NSObject<RD, WR>*)object
			atPort:(uint8_t)port;

// -----------------------------------------------------------------------------

#ifdef __cplusplus
extern "C"
	{
#endif
		void IOW(X8080 *cpu, uint16_t addr, uint8_t data, uint64_t clock, uint8_t status);
		uint8_t IOR(X8080 *cpu, uint16_t addr, uint64_t clock, uint8_t status);
#ifdef __cplusplus
	};
#endif

// -----------------------------------------------------------------------------

@property uint8_t *breakpoints;
@property uint64_t BREAK;

- (BOOL)execute:(uint64_t)clock;
- (void)reset;

@end
