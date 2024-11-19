/*****

Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2024 Andrey Chicherov <andrey@chicherov.ru>

 *****/

#include "cpu80.h"
#import "x8080.h"
#import "Dbg80.h"

@implementation X8080
{
	CPU *cpu;

	// -------------------------------------------------------------------------
	// Сигнал INTE
	// -------------------------------------------------------------------------

	void (*CallINTE) (id, SEL, BOOL, uint64_t);
	NSObject<INTE> *INTE;

	// -------------------------------------------------------------------------
	// Сигнал HLDA
	// -------------------------------------------------------------------------

	unsigned (*CallHLDA) (id, SEL, uint64_t, unsigned);
	NSObject<HLDA> *HLDA;

	// -------------------------------------------------------------------------
	// Адресная шина
	// -------------------------------------------------------------------------

	NSObject<RD> *RD[16][0x10000];
	NSObject<WR> *WR[16][0x10000];
	NSObject<RD, WR> *IO[256];

	void (*CallRD [16][0x10000]) (id, SEL, uint16_t, uint8_t *, uint64_t);
	void (*CallWR [16][0x10000]) (id, SEL, uint16_t, uint8_t, uint64_t);

	void (*CallIOR [256]) (id, SEL, uint16_t, uint8_t *, uint64_t);
	void (*CallIOW [256]) (id, SEL, uint16_t, uint8_t, uint64_t);
}

// -----------------------------------------------------------------------------
// Hardware Abstraction Layer
// -----------------------------------------------------------------------------

class Core: public ICore
{
	__weak X8080 *cpu8080;

public:

	void MEMW(uint16_t addr, uint8_t data, uint8_t status) override
	{
		return ::MEMW(cpu8080, addr, data, CLOCK, status);
	}

	uint8_t MEMR(uint16_t addr, uint8_t status) override
	{
		return ::MEMR(cpu8080, addr, CLOCK, status);
	}

	void IOW(uint16_t addr, uint8_t data, uint8_t status) override
	{
		return ::IOW(cpu8080, addr, data, CLOCK, status);
	}

	uint8_t IOR(uint16_t addr, uint8_t status) override
	{
		return ::IOR(cpu8080, addr, CLOCK, status);
	}

	uint8_t INTA(uint16_t addr, uint8_t status) override
	{
		return cpu8080.RST;
	}

	bool HLDA(bool write) override
	{
		if(cpu8080->HLDA)
		{
			if(auto clock = cpu8080->CallHLDA(cpu8080->HLDA, @selector(HLDA:clk:), CLOCK - 9, write ? 18 : 9))
			{
				CLOCK += clock - 9;
				return true;
			}
		}

		return false;
	}

	void INTE(bool value) override
	{
		if(cpu8080->INTE)
			cpu8080->CallINTE(cpu8080->INTE, @selector(INTE:clock:), value, CLOCK);
	}

	explicit Core(X8080 *cpu8080): cpu8080(cpu8080)
	{

	}
};

// -----------------------------------------------------------------------------
// Доступ к регистрам процессора
// -----------------------------------------------------------------------------

@synthesize START;
@synthesize PAGE;

- (void) setZ80:(BOOL)value
{
	cpu->m_cpuType = value ? CPU::Type::Z80 : CPU::Type::I8080;
}

- (uint64_t) CLK
{
	return cpu->m_core->CLOCK;
}

- (void) setCLK:(uint64_t)value
{
	cpu->m_core->CLOCK = value;
}

- (BOOL) Z80
{
	return (BOOL) (cpu->m_cpuType == CPU::Type::Z80);
}

- (void) setPC:(uint16_t)value { cpu->PC = value; }
- (uint16_t) PC { return cpu->PC; }

- (void) setSP:(uint16_t)value { cpu->SP = value; }
- (uint16_t) SP { return cpu->SP; }

- (void) setAF:(uint16_t)value { cpu->AF = value; }
- (uint16_t) AF { return cpu->AF; }

- (void) setA:(uint8_t)value { cpu->A = value; }
- (uint8_t) A { return cpu->A; }

- (void) setF:(uint8_t)value { cpu->F = value; }
- (uint8_t) F { return cpu->F; }

- (void) setBC:(uint16_t)value { cpu->BC = value; }
- (uint16_t) BC { return cpu->BC; }

- (void) setB:(uint8_t)value { cpu->B = value; }
- (uint8_t) B { return cpu->B; }

- (void) setC:(uint8_t)value { cpu->C = value; }
- (uint8_t) C { return cpu->C; }

- (void) setDE:(uint16_t)value { cpu->DE = value; }
- (uint16_t) DE { return cpu->DE; }

- (void) setD:(uint8_t)value { cpu->D = value; }
- (uint8_t) D { return cpu->D; }

- (void) setE:(uint8_t)value { cpu->E = value; }
- (uint8_t) E { return cpu->E; }

- (void) setHL:(uint16_t)value { cpu->HL = value; }
- (uint16_t) HL { return cpu->HL; }

- (void) setH:(uint8_t)value { cpu->H = value; }
- (uint8_t) H { return cpu->H; }

- (void) setL:(uint8_t)value { cpu->L = value; }
- (uint8_t) L { return cpu->L; }

- (void) setIF:(BOOL)value { cpu->IF = value; }
- (BOOL) IF { return cpu->IF; }

- (void) setIFF2:(BOOL)value { cpu->IFF2 = value; }
- (BOOL) IFF2 { return cpu->IFF2; }

- (void) setAF1:(uint16_t)value { cpu->AF1 = value; }
- (uint16_t) AF1 { return cpu->AF1; }

- (void) setA1:(uint8_t)value { cpu->A1 = value; }
- (uint8_t) A1 { return cpu->A1; }

- (void) setF1:(uint8_t)value { cpu->F1 = value; }
- (uint8_t) F1 { return cpu->F1; }

- (void) setBC1:(uint16_t)value { cpu->BC1 = value; }
- (uint16_t) BC1 { return cpu->BC1; }

- (void) setB1:(uint8_t)value { cpu->B1 = value; }
- (uint8_t) B1 { return cpu->B1; }

- (void) setC1:(uint8_t)value { cpu->C1 = value; }
- (uint8_t) C1 { return cpu->C1; }

- (void) setDE1:(uint16_t)value { cpu->DE1 = value; }
- (uint16_t) DE1 { return cpu->DE1; }

- (void) setD1:(uint8_t)value { cpu->D1 = value; }
- (uint8_t) D1 { return cpu->D1; }

- (void) setE1:(uint8_t)value { cpu->E1 = value; }
- (uint8_t) E1 { return cpu->E1; }

- (void) setHL1:(uint16_t)value { cpu->HL1 = value; }
- (uint16_t) HL1 { return cpu->HL1; }

- (void) setH1:(uint8_t)value { cpu->H1 = value; }
- (uint8_t) H1 { return cpu->H1; }

- (void) setL1:(uint8_t)value { cpu->L1 = value; }
- (uint8_t) L1 { return cpu->L1; }

- (void) setIX:(uint16_t)value { cpu->IX = value; }
- (uint16_t) IX { return cpu->IX; }

- (void) setIXH:(uint8_t)value { cpu->IXH = value; }
- (uint8_t) IXH { return cpu->IXH; }

- (void) setIXL:(uint8_t)value { cpu->IXL = value; }
- (uint8_t) IXL { return cpu->IXL; }

- (void) setIY:(uint16_t)value { cpu->IY = value; }
- (uint16_t) IY { return cpu->IY; }

- (void) setIYH:(uint8_t)value { cpu->IYH = value; }
- (uint8_t) IYH { return cpu->IYH; }

- (void) setIYL:(uint8_t)value { cpu->IYL = value; }
- (uint8_t) IYL { return cpu->IYL; }

- (void) setR:(uint8_t)value { cpu->R = value; }
- (uint8_t) R { return cpu->R; }

- (void) setI:(uint8_t)value { cpu->I = value; }
- (uint8_t) I { return cpu->I; }

@synthesize RST;

- (void) setIM:(uint8_t)value { cpu->IM = value; }
- (uint8_t) IM { return cpu->IM; }

- (void) setNMI:(uint64_t)value { cpu->m_core->NMI = value; }
- (uint64_t) NMI { return cpu->m_core->NMI; }

- (void) setIRQ:(uint64_t)value { cpu->m_core->IRQ = value; }
- (uint64_t) IRQ { return cpu->m_core->IRQ; }

- (void) setIRQLoop:(uint32_t)value { cpu->m_core->IRQLoop = value; }
- (uint32_t) IRQLoop { return cpu->m_core->IRQLoop; }

- (void) setHOLD:(uint64_t)value { cpu->m_core->HOLD = value; }
- (uint64_t) HOLD { return cpu->m_core->HOLD; }

// -----------------------------------------------------------------------------
// Работа с сигналом INTE
// -----------------------------------------------------------------------------

- (void) setINTE:(NSObject<INTE> *)object
{
	CallINTE = (void (*) (id, SEL, BOOL, uint64_t)) [INTE = object methodForSelector:@selector(INTE:clock:)];
}

- (NSObject<INTE> *) INTE
{
	return INTE;
}

// -----------------------------------------------------------------------------
// Работа с сигналом HLDA
// -----------------------------------------------------------------------------

- (void) setHLDA:(NSObject<HLDA> *)object
{
	CallHLDA = (unsigned (*) (id, SEL, uint64_t, unsigned)) [HLDA = object methodForSelector:@selector(HLDA:clk:)];
}

- (NSObject<HLDA> *)HLDA
{
	return HLDA;
}

// -----------------------------------------------------------------------------
// Доступ к адресному пространству
// -----------------------------------------------------------------------------

@synthesize RAMDISK;
@synthesize M1;

@synthesize MEMIO;
@synthesize FF;

- (void) mapObject:(NSObject<RD> *)rd atPage:(uint8_t)page from:(uint16_t)from to:(uint16_t)to WR:(NSObject<WR> *)wr
{
	void (*rdCall) (id, SEL, uint16_t, uint8_t *, uint64_t) = 0;

	if (rd)
		rdCall = (void (*) (id, SEL, uint16_t, uint8_t *, uint64_t)) [rd methodForSelector:@selector(RD:data:CLK:)];

	void (*wrCall) (id, SEL, uint16_t, uint8_t, uint64_t) = 0;

	if (wr)
		wrCall = (void (*) (id, SEL, uint16_t, uint8_t, uint64_t)) [wr methodForSelector:@selector(WR:data:CLK:)];

	for (unsigned address = from; address <= to; address++)
	{
		RD[page][address] = rd;
		CallRD[page][address] = rdCall;

		WR[page][address] = wr;
		CallWR[page][address] = wrCall;
	}
}

- (void) mapObject:(NSObject<WR> *)wr atPage:(uint8_t)page from:(uint16_t)from to:(uint16_t)to RD:(NSObject<RD> *)rd
{
	[self mapObject:rd atPage:page from:from to:to WR:wr];
}

- (void) mapObject:(NSObject<RD, WR> *)object atPage:(uint8_t)page from:(uint16_t)from to:(uint16_t)to
{
	[self mapObject:object atPage:page from:from to:to WR:object];
}

// -----------------------------------------------------------------------------

- (void) mapObject:(NSObject<RD>*)rd from:(uint16_t)from to:(uint16_t)to WR:(NSObject<WR> *)wr
{
	[self mapObject:rd atPage:0 from:from to:to WR:wr];
}

- (void) mapObject:(NSObject<WR>*)wr from:(uint16_t)from to:(uint16_t)to RD:(NSObject<RD> *)rd
{
	[self mapObject:wr atPage:0 from:from to:to RD:rd];
}

- (void) mapObject:(NSObject<RD, WR>*)object from:(uint16_t)from to:(uint16_t)to
{
	[self mapObject:object atPage:0 from:from to:to];
}

// -----------------------------------------------------------------------------

extern "C"
{
	void MEMW(X8080 *cpu, uint16_t addr, uint8_t data, uint64_t clock, uint8_t status)
	{
		uint8_t page = status == 0x04 && cpu->RAMDISK ? cpu->RAMDISK : cpu->PAGE;

		if (cpu->CallWR[page][addr])
			cpu->CallWR[page][addr](cpu->WR[page][addr], @selector(WR:data:CLK:), addr, data, clock);
	}

	uint8_t MEMR(X8080 *cpu, uint16_t addr, uint64_t clock, uint8_t status)
	{
		uint8_t data = cpu.Z80 || cpu->FF ? 0xFF : status;
		cpu->M1 = status == 0xA2;

		uint8_t page = status == 0x86 && cpu->RAMDISK ? cpu->RAMDISK : cpu->PAGE;

		if (cpu->CallRD[page][addr])
			cpu->CallRD[page][addr](cpu->RD[page][addr], @selector(RD:data:CLK:), addr, &data, clock);

		return data;
	}
}

- (uint8_t *) BYTE:(uint16_t)addr
{
	if ([RD[PAGE][addr] respondsToSelector:@selector(BYTE:)])
		return [(NSObject<BYTE> *)RD[PAGE][addr] BYTE:addr];
	else
		return NULL;
}

// -----------------------------------------------------------------------------
// Доступ к порта ввода/вывода
// -----------------------------------------------------------------------------

- (void) mapObject:(NSObject<RD, WR> *)object atPort:(uint8_t)port count:(unsigned int)count
{
	while (count--) [self mapObject:object atPort:port++];
}

- (void) mapObject:(NSObject<RD, WR> *)object atPort:(uint8_t)port
{
	IO[port] = object;
	MEMIO = NO;

	CallIOR[port] = object ? (void (*) (id, SEL, uint16_t, uint8_t *, uint64_t)) [object methodForSelector:@selector(RD:data:CLK:)] : 0;
	CallIOW[port] = object ? (void (*) (id, SEL, uint16_t, uint8_t, uint64_t)) [object methodForSelector:@selector(WR:data:CLK:)] : 0;
}

// -----------------------------------------------------------------------------

extern "C"
{
	void IOW(X8080 *cpu, uint16_t addr, uint8_t data, uint64_t clock, uint8_t status)
	{
		if(cpu->CallIOW[addr & 0xFF])
			cpu->CallIOW[addr & 0xFF](cpu->IO[addr & 0xFF], @selector(WR:data:CLK:), addr, data, clock);

		else if(cpu->MEMIO && cpu->CallWR[cpu->PAGE][cpu.Z80 ? addr = (addr & 0xFF) | ((addr & 0xFF) << 8) : addr])
			cpu->CallWR[cpu->PAGE][addr](cpu->WR[cpu->PAGE][addr], @selector(WR:data:CLK:), addr, data, clock);
	}

	uint8_t IOR(X8080 *cpu, uint16_t addr, uint64_t clock, uint8_t status)
	{
		uint8_t data = cpu.Z80 || cpu.FF ? 0xFF : status;

		if(cpu->CallIOR[addr & 0xFF])
			cpu->CallIOR[addr & 0xFF](cpu->IO[addr & 0xFF], @selector(RD:data:CLK:), addr, &data, clock);

		else if(cpu->MEMIO && cpu->CallRD[cpu->PAGE][cpu.Z80 ? addr = (addr & 0xFF) | ((addr & 0xFF) << 8) : addr])
			cpu->CallRD[cpu->PAGE][addr](cpu->RD[cpu->PAGE][addr], @selector(RD:data:CLK:), addr, &data, clock);

		return data;
	}
}

// -----------------------------------------------------------------------------
// Работа с отладчиком
// -----------------------------------------------------------------------------

- (void) setBreakpoints:(uint8_t*)value { cpu->m_breakpoints = value; }
- (uint8_t*) breakpoints { return cpu->m_breakpoints; }

- (void) setBREAK:(uint64_t)value { cpu->m_break = value; }
- (uint64_t) BREAK { return cpu->m_break; }

// -----------------------------------------------------------------------------
// reset
// -----------------------------------------------------------------------------

- (void) reset
{
	NSMutableArray *resetArray = [NSMutableArray array];

	NSObject *object = nil; for (int page = 0; page < sizeof(RD)/sizeof(RD[0]); page++)
	{
		for (unsigned addr = 0; addr < 0x10000; addr++) if (RD[page][addr] && RD[page][addr] != object)
			if ([object = RD[page][addr] respondsToSelector:@selector(RESET:)] && ![resetArray containsObject:object])
				[resetArray addObject:object];

		for (unsigned addr = 0; addr < 0x10000; addr++) if (WR[page][addr] && WR[page][addr] != object)
			if ([object = WR[page][addr] respondsToSelector:@selector(RESET:)] && ![resetArray containsObject:object])
				[resetArray addObject:object];
	}

	for (unsigned addr = 0; addr < 0x100; addr++) if (IO[addr] && IO[addr] != object)
		if ([object = IO[addr] respondsToSelector:@selector(RESET:)] && ![resetArray containsObject:object])
			[resetArray addObject:object];

	for (object in resetArray)
		[(NSObject<RESET> *)object RESET:self.CLK];

	PAGE = (START >> 16) & 0xF;
	cpu->reset(START & 0xFFFF);
}

// -----------------------------------------------------------------------------
// execute
// -----------------------------------------------------------------------------

- (BOOL) execute:(uint64_t)CLKI
{
	return cpu->execute(CLKI) ? YES : NO;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (instancetype)init8080:(uint32_t)start
{
	if (self = [super init])
	{
		cpu = new CPU(CPU::Type::I8080, new Core(self));

		MEMIO = YES;

		START = start;

		PAGE = (START >> 16) & 0xF;
		cpu->PC = START & 0xFFFF;
		RST = 0xFF;
	}

	return self;
}

- (instancetype)initZ80:(uint32_t)start
{
	if (self = [self init8080:start])
		cpu->m_cpuType = CPU::Type::Z80;

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:START forKey:@"START"];

	[encoder encodeInt64:self.CLK forKey:@"CLK"];
	[encoder encodeBool:self.IF forKey:@"IF"];

	[encoder encodeInt:PAGE forKey:@"PAGE"];

	[encoder encodeInt:self.PC forKey:@"PC"];
	[encoder encodeInt:self.SP forKey:@"SP"];
	[encoder encodeInt:self.AF forKey:@"AF"];
	[encoder encodeInt:self.BC forKey:@"BC"];
	[encoder encodeInt:self.DE forKey:@"DE"];
	[encoder encodeInt:self.HL forKey:@"HL"];

	[encoder encodeInt64:self.HOLD forKey:@"HOLD"];

	[encoder encodeInt64:self.IRQ forKey:@"IRQ"];
	[encoder encodeInt32:self.IRQLoop forKey:@"IRQLoop"];

	[encoder encodeBool:self.Z80 forKey:@"Z80"];

	if (self.Z80)
	{
		[encoder encodeBool:self.IFF2 forKey:@"IFF2"];
		[encoder encodeInt:self.IM forKey:@"IM"];

		[encoder encodeInt:self.AF1 forKey:@"AF1"];
		[encoder encodeInt:self.BC1 forKey:@"BC1"];
		[encoder encodeInt:self.DE1 forKey:@"DE1"];
		[encoder encodeInt:self.HL1 forKey:@"HL1"];

		[encoder encodeInt:self.I forKey:@"IR_I"];
		[encoder encodeInt:self.R forKey:@"IR_R"];
		[encoder encodeInt:self.IX forKey:@"IX"];
		[encoder encodeInt:self.IY forKey:@"IY"];

		[encoder encodeInt64:self.NMI forKey:@"NMI"];
	}
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self init8080:[decoder decodeIntForKey:@"START"]])
	{
		self.CLK = [decoder decodeInt64ForKey:@"CLK"];
		self.IF = [decoder decodeBoolForKey:@"IF"];

		PAGE = [decoder decodeIntForKey:@"PAGE"];

		self.PC = [decoder decodeIntForKey:@"PC"];
		self.SP = [decoder decodeIntForKey:@"SP"];
		self.AF = [decoder decodeIntForKey:@"AF"];
		self.BC = [decoder decodeIntForKey:@"BC"];
		self.DE = [decoder decodeIntForKey:@"DE"];
		self.HL = [decoder decodeIntForKey:@"HL"];

		self.HOLD = [decoder decodeInt64ForKey:@"HOLD"];

		self.IRQ = [decoder decodeInt64ForKey:@"IRQ"];
		self.IRQLoop = [decoder decodeInt32ForKey:@"IRQLoop"];

		if((self.Z80 = [decoder decodeBoolForKey:@"Z80"]))
		{
			self.IFF2 = [decoder decodeBoolForKey:@"IFF2"];
			self.IM = [decoder decodeIntForKey:@"IM"];

			self.AF1 = [decoder decodeIntForKey:@"AF1"];
			self.BC1 = [decoder decodeIntForKey:@"BC1"];
			self.DE1 = [decoder decodeIntForKey:@"DE1"];
			self.HL1 = [decoder decodeIntForKey:@"HL1"];

			self.I = [decoder decodeIntForKey:@"IR_I"];
			self.R = [decoder decodeIntForKey:@"IR_R"];
			self.IX = [decoder decodeIntForKey:@"IX"];
			self.IY = [decoder decodeIntForKey:@"IY"];

			self.NMI = [decoder decodeInt64ForKey:@"NMI"];
		}
	}

	return self;
}

// -----------------------------------------------------------------------------
// DEBUG: dealloc
// -----------------------------------------------------------------------------

- (void) dealloc
{
#ifndef NDEBUG
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
#endif
	delete cpu->m_core;
	delete cpu;
}

@end
