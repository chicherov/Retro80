/*******************************************************************************
 Микропроцессор КР580ВМ80А (8080A)
 ******************************************************************************/

#import "x8080.h"

@implementation X8080
{
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

	void (*SyncRD [16][0x10000]) (id, SEL, uint16_t, uint8_t);
	void (*SyncWR [16][0x10000]) (id, SEL, uint16_t, uint8_t);

	void (*SyncIO [256]) (id, SEL, uint16_t, uint8_t);

	NSMutableArray *RESETLIST;
	uint32_t START;

	uint32_t STOP1;
	uint32_t STOP2;

	// -------------------------------------------------------------------------
	// Отладчик
	// -------------------------------------------------------------------------

	NSString *unicode;

	uint16_t offset;
	uint32_t lastL;
	uint32_t lastD;

	unichar dbgCmd;
	uint32_t lastM;
	uint32_t lastA;
}

// -----------------------------------------------------------------------------
// Доступ к регистрам процессора
// -----------------------------------------------------------------------------

@synthesize quartz;
@synthesize CLK;

@synthesize PAGE;

@synthesize PC;
@synthesize SP;

- (void) setAF:(uint16_t)value { AF.AF = value; }
- (uint16_t) AF { return AF.AF; }

- (void) setA:(uint8_t)value { AF.A = value; }
- (uint8_t) A { return AF.A; }

- (void) setF:(uint8_t)value { AF.F = value; }
- (uint8_t) F { return AF.F; }

- (void) setBC:(uint16_t)value { BC.BC = value; }
- (uint16_t) BC { return BC.BC; }

- (void) setB:(uint8_t)value { BC.B = value; }
- (uint8_t) B { return BC.B; }

- (void) setC:(uint8_t)value { BC.C = value; }
- (uint8_t) C { return BC.C; }

- (void) setDE:(uint16_t)value { DE.DE = value; }
- (uint16_t) DE { return DE.DE; }

- (void) setD:(uint8_t)value { DE.D = value; }
- (uint8_t) D { return DE.D; }

- (void) setE:(uint8_t)value { DE.E = value; }
- (uint8_t) E { return DE.E; }

- (void) setHL:(uint16_t)value { HL.HL = value; }
- (uint16_t) HL { return HL.HL; }

- (void) setH:(uint8_t)value { HL.H = value; }
- (uint8_t) H { return HL.H; }

- (void) setL:(uint8_t)value { HL.L = value; }
- (uint8_t) L { return HL.L; }

// -----------------------------------------------------------------------------
// Работа с сигналом IRQ
// -----------------------------------------------------------------------------

- (void) setIRQ:(NSObject<IRQ> *)object
{
	CallIRQ = (BOOL (*) (id, SEL, uint64_t)) [IRQ = object methodForSelector:@selector(IRQ:)];
}

- (NSObject<IRQ> *) IRQ
{
	return IRQ;
}

@synthesize RST;

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

- (void) setIF:(BOOL)value
{
	IF = value; if (INTE)
		CallINTE(INTE, @selector(INTE:clock:), IF, CLK);
}

- (BOOL) IF
{
	return IF;
}

// -----------------------------------------------------------------------------
// Работа с сигналом HLDA
// -----------------------------------------------------------------------------

- (void) setHLDA:(NSObject<HLDA> *)object
{
	CallHLDA = (unsigned (*) (id, SEL, uint64_t)) [HLDA = object methodForSelector:@selector(HLDA:)];
}

- (NSObject<HLDA> *)HLDA
{
	return HLDA;
}

static unsigned HOLD(X8080* cpu, unsigned clk)
{
	unsigned clkHOLD = cpu->HLDA ? cpu->CallHLDA(cpu->HLDA, @selector(HLDA:), cpu->CLK) : 0;
	return clk > clkHOLD ? clk : clkHOLD;
}

// -----------------------------------------------------------------------------
// Доступ к адресному пространству
// -----------------------------------------------------------------------------

@synthesize MEMIO;
@synthesize FF;

- (void) mapObject:(NSObject<RD> *)rd atPage:(uint8_t)page from:(uint16_t)from to:(uint16_t)to WR:(NSObject<WR> *)wr
{
	void (*rdCall) (id, SEL, uint16_t, uint8_t *, uint64_t) = 0;
	void (*rdSync) (id, SEL, uint16_t, uint8_t) = 0;

	if (rd)
	{
		rdCall = (void (*) (id, SEL, uint16_t, uint8_t *, uint64_t)) [rd methodForSelector:@selector(RD:data:CLK:)];

		if ([rd respondsToSelector:@selector(SYNC:status:)])
			rdSync = (void (*) (id, SEL, uint16_t, uint8_t)) [rd methodForSelector:@selector(SYNC:status:)];

		if ([rd conformsToProtocol:@protocol(RESET)] && ![RESETLIST containsObject:rd])
			[RESETLIST addObject:rd];
	}

	void (*wrCall) (id, SEL, uint16_t, uint8_t, uint64_t) = 0;
	void (*wrSync) (id, SEL, uint16_t, uint8_t) = 0;

	if (wr)
	{
		wrCall = (void (*) (id, SEL, uint16_t, uint8_t, uint64_t)) [wr methodForSelector:@selector(WR:data:CLK:)];

		if ([wr respondsToSelector:@selector(SYNC:status:)])
			wrSync = (void (*) (id, SEL, uint16_t, uint8_t)) [wr methodForSelector:@selector(SYNC:status:)];

		if ([wr conformsToProtocol:@protocol(RESET)] && ![RESETLIST containsObject:wr])
			[RESETLIST addObject:wr];
	}

	for (unsigned address = from; address <= to; address++)
	{
		RD[page][address] = rd;
		CallRD[page][address] = rdCall;
		SyncRD[page][address] = rdSync;

		WR[page][address] = wr;
		CallWR[page][address] = wrCall;
		SyncWR[page][address] = wrSync;
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

void MEMW(X8080 *cpu, uint16_t addr, uint8_t data, uint64_t clock, uint8_t status)
{
	if (cpu->SyncWR[cpu->PAGE][addr])
		cpu->SyncWR[cpu->PAGE][addr](cpu->WR[cpu->PAGE][addr], @selector(SYNC:status:), addr, status);

	if (cpu->CallWR[cpu->PAGE][addr])
		cpu->CallWR[cpu->PAGE][addr](cpu->WR[cpu->PAGE][addr], @selector(WR:data:CLK:), addr, data, clock);
}

uint8_t MEMR(X8080 *cpu, uint16_t addr, uint64_t clock, uint8_t status)
{
	if (cpu->SyncRD[cpu->PAGE][addr])
		cpu->SyncRD[cpu->PAGE][addr](cpu->RD[cpu->PAGE][addr], @selector(SYNC:status:), addr, status);

	uint8_t data = cpu->FF ? 0xFF : status;

	if (cpu->CallRD[cpu->PAGE][addr])
		cpu->CallRD[cpu->PAGE][addr](cpu->RD[cpu->PAGE][addr], @selector(RD:data:CLK:), addr, &data, clock);

	return data;
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
	MEMIO = FALSE;

	CallIOR[port] = object ? (void (*) (id, SEL, uint16_t, uint8_t *, uint64_t)) [object methodForSelector:@selector(RD:data:CLK:)] : 0;
	CallIOW[port] = object ? (void (*) (id, SEL, uint16_t, uint8_t, uint64_t)) [object methodForSelector:@selector(WR:data:CLK:)] : 0;

	if ([object respondsToSelector:@selector(SYNC:status:)])
		SyncIO[port] = (void (*) (id, SEL, uint16_t, uint8_t)) [object methodForSelector:@selector(SYNC:status:)];
	else
		SyncIO[port] = 0;
}

// -----------------------------------------------------------------------------

void IOW(X8080 *cpu, uint16_t addr, uint8_t data, uint64_t clock, uint8_t status)
{
	if (cpu->SyncIO[addr & 0xFF])
		cpu->SyncIO[addr & 0xFF](cpu->IO[addr & 0xFF], @selector(SYNC:status:), addr, status);

	if (cpu->CallIOW[addr & 0xFF])
		cpu->CallIOW[addr & 0xFF](cpu->IO[addr & 0xFF], @selector(WR:data:CLK:), addr, data, clock);

	else if (cpu->MEMIO && cpu->CallWR[cpu->PAGE][addr])
		cpu->CallWR[cpu->PAGE][addr](cpu->WR[cpu->PAGE][addr], @selector(WR:data:CLK:), addr, data, clock);
}

uint8_t IOR(X8080 *cpu, uint16_t addr, uint64_t clock, uint8_t status)
{
	if (cpu->SyncIO[addr & 0xFF])
		cpu->SyncIO[addr & 0xFF](cpu->IO[addr & 0xFF], @selector(SYNC:status:), addr, status);

	uint8_t data = cpu->FF ? 0xFF : status;

	if (cpu->CallIOR[addr & 0xFF])
		cpu->CallIOR[addr & 0xFF](cpu->IO[addr & 0xFF], @selector(RD:data:CLK:), addr, &data, clock);

	else if (cpu->MEMIO && cpu->CallRD[cpu->PAGE][addr])
		cpu->CallRD[cpu->PAGE][addr](cpu->RD[cpu->PAGE][addr], @selector(RD:data:CLK:), addr, &data, clock);

	return data;
}

// -----------------------------------------------------------------------------
// Блок работы с памятью
// -----------------------------------------------------------------------------

static unsigned timings[256] =
{
	18, 18, 18, 27, 27, 27, 18, 18, 18, 18, 18, 27, 27, 27, 18, 18,
	18, 18, 18, 27, 27, 27, 18, 18, 18, 18, 18, 27, 27, 27, 18, 18,
	18, 18, 18, 27, 27, 27, 18, 18, 18, 18, 18, 27, 27, 27, 18, 18,
	18, 18, 18, 27, 18, 18, 18, 18, 18, 18, 18, 27, 27, 27, 18, 18,

	27, 27, 27, 27, 27, 27, 18, 27, 27, 27, 27, 27, 27, 27, 18, 27,
	27, 27, 27, 27, 27, 27, 18, 27, 27, 27, 27, 27, 27, 27, 18, 27,
	27, 27, 27, 27, 27, 27, 18, 27, 27, 27, 27, 27, 27, 27, 18, 27,
	18, 18, 18, 18, 18, 18, 18, 18, 27, 27, 27, 27, 27, 27, 18, 27,

	18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
	18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
	18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
	18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,

	27, 18, 18, 18, 27, 27, 18, 27, 27, 18, 18, 18, 27, 27, 18, 27,
	27, 18, 18, 18, 27, 27, 18, 27, 27, 18, 18, 18, 27, 27, 18, 27,
	27, 18, 18, 18, 27, 27, 18, 27, 27, 18, 18, 18, 27, 27, 18, 27,
	27, 18, 18, 18, 27, 27, 18, 27, 27, 18, 18, 18, 27, 27, 18, 27
};

static uint8_t get(X8080* cpu, uint16_t addr, uint8_t status)
{
	cpu->CLK += 9; uint8_t data = MEMR(cpu, addr, cpu->CLK, status);
	cpu->CLK += 9; cpu->CLK += HOLD(cpu, 9);
	return data;
}

static void put(X8080* cpu, uint16_t addr, uint8_t data, uint8_t status)
{
	cpu->CLK += 18; MEMW(cpu, addr, data, cpu->CLK, status);
	cpu->CLK += 9; cpu->CLK += HOLD(cpu, 0);
}

static uint8_t inp(X8080* cpu, uint16_t addr)
{
	cpu->CLK += 9; uint8_t data = IOR(cpu, addr, cpu->CLK, 0x42);
	cpu->CLK += 9; cpu->CLK += HOLD(cpu, 9);
	return data;
}

static void out(X8080* cpu, uint16_t addr, uint8_t data)
{
	cpu->CLK += 18; IOW(cpu, addr, data, cpu->CLK, 0x10);
	cpu->CLK += 9; cpu->CLK += HOLD(cpu, 0);
}

// -----------------------------------------------------------------------------
// ALU
// -----------------------------------------------------------------------------

static uint8_t flags[256];

static uint8_t INR[0x100];
static uint8_t DCR[0x100];

static uint16_t RLC[0x10000];
static uint16_t RRC[0x10000];
static uint16_t RAL[0x10000];
static uint16_t RAR[0x10000];
static uint16_t DAA[0x10000];

static uint16_t ADD[0x100][0x100];
static uint16_t ADC[0x100][0x100];
static uint16_t SUB[0x100][0x100];
static uint16_t SBB[0x100][0x100];
static uint16_t AND[0x100][0x100];

+ (void) ALU
{
	if (flags[0] == 0)
	{
		for (int byte = 0x00; byte <= 0xFF; byte++)
		{
			uint8_t flag = (byte ? 0x06 : 0x46) | (byte & 0x80);

			if (byte & 0x01) flag ^= 0x04;
			if (byte & 0x02) flag ^= 0x04;
			if (byte & 0x04) flag ^= 0x04;
			if (byte & 0x08) flag ^= 0x04;
			if (byte & 0x10) flag ^= 0x04;
			if (byte & 0x20) flag ^= 0x04;
			if (byte & 0x40) flag ^= 0x04;
			if (byte & 0x80) flag ^= 0x04;

			flags[byte] = flag;
		}

		for (int byte = 0x00; byte <= 0xFF; byte++)
		{
			INR[byte] = flags[byte] | ((byte & 0x0F) == 0x00 ? 0x10 : 0x00);
			DCR[byte] = flags[byte] | ((byte & 0x0F) != 0x0F ? 0x10 : 0x00);

			for (int data = 0x00; data <= 0xFF; data++)
			{
				ADD[byte][data] = ((byte + data) << 8) | flags[(byte + data) & 0xFF] | ((byte & 0x0F) + (data & 0x0F) > 0x0F ? 0x10 : 0x00) | (byte + data > 0xFF ? 0x01 : 0x00);
				ADC[byte][data] = ((byte + data + 1) << 8) | flags[(byte + data + 1) & 0xFF] | ((byte & 0x0F) + (data & 0x0F) + 1 > 0x0F ? 0x10 : 0x00) | (byte + data + 1 > 0xFF ? 0x01 : 0x00);

				SUB[byte][data] = ((byte - data) << 8) | flags[(byte - data) & 0xFF] | ((byte & 0x0F) < (data & 0x0F) ? 0x00 : 0x10) | (byte < data ? 0x01 : 0x00);
				SBB[byte][data] = ((byte - data - 1) << 8) | flags[(byte - data - 1) & 0xFF] | ((byte & 0x0F) < (data & 0x0F) + 1 ? 0x00 : 0x10) | (byte < data + 1 ? 0x01 : 0x00);

				AND[byte][data] = ((byte & data) << 8) | flags[byte & data] | ((byte | data) & 0x08 ? 0x10 : 0x00);
			}
		}

		for (int word = 0x0000; word <= 0xFFFF; word++)
		{
			uint8_t F = word & 0xFF;
			uint8_t A = word >> 8;

			uint8_t RLC_A = (A << 1) | (A >> 7);
			uint8_t RLC_F = (F & ~1) | (RLC_A & 1);
			RLC[word] = ((RLC_A) << 8) | RLC_F;

			uint8_t RRC_F = (F & ~1) | (A & 1);
			uint8_t RRC_A = (A >> 1) | (A << 7);
			RRC[word] = ((RRC_A) << 8) | RRC_F;

			uint8_t RAL_A = (A << 1) | (F & 1);
			uint8_t RAL_F = (F & ~1) | (A >> 7);
			RAL[word] = ((RAL_A) << 8) | RAL_F;

			uint8_t RAR_A = (A >> 1) | (F << 7);
			uint8_t RAR_F = (F & ~1) | (A & 1);
			RAR[word] = ((RAR_A) << 8) | RAR_F;

			uint8_t T = ((A & 0x0F) > 0x09 || F & 0x10) ? 0x06 : 0x00;
			if (A + T > 0x9F || F & 0x01) T += 0x60;
			DAA[word] = ADD[A][T] | (F & 1);
		}
	}
}

// -----------------------------------------------------------------------------
// reset
// -----------------------------------------------------------------------------

- (void) reset
{
	for (NSObject<RESET> *object in RESETLIST)
		[object RESET];

	self.IF = FALSE;

	PAGE = (START >> 16) & 0xF;
	PC = START & 0xFFFF;
}

// -----------------------------------------------------------------------------
// execute
// -----------------------------------------------------------------------------

- (BOOL) execute:(uint64_t)CLKI
{
	while (CLK < CLKI)
	{
		union
		{
			uint16_t WZ; struct
			{
				uint8_t Z;
				uint8_t W;
			};

		} WZ;
		
		uint32_t addr = (PAGE << 16) | PC;
		if (addr == STOP1 || addr == STOP2)
			return FALSE;

		uint8_t IR; CLK += 9;

		if (IF && IRQ && CallIRQ(IRQ, @selector(IRQ:), CLK))
			IR = RST;
		else
			IR = MEMR(self, PC++, CLK, 0xA2);

		CLK += 9; CLK += HOLD(self, timings[IR]);

		switch (IR)
		{
			case 0x00:	// NOP
			case 0x08:
			case 0x10:
			case 0x18:
			case 0x20:
			case 0x28:
			case 0x30:
			case 0x38:
			{
				break;
			}

			case 0x01:	// LXI B
			{
				BC.C = get(self, PC++, 0x82);
				BC.B = get(self, PC++, 0x82);
				break;
			}

			case 0x02:	// STAX B
			{
				put(self, BC.BC, AF.A, 0x00);
				break;
			}

			case 0x03:	// INX B
			{
				BC.BC++;
				break;
			}

			case 0x04:	// INR B
			{
				AF.F = (AF.F & 0x01) | INR[++BC.B];
				break;
			}

			case 0x05:	// DCR B
			{
				AF.F = (AF.F & 0x01) | DCR[--BC.B];
				break;
			}

			case 0x06:	// MVI B
			{
				BC.B = get(self, PC++, 0x82);
				break;
			}

			case 0x07:	// RLC
			{
				AF.AF = RLC[AF.AF];
				break;
			}

			case 0x09:	// DAD B
			{
				if ((HL.HL + BC.BC) & 0x10000)
					AF.F |= 0x01;
				else
					AF.F &= 0xFE;

				HL.HL += BC.BC;
				break;
			}

			case 0x0A:	// LDAX B
			{
				AF.A = get(self, BC.BC, 0x82);
				break;
			}

			case 0x0B:	// DCX B
			{
				BC.BC--;
				break;
			}

			case 0x0C:	// INR C
			{
				AF.F = (AF.F & 0x01) | INR[++BC.C];
				break;
			}

			case 0x0D:	// DCR C
			{
				AF.F = (AF.F & 0x01) | DCR[--BC.C];
				break;
			}

			case 0x0E:	// MVI C
			{
				BC.C = get(self, PC++, 0x82);
				break;
			}

			case 0x0F:	// RRC
			{
				AF.AF = RRC[AF.AF];
				break;
			}

			case 0x11:	// LXI D
			{
				DE.E = get(self, PC++, 0x82);
				DE.D = get(self, PC++, 0x82);
				break;
			}

			case 0x12:	// STAX D
			{
				put(self, DE.DE, AF.A, 0x00);
				break;
			}

			case 0x13:	// INX D
			{
				DE.DE++;
				break;
			}

			case 0x14:	// INR D
			{
				AF.F = (AF.F & 0x01) | INR[++DE.D];
				break;
			}

			case 0x15:	// DCR D
			{
				AF.F = (AF.F & 0x01) | DCR[--DE.D];
				break;
			}

			case 0x16:	// MVI D
			{
				DE.D = get(self, PC++, 0x82);
				break;
			}

			case 0x17:	// RAL
			{
				AF.AF = RAL[AF.AF];
				break;
			}

			case 0x19:	// DAD D
			{
				if ((HL.HL + DE.DE) & 0x10000)
					AF.F |= 0x01;
				else
					AF.F &= 0xFE;

				HL.HL += DE.DE;
				break;
			}

			case 0x1A:	// LDAX D
			{
				AF.A = get(self, DE.DE, 0x82);
				break;
			}

			case 0x1B:	// DCX B
			{
				DE.DE--;
				break;
			}

			case 0x1C:	// INR E
			{
				AF.F = (AF.F & 0x01) | INR[++DE.E];
				break;
			}

			case 0x1D:	// DCR E
			{
				AF.F = (AF.F & 0x01) | DCR[--DE.E];
				break;
			}

			case 0x1E:	// MVI E
			{
				DE.E = get(self, PC++, 0x82);
				break;
			}

			case 0x1F:	// RAR
			{
				AF.AF = RAR[AF.AF];
				break;
			}

			case 0x21:	// LXI H
			{
				HL.L = get(self, PC++, 0x82);
				HL.H = get(self, PC++, 0x82);
				break;
			}

			case 0x22:	// SHLD
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);
				put(self, WZ.WZ++, HL.L, 0x00);
				put(self, WZ.WZ, HL.H, 0x00);
				break;
			}

			case 0x23:	// INX H
			{
				HL.HL++;
				break;
			}

			case 0x24:	// INR H
			{
				AF.F = (AF.F & 0x01) | INR[++HL.H];
				break;
			}

			case 0x25:	// DCR H
			{
				AF.F = (AF.F & 0x01) | DCR[--HL.H];
				break;
			}

			case 0x26:	// MVI H
			{
				HL.H = get(self, PC++, 0x82);
				break;
			}

			case 0x27:	// DAA
			{
				AF.AF = DAA[AF.AF];
				break;
			}

			case 0x29:	// DAD H
			{
				if (HL.HL & 0x8000)
					AF.F |= 0x01;
				else
					AF.F &= 0xFE;

				HL.HL <<= 1;
				break;
			}

			case 0x2A:	// LHLD
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);
				HL.L = get(self, WZ.WZ++, 0x82);
				HL.H = get(self, WZ.WZ, 0x82);
				break;
			}

			case 0x2B:	// DCX H
			{
				HL.HL--;
				break;
			}

			case 0x2C:	// INR L
			{
				AF.F = (AF.F & 0x01) | INR[++HL.L];
				break;
			}

			case 0x2D:	// DCR L
			{
				AF.F = (AF.F & 0x01) | DCR[--HL.L];
				break;
			}

			case 0x2E:	// MVI L
			{
				HL.L = get(self, PC++, 0x82);
				break;
			}

			case 0x2F:	// CMA
			{
				AF.A = ~AF.A;
				break;
			}

			case 0x31:	// LXI SP
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);
				SP = WZ.WZ;
				break;
			}

			case 0x32:	// STA
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);
				put(self, WZ.WZ, AF.A, 0x00);
				break;
			}

			case 0x33:	// INX SP
			{
				SP++;
				break;
			}

			case 0x34:	// INR M
			{
				uint8_t M = get(self, HL.HL, 0x82);
				AF.F = (AF.F & 0x01) | INR[++M];
				put(self, HL.HL, M, 0x00);
				break;
			}

			case 0x35:	// DCR M
			{
				uint8_t M = get(self, HL.HL, 0x82);
				AF.F = (AF.F & 0x01) | DCR[--M];
				put(self, HL.HL, M, 0x00);
				break;
			}

			case 0x36:	// MVI M
			{
				put(self, HL.HL, get(self, PC++, 0x82), 0x00);
				break;
			}

			case 0x37:	// STC
			{
				AF.F |= 0x01;
				break;
			}

			case 0x39:	// DAD SP
			{
				if ((HL.HL + SP) & 0x10000)
					AF.F |= 0x01;
				else
					AF.F &= 0xFE;

				HL.HL += SP;
				break;
			}

			case 0x3A:	// LDA
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);
				AF.A = get(self, WZ.WZ, 0x82);
				break;
			}

			case 0x3B:	// DCX SP
			{
				SP--;
				break;
			}

			case 0x3C:	// INR A
			{
				AF.F = (AF.F & 0x01) | INR[++AF.A];
				break;
			}

			case 0x3D:	// DCR A
			{
				AF.F = (AF.F & 0x01) | DCR[--AF.A];
				break;
			}

			case 0x3E:	// MVI A
			{
				AF.A = get(self, PC++, 0x82);
				break;
			}

			case 0x3F:	// CMC
			{
				AF.F ^= 0x01;
				break;
			}

			case 0x40:	// MOV B, B
			{
				BC.B = BC.B;
				break;
			}

			case 0x41:	// MOV B, C
			{
				BC.B = BC.C;
				break;
			}

			case 0x42:	// MOV B, D
			{
				BC.B = DE.D;
				break;
			}

			case 0x43:	// MOV B, E
			{
				BC.B = DE.E;
				break;
			}

			case 0x44:	// MOV B, H
			{
				BC.B = HL.H;
				break;
			}

			case 0x45:	// MOV B, L
			{
				BC.B = HL.L;
				break;
			}

			case 0x46:	// MOV B, M
			{
				BC.B = get(self, HL.HL, 0x82);
				break;
			}

			case 0x47:	// MOV B, A
			{
				BC.B = AF.A;
				break;
			}

			case 0x48:	// MOV C, B
			{
				BC.C = BC.B;
				break;
			}

			case 0x49:	// MOV C, C
			{
				BC.C = BC.C;
				break;
			}

			case 0x4A:	// MOV C, D
			{
				BC.C = DE.D;
				break;
			}

			case 0x4B:	// MOV C, E
			{
				BC.C = DE.E;
				break;
			}

			case 0x4C:	// MOV C, H
			{
				BC.C = HL.H;
				break;
			}

			case 0x4D:	// MOV C, L
			{
				BC.C = HL.L;
				break;
			}

			case 0x4E:	// MOV C, M
			{
				BC.C = get(self, HL.HL, 0x82);
				break;
			}

			case 0x4F:	// MOV C, A
			{
				BC.C = AF.A;
				break;
			}

			case 0x50:	// MOV D, B
			{
				DE.D = BC.B;
				break;
			}

			case 0x51:	// MOV D, C
			{
				DE.D = BC.C;
				break;
			}

			case 0x52:	// MOV D, D
			{
				DE.D = DE.D;
				break;
			}

			case 0x53:	// MOV D, E
			{
				DE.D = DE.E;
				break;
			}

			case 0x54:	// MOV D, H
			{
				DE.D = HL.H;
				break;
			}

			case 0x55:	// MOV D, L
			{
				DE.D = HL.L;
				break;
			}

			case 0x56:	// MOV D, M
			{
				DE.D = get(self, HL.HL, 0x82);
				break;
			}

			case 0x57:	// MOV D, A
			{
				DE.D = AF.A;
				break;
			}

			case 0x58:	// MOV E, B
			{
				DE.E = BC.B;
				break;
			}

			case 0x59:	// MOV E, C
			{
				DE.E = BC.C;
				break;
			}

			case 0x5A:	// MOV E, D
			{
				DE.E = DE.D;
				break;
			}

			case 0x5B:	// MOV E, E
			{
				DE.E = DE.E;
				break;
			}

			case 0x5C:	// MOV E, H
			{
				DE.E = HL.H;
				break;
			}

			case 0x5D:	// MOV E, L
			{
				DE.E = HL.L;
				break;
			}

			case 0x5E:	// MOV E, M
			{
				DE.E = get(self, HL.HL, 0x82);
				break;
			}

			case 0x5F:	// MOV E, A
			{
				DE.E = AF.A;
				break;
			}

			case 0x60:	// MOV H, B
			{
				HL.H = BC.B;
				break;
			}

			case 0x61:	// MOV H, C
			{
				HL.H = BC.C;
				break;
			}

			case 0x62:	// MOV H, D
			{
				HL.H = DE.D;
				break;
			}

			case 0x63:	// MOV H, E
			{
				HL.H = DE.E;
				break;
			}

			case 0x64:	// MOV H, H
			{
				HL.H = HL.H;
				break;
			}

			case 0x65:	// MOV H, L
			{
				HL.H = HL.L;
				break;
			}

			case 0x66:	// MOV H, M
			{
				HL.H = get(self, HL.HL, 0x82);
				break;
			}

			case 0x67:	// MOV H, A
			{
				HL.H = AF.A;
				break;
			}

			case 0x68:	// MOV L, B
			{
				HL.L = BC.B;
				break;
			}

			case 0x69:	// MOV L, C
			{
				HL.L = BC.C;
				break;
			}

			case 0x6A:	// MOV L, D
			{
				HL.L = DE.D;
				break;
			}

			case 0x6B:	// MOV L, E
			{
				HL.L = DE.E;
				break;
			}

			case 0x6C:	// MOV L, H
			{
				HL.L = HL.H;
				break;
			}

			case 0x6D:	// MOV L, L
			{
				HL.L = HL.L;
				break;
			}

			case 0x6E:	// MOV L, M
			{
				HL.L = get(self, HL.HL, 0x82);
				break;
			}

			case 0x6F:	// MOV L, A
			{
				HL.L = AF.A;
				break;
			}

			case 0x70:	// MOV M, B
			{
				put(self, HL.HL, BC.B, 0x00);
				break;
			}

			case 0x71:	// MOV M, C
			{
				put(self, HL.HL, BC.C, 0x00);
				break;
			}

			case 0x72:	// MOV M, D
			{
				put(self, HL.HL, DE.D, 0x00);
				break;
			}

			case 0x73:	// MOV M, E
			{
				put(self, HL.HL, DE.E, 0x00);
				break;
			}

			case 0x74:	// MOV M, H
			{
				put(self, HL.HL, HL.H, 0x00);
				break;
			}

			case 0x75:	// MOV M, L
			{
				put(self, HL.HL, HL.L, 0x00);
				break;
			}

			case 0x76:	// HLT
			{
				PC--;
				break;
			}

			case 0x77:	// MOV M, A
			{
				put(self, HL.HL, AF.A, 0x00);
				break;
			}

			case 0x78:	// MOV A, B
			{
				AF.A = BC.B;
				break;
			}

			case 0x79:	// MOV A, C
			{
				AF.A = BC.C;
				break;
			}

			case 0x7A:	// MOV A, D
			{
				AF.A = DE.D;
				break;
			}

			case 0x7B:	// MOV A, E
			{
				AF.A = DE.E;
				break;
			}

			case 0x7C:	// MOV A, H
			{
				AF.A = HL.H;
				break;
			}

			case 0x7D:	// MOV A, L
			{
				AF.A = HL.L;
				break;
			}

			case 0x7E:	// MOV A, M
			{
				AF.A = get(self, HL.HL, 0x82);
				break;
			}

			case 0x7F:	// MOV A, A
			{
				AF.A = AF.A;
				break;
			}

			case 0x80:	// ADD B
			{
				AF.AF = ADD[AF.A][BC.B];
				break;
			}

			case 0x81:	// ADD C
			{
				AF.AF = ADD[AF.A][BC.C];
				break;
			}

			case 0x82:	// ADD D
			{
				AF.AF = ADD[AF.A][DE.D];
				break;
			}

			case 0x83:	// ADD E
			{
				AF.AF = ADD[AF.A][DE.E];
				break;
			}

			case 0x84:	// ADD H
			{
				AF.AF = ADD[AF.A][HL.H];
				break;
			}

			case 0x85:	// ADD L
			{
				AF.AF = ADD[AF.A][HL.L];
				break;
			}

			case 0x86:	// ADD M
			{
				AF.AF = ADD[AF.A][get(self, HL.HL, 0x82)];
				break;
			}

			case 0x87:	// ADD A
			{
				AF.AF = ADD[AF.A][AF.A];
				break;
			}

			case 0x88:	// ADC B
			{
				if (AF.F & 1)
					AF.AF = ADC[AF.A][BC.B];
				else
					AF.AF = ADD[AF.A][BC.B];

				break;
			}

			case 0x89:	// ADC C
			{
				if (AF.F & 1)
					AF.AF = ADC[AF.A][BC.C];
				else
					AF.AF = ADD[AF.A][BC.C];

				break;
			}

			case 0x8A:	// ADC D
			{
				if (AF.F & 1)
					AF.AF = ADC[AF.A][DE.D];
				else
					AF.AF = ADD[AF.A][DE.D];

				break;
			}

			case 0x8B:	// ADC E
			{
				if (AF.F & 1)
					AF.AF = ADC[AF.A][DE.E];
				else
					AF.AF = ADD[AF.A][DE.E];

				break;
			}

			case 0x8C:	// ADC H
			{
				if (AF.F & 1)
					AF.AF = ADC[AF.A][HL.H];
				else
					AF.AF = ADD[AF.A][HL.H];

				break;
			}

			case 0x8D:	// ADC L
			{
				if (AF.F & 1)
					AF.AF = ADC[AF.A][HL.L];
				else
					AF.AF = ADD[AF.A][HL.L];

				break;
			}

			case 0x8E:	// ADC M
			{
				if (AF.F & 1)
					AF.AF = ADC[AF.A][get(self, HL.HL, 0x82)];
				else
					AF.AF = ADD[AF.A][get(self, HL.HL, 0x82)];

				break;
			}

			case 0x8F:	// ADC A
			{
				if (AF.F & 1)
					AF.AF = ADC[AF.A][AF.A];
				else
					AF.AF = ADD[AF.A][AF.A];

				break;
			}

			case 0x90:	// SUB B
			{
				AF.AF = SUB[AF.A][BC.B];
				break;
			}

			case 0x91:	// SUB C
			{
				AF.AF = SUB[AF.A][BC.C];
				break;
			}

			case 0x92:	// SUB D
			{
				AF.AF = SUB[AF.A][DE.D];
				break;
			}

			case 0x93:	// SUB E
			{
				AF.AF = SUB[AF.A][DE.E];
				break;
			}

			case 0x94:	// SUB H
			{
				AF.AF = SUB[AF.A][HL.H];
				break;
			}

			case 0x95:	// SUB L
			{
				AF.AF = SUB[AF.A][HL.L];
				break;
			}

			case 0x96:	// SUB M
			{
				AF.AF = SUB[AF.A][get(self, HL.HL, 0x82)];
				break;
			}

			case 0x97:	// SUB A
			{
				AF.AF = SUB[AF.A][AF.A];
				break;
			}

			case 0x98:	// SBB B
			{
				if (AF.F & 1)
					AF.AF = SBB[AF.A][BC.B];
				else
					AF.AF = SUB[AF.A][BC.B];

				break;
			}

			case 0x99:	// SBB C
			{
				if (AF.F & 1)
					AF.AF = SBB[AF.A][BC.C];
				else
					AF.AF = SUB[AF.A][BC.C];

				break;
			}

			case 0x9A:	// SBB D
			{
				if (AF.F & 1)
					AF.AF = SBB[AF.A][DE.D];
				else
					AF.AF = SUB[AF.A][DE.D];

				break;
			}

			case 0x9B:	// SBB E
			{
				if (AF.F & 1)
					AF.AF = SBB[AF.A][DE.E];
				else
					AF.AF = SUB[AF.A][DE.E];

				break;
			}

			case 0x9C:	// SBB H
			{
				if (AF.F & 1)
					AF.AF = SBB[AF.A][HL.H];
				else
					AF.AF = SUB[AF.A][HL.H];

				break;
			}

			case 0x9D:	// SBB L
			{
				if (AF.F & 1)
					AF.AF = SBB[AF.A][HL.L];
				else
					AF.AF = SUB[AF.A][HL.L];

				break;
			}

			case 0x9E:	// SBB M
			{
				if (AF.F & 1)
					AF.AF = SBB[AF.A][get(self, HL.HL, 0x82)];
				else
					AF.AF = SUB[AF.A][get(self, HL.HL, 0x82)];

				break;
			}

			case 0x9F:	// SBB A
			{
				if (AF.F & 1)
					AF.AF = SBB[AF.A][AF.A];
				else
					AF.AF = SUB[AF.A][AF.A];

				break;
			}

			case 0xA0:	// ANA B
			{
				AF.AF = AND[AF.A][BC.B];
				break;
			}

			case 0xA1:	// ANA C
			{
				AF.AF = AND[AF.A][BC.C];
				break;
			}

			case 0xA2:	// ANA D
			{
				AF.AF = AND[AF.A][DE.D];
				break;
			}

			case 0xA3:	// ANA E
			{
				AF.AF = AND[AF.A][DE.E];
				break;
			}

			case 0xA4:	// ANA H
			{
				AF.AF = AND[AF.A][HL.H];
				break;
			}

			case 0xA5:	// ANA L
			{
				AF.AF = AND[AF.A][HL.L];
				break;
			}

			case 0xA6:	// ANA M
			{
				AF.AF = AND[AF.A][get(self, HL.HL, 0x82)];
				break;
			}

			case 0xA7:	// ANA A
			{
				AF.AF = AND[AF.A][AF.A];
				break;
			}

			case 0xA8:	// XRA B
			{
				AF.F = flags[AF.A ^= BC.B];
				break;
			}

			case 0xA9:	// XRA C
			{
				AF.F = flags[AF.A ^= BC.C];
				break;
			}

			case 0xAA:	// XRA D
			{
				AF.F = flags[AF.A ^= DE.D];
				break;
			}

			case 0xAB:	// XRA E
			{
				AF.F = flags[AF.A ^= DE.E];
				break;
			}

			case 0xAC:	// XRA H
			{
				AF.F = flags[AF.A ^= HL.H];
				break;
			}

			case 0xAD:	// XRA L
			{
				AF.F = flags[AF.A ^= HL.L];
				break;
			}

			case 0xAE:	// XRA M
			{
				AF.F = flags[AF.A ^= get(self, HL.HL, 0x82)];
				break;
			}

			case 0xAF:	// XRA A
			{
				AF.F = flags[AF.A ^= AF.A];
				break;
			}

			case 0xB0:	// ORA B
			{
				AF.F = flags[AF.A |= BC.B];
				break;
			}

			case 0xB1:	// ORA C
			{
				AF.F = flags[AF.A |= BC.C];
				break;
			}

			case 0xB2:	// ORA D
			{
				AF.F = flags[AF.A |= DE.D];
				break;
			}

			case 0xB3:	// ORA E
			{
				AF.F = flags[AF.A |= DE.E];
				break;
			}

			case 0xB4:	// ORA H
			{
				AF.F = flags[AF.A |= HL.H];
				break;
			}

			case 0xB5:	// ORA L
			{
				AF.F = flags[AF.A |= HL.L];
				break;
			}

			case 0xB6:	// ORA M
			{
				AF.F = flags[AF.A |= get(self, HL.HL, 0x82)];
				break;
			}

			case 0xB7:	// ORA A
			{
				AF.F = flags[AF.A];
				break;
			}

			case 0xB8:	// CMP B
			{
				AF.F = SUB[AF.A][BC.B];
				break;
			}

			case 0xB9:	// CMP C
			{
				AF.F = SUB[AF.A][BC.C];
				break;
			}

			case 0xBA:	// CMP D
			{
				AF.F = SUB[AF.A][DE.D];
				break;
			}

			case 0xBB:	// CMP E
			{
				AF.F = SUB[AF.A][DE.E];
				break;
			}

			case 0xBC:	// CMP H
			{
				AF.F = SUB[AF.A][HL.H];
				break;
			}

			case 0xBD:	// CMP L
			{
				AF.F = SUB[AF.A][HL.L];
				break;
			}

			case 0xBE:	// CMP M
			{
				AF.F = SUB[AF.A][get(self, HL.HL, 0x82)];
				break;
			}

			case 0xBF:	// CMP A
			{
				AF.F = SUB[AF.A][AF.A];
				break;
			}

			case 0xC0:	// RNZ
			{
				if ((AF.F & 0x40) == 0)
				{
					WZ.Z = get(self, SP++, 0x86);
					WZ.W = get(self, SP++, 0x86);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xC1:	// POP B
			{
				BC.C = get(self, SP++, 0x86);
				BC.B = get(self, SP++, 0x86);
				break;
			}

			case 0xC2:	// JNZ
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if ((AF.F & 0x40) == 0)
					PC = WZ.WZ;

				break;
			}

			case 0xC3:	// JMP
			case 0xCB:
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);
				PC = WZ.WZ;
				break;
			}

			case 0xC4:	// CNZ
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if ((AF.F & 0x40) == 0)
				{
					put(self, --SP, PC >> 8, 0x04);
					put(self, --SP, PC, 0x04);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xC5:	// PUSH B
			{
				put(self, --SP, BC.B, 0x04);
				put(self, --SP, BC.C, 0x04);
				break;
			}

			case 0xC6:	// ADI
			{
				AF.AF = ADD[AF.A][get(self, PC++, 0x82)];
				break;
			}

			case 0xC7:	// RST
			case 0xCF:
			case 0xD7:
			case 0xDF:
			case 0xE7:
			case 0xEF:
			case 0xF7:
			case 0xFF:
			{
				put(self, --SP, PC >> 8, 0x04);
				put(self, --SP, PC, 0x04);
				PC = IR & 0x38;
				break;
			}

			case 0xC8:	// RZ
			{
				if (AF.F & 0x40)
				{
					WZ.Z = get(self, SP++, 0x86);
					WZ.W = get(self, SP++, 0x86);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xC9:	// RET
			case 0xD9:
			{
				WZ.Z = get(self, SP++, 0x86);
				WZ.W = get(self, SP++, 0x86);
				PC = WZ.WZ;
				break;
			}

			case 0xCA:	// JZ
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if (AF.F & 0x40)
					PC = WZ.WZ;

				break;
			}

			case 0xCC:	// CZ
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if (AF.F & 0x40)
				{
					put(self, --SP, PC >> 8, 0x04);
					put(self, --SP, PC, 0x04);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xCD:	// CALL
			case 0xDD:
			case 0xED:
			case 0xFD:
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				put(self, --SP, PC >> 8, 0x04);
				put(self, --SP, PC, 0x04);
				PC = WZ.WZ;

				break;
			}

			case 0xCE:	// ACI
			{
				if (AF.F & 1)
					AF.AF = ADC[AF.A][get(self, PC++, 0x82)];
				else
					AF.AF = ADD[AF.A][get(self, PC++, 0x82)];

				break;
			}

			case 0xD0:	// RNC
			{
				if ((AF.F & 0x01) == 0)
				{
					WZ.Z = get(self, SP++, 0x86);
					WZ.W = get(self, SP++, 0x86);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xD1:	// POP D
			{
				DE.E = get(self, SP++, 0x86);
				DE.D = get(self, SP++, 0x86);
				break;
			}

			case 0xD2:	// JNC
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if ((AF.F & 0x01) == 0x00)
					PC = WZ.WZ;

				break;
			}

			case 0xD3:	// OUT
			{
				WZ.W = WZ.Z = get(self, PC++, 0x82);
				out(self, WZ.WZ, AF.A);
				break;
			}

			case 0xD4:	// CNC
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if ((AF.F & 0x01) == 0x00)
				{
					put(self, --SP, PC >> 8, 0x04);
					put(self, --SP, PC, 0x04);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xD5:	// PUSH D
			{
				put(self, --SP, DE.D, 0x04);
				put(self, --SP, DE.E, 0x04);
				break;
			}

			case 0xD6:	// SUI
			{
				AF.AF = SUB[AF.A][get(self, PC++, 0x82)];
				break;
			}

			case 0xD8:	// RC
			{
				if (AF.F & 0x01)
				{
					WZ.Z = get(self, SP++, 0x86);
					WZ.W = get(self, SP++, 0x86);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xDA:	// JC
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if (AF.F & 0x01)
					PC = WZ.WZ;

				break;
			}

			case 0xDB:	// IN
			{
				WZ.W = WZ.Z = get(self, PC++, 0x82);
				AF.A = inp(self, WZ.WZ);
				break;
			}

			case 0xDC:	// CC
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if (AF.F & 0x01)
				{
					put(self, --SP, PC >> 8, 0x04);
					put(self, --SP, PC, 0x04);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xDE:	// SBI
			{
				if (AF.F & 1)
					AF.AF = SBB[AF.A][get(self, PC++, 0x82)];
				else
					AF.AF = SUB[AF.A][get(self, PC++, 0x82)];

				break;
			}

			case 0xE0:	// RPO
			{
				if ((AF.F & 0x04) == 0)
				{
					WZ.Z = get(self, SP++, 0x86);
					WZ.W = get(self, SP++, 0x86);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xE1:	// POP H
			{
				HL.L = get(self, SP++, 0x86);
				HL.H = get(self, SP++, 0x86);
				break;
			}

			case 0xE2:	// JPO
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if ((AF.F & 0x04) == 0x00)
					PC = WZ.WZ;

				break;
			}

			case 0xE3:	// XTHL
			{
				WZ.Z = get(self, SP, 0x86);
				WZ.W = get(self, SP + 1, 0x86);
				put(self, SP + 1, HL.H, 0x04);

				uint64_t M5 = CLK + 9 * 5;
				put(self, SP, HL.L, 0x04);
				if (CLK < M5) CLK = M5;
				HL.HL = WZ.WZ;

				break;
			}

			case 0xE4:	// CPO
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if ((AF.F & 0x04) == 0x00)
				{
					put(self, --SP, PC >> 8, 0x04);
					put(self, --SP, PC, 0x04);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xE5:	// PUSH H
			{
				put(self, --SP, HL.H, 0x04);
				put(self, --SP, HL.L, 0x04);
				break;
			}

			case 0xE6:	// ANI
			{
				AF.AF = AND[AF.A][get(self, PC++, 0x82)];
				break;
			}

			case 0xE8:	// RPE
			{
				if (AF.F & 0x04)
				{
					WZ.Z = get(self, SP++, 0x86);
					WZ.W = get(self, SP++, 0x86);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xE9:	// PCHL
			{
				PC = HL.HL;
				break;
			}
				
			case 0xEA:	// JPE
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if (AF.F & 0x04)
					PC = WZ.WZ;

				break;
			}

			case 0xEB:	// XCHG
			{
				WZ.WZ = HL.HL;
				HL.HL = DE.DE;
				DE.DE = WZ.WZ;
				break;
			}

			case 0xEC:	// CPE
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if (AF.F & 0x04)
				{
					put(self, --SP, PC >> 8, 0x04);
					put(self, --SP, PC, 0x04);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xEE:	// XRI
			{
				AF.F = flags[AF.A ^= get(self, PC++, 0x82)];
				break;
			}

			case 0xF0:	// RP
			{
				if ((AF.F & 0x80) == 0)
				{
					WZ.Z = get(self, SP++, 0x86);
					WZ.W = get(self, SP++, 0x86);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xF1:	// POP PSW
			{
				AF.F = get(self, SP++, 0x86);
				AF.A = get(self, SP++, 0x86);
				break;
			}

			case 0xF2:	// JP
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if ((AF.F & 0x80) == 0x00)
					PC = WZ.WZ;

				break;
			}

			case 0xF3:	// DI
			{
				self.IF = FALSE;
				break;
			}

			case 0xF4:	// CP
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if ((AF.F & 0x80) == 0x00)
				{
					put(self, --SP, PC >> 8, 0x04);
					put(self, --SP, PC, 0x04);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xF5:	// PUSH PSW
			{
				put(self, --SP, AF.A, 0x04);
				put(self, --SP, (AF.F & 0xD7) | 0x02, 0x04);
				break;
			}

			case 0xF6:	// ORI
			{
				AF.F = flags[AF.A |= get(self, PC++, 0x82)];
				break;
			}

			case 0xF8:	// RM
			{
				if (AF.F & 0x80)
				{
					WZ.Z = get(self, SP++, 0x86);
					WZ.W = get(self, SP++, 0x86);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xF9:	// SPHL
			{
				SP = HL.HL;
				break;
			}

			case 0xFA:	// JM
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if (AF.F & 0x80)
					PC = WZ.WZ;

				break;
			}

			case 0xFB:	// EI
			{
				self.IF = TRUE;
				break;
			}

			case 0xFC:	// CM
			{
				WZ.Z = get(self, PC++, 0x82);
				WZ.W = get(self, PC++, 0x82);

				if (AF.F & 0x80)
				{
					put(self, --SP, PC >> 8, 0x04);
					put(self, --SP, PC, 0x04);
					PC = WZ.WZ;
				}

				break;
			}

			case 0xFE:	// CPI
			{
				AF.F = SUB[AF.A][get(self, PC++, 0x82)];
				break;
			}
		}
	}

	return TRUE;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) initWithQuartz:(unsigned)freq start:(unsigned int)start
{
	if (self = [self init])
	{
		[X8080 ALU];

		quartz = freq;
		START = start;

		PAGE = (START >> 16) & 0xF;
		PC = START & 0xFFFF;

		RESETLIST = [[NSMutableArray alloc] init];

		MEMIO = TRUE;

		STOP1 = -1;
		STOP2 = -1;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:quartz forKey:@"quartz"];
	[encoder encodeInt:START forKey:@"START"];

	[encoder encodeInt64:CLK forKey:@"CLK"];
	[encoder encodeBool:IF forKey:@"IF"];

	[encoder encodeInt:PAGE forKey:@"PAGE"];

	[encoder encodeInt:PC forKey:@"PC"];
	[encoder encodeInt:SP forKey:@"SP"];
	[encoder encodeInt:AF.AF forKey:@"AF"];
	[encoder encodeInt:BC.BC forKey:@"BC"];
	[encoder encodeInt:DE.DE forKey:@"DE"];
	[encoder encodeInt:HL.HL forKey:@"HL"];

	[encoder encodeInt:STOP1 forKey:@"STOP1"];
	[encoder encodeInt:STOP2 forKey:@"STOP2"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [self initWithQuartz:[decoder decodeIntForKey:@"quartz"] start:[decoder decodeIntForKey:@"START"]])
	{
		CLK = [decoder decodeInt64ForKey:@"CLK"];
		IF = [decoder decodeBoolForKey:@"IF"];

		PAGE = [decoder decodeIntForKey:@"PAGE"];

		PC = [decoder decodeIntForKey:@"PC"];
		SP = [decoder decodeIntForKey:@"SP"];
		AF.AF = [decoder decodeIntForKey:@"AF"];
		BC.BC = [decoder decodeIntForKey:@"BC"];
		DE.DE = [decoder decodeIntForKey:@"DE"];
		HL.HL = [decoder decodeIntForKey:@"HL"];

		STOP1 = [decoder decodeIntForKey:@"STOP1"];
		STOP2 = [decoder decodeIntForKey:@"STOP2"];
	}

	return self;
}

// -----------------------------------------------------------------------------
// Служенные методы для отладчика
// -----------------------------------------------------------------------------

+ (NSString *) koi7
{
	return @".▘▝▀▗▚▐▜........▖▌▞▛▄▙▟█........ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_ЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧ.";
}

+ (NSString *) koi8
{
	return @".▘▝▀▗▚▐▜........▖▌▞▛▄▙▟█........ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~.................................................................юабцдефгхийклмнопярстужвьызшэщчъЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧЪ";
}

- (BOOL) addr:(uint32_t *)addr fromString:(NSString *)string
{
	NSArray *array = [string componentsSeparatedByString:@":"];
	if (array.count > 2) return FALSE;

	unsigned page = *addr >> 16; if (array.count > 1)
	{
		NSScanner *scanner = [NSScanner scannerWithString:array.firstObject];
		if (![scanner scanHexInt:&page] || scanner.scanLocation != [array.firstObject length] || page > 15) return FALSE;
	}

	unsigned temp; NSScanner *scanner = [NSScanner scannerWithString:array.lastObject];
	if (![scanner scanHexInt:&temp] || scanner.scanLocation != [array.lastObject length] || temp > 0xFFFF) return FALSE;

	*addr = (page << 16) | temp;
	return TRUE;
}

- (uint8_t *) pointerFromAddress:(uint32_t)addr
{
	return [RD[addr >> 16][addr & 0xFFFF] respondsToSelector:@selector(BYTE:)] ? [(NSObject<BYTE>*)RD[addr >> 16][addr & 0xFFFF] BYTE:addr & 0xFFFF] : 0;
}

static void inc(uint32_t *addr)
{
	(*(uint16_t *)addr)++;
}

- (uint16_t) wordFromString:(NSString *)string
{
	if (string.length > 1 && [string characterAtIndex:0] == '#')
	{
		int data; NSScanner *scanner = [NSScanner scannerWithString:[string substringFromIndex:1]];
		if (![scanner scanInt:&data] || scanner.scanLocation != string.length - 1 || data > 65535 || data < -32767)
			@throw @"Недопустимое значение";

		return data;
	}

	unsigned data; NSScanner *scanner = [NSScanner scannerWithString:string];
	if (![scanner scanHexInt:&data] || scanner.scanLocation != string.length || data > 0xFFFF)
		@throw @"Недопустимое значение";

	return data;
}

- (uint8_t) byteFromString:(NSString *)string
{
	if (string.length == 3 && [string characterAtIndex:0] == '\'' && [string characterAtIndex:2] == '\'')
	{
		NSRange range = [unicode rangeOfString:[string substringWithRange:NSMakeRange(1, 1)]];
		if (range.location == NSNotFound)
			@throw @"Недопустимое значение";

		return range.location;
	}

	if (string.length > 1 && [string characterAtIndex:0] == '#')
	{
		int data; NSScanner *scanner = [NSScanner scannerWithString:[string substringFromIndex:1]];
		if (![scanner scanInt:&data] || scanner.scanLocation != string.length - 1 || data > 255 || data < -127)
			@throw @"Недопустимое значение";

		return data;
	}

	unsigned data; NSScanner *scanner = [NSScanner scannerWithString:string];
	if (![scanner scanHexInt:&data] || scanner.scanLocation != string.length || data > 0xFF)
		@throw @"Недопустимое значение";

	return data;
}

// -----------------------------------------------------------------------------
// Данные для ассемблера/дисассемблера
// -----------------------------------------------------------------------------

static const char *rst[] =
{
	"0", "1", "2", "3", "4", "5", "6", "7", 0
};

static const char *reg[] =
{
	"B", "C", "D", "E", "H", "L", "M", "A", 0
};

static const char *push_rp[] =
{
	"B", "D", "H", "PSW", 0
};

static const char *rp[] =
{
	"B", "D", "H", "SP", 0
};

struct arg_t
{
	int type; /* 1 - next byte, 2 - next word, 3 - in opcode */

	int shift;
	int mask;

	const char **fmt;
};

struct opcode_t
{
	uint8_t cmd;
	uint8_t size;
	const char *name;
	struct arg_t arg1;
	struct arg_t arg2;

};

static struct opcode_t opcodes[] =
{
	{ 0x76, 1, "HLT" },
	{ 0x06, 2, "MVI", { 3, 3, 7, reg }, { 1 } },
	{ 0xC3, 3, "JMP", { 2 } },
	{ 0x40, 1, "MOV", { 3, 3, 7, reg }, { 3, 0, 7, reg } },
	{ 0x01, 3, "LXI", { 3, 4, 3, rp }, { 2 } },
	{ 0x32, 3, "STA", { 2 } },
	{ 0x3A, 3, "LDA", { 2 } },
	{ 0x2A, 3, "LHLD", { 2 } },
	{ 0x22, 3, "SHLD", { 2 } },
	{ 0x0A, 1, "LDAX", { 3, 4, 1, rp } },
	{ 0x02, 1, "STAX", { 3, 4, 1, rp } },
	{ 0xEB, 1, "XCHG" },
	{ 0xF9, 1, "SPHL" },
	{ 0xE3, 1, "XTHL" },
	{ 0xC5, 1, "PUSH", { 3, 4, 3, push_rp } },
	{ 0xC1, 1, "POP", { 3, 4, 3, push_rp } },
	{ 0xDB, 2, "IN", { 1 } },
	{ 0xD3, 2, "OUT", { 1 } },
	{ 0x03, 1, "INX", { 3, 4, 3, rp } },
	{ 0x0B, 1, "DCX", { 3, 4, 3, rp } },
	{ 0x04, 1, "INR", { 3, 3, 7, reg } },
	{ 0x05, 1, "DCR", { 3, 3, 7, reg } },
	{ 0x09, 1, "DAD", { 3, 4, 3, rp } },
	{ 0x2F, 1, "CMA" },
	{ 0x07, 1, "RLC" },
	{ 0x0F, 1, "RRC" },
	{ 0x17, 1, "RAL" },
	{ 0x1F, 1, "RAR" },
	{ 0xFB, 1, "EI" },
	{ 0xF3, 1, "DI" },
	{ 0x00, 1, "NOP" },
	{ 0x37, 1, "STC" },
	{ 0x3F, 1, "CMC" },
	{ 0xE9, 1, "PCHL" },
	{ 0x27, 1, "DAA" },
	{ 0xCD, 3, "CALL", { 2 } },
	{ 0xC9, 1, "RET" },
	{ 0xC7, 1, "RST", { 3, 3, 7, rst } },

	{ 0xC0, 1, "RNZ" },
	{ 0xC8, 1, "RZ" },
	{ 0xD0, 1, "RNC" },
	{ 0xD8, 1, "RC" },
	{ 0xE0, 1, "RPO" },
	{ 0xE8, 1, "RPE" },
	{ 0xF0, 1, "RP" },
	{ 0xF8, 1, "RM" },

	{ 0xC2, 3, "JNZ", { 2 } },
	{ 0xCA, 3, "JZ", { 2 } },
	{ 0xD2, 3, "JNC", { 2 } },
	{ 0xDA, 3, "JC", { 2 } },
	{ 0xE2, 3, "JPO", { 2 } },
	{ 0xEA, 3, "JPE", { 2 } },
	{ 0xF2, 3, "JP", { 2 } },
	{ 0xFA, 3, "JM", { 2 } },

	{ 0xC4, 3, "CNZ", { 2 } },
	{ 0xCC, 3, "CZ", { 2 } },
	{ 0xD4, 3, "CNC", { 2 } },
	{ 0xDC, 3, "CC", { 2 } },
	{ 0xE4, 3, "CPO", { 2 } },
	{ 0xEC, 3, "CPE", { 2 } },
	{ 0xF4, 3, "CP", { 2 } },
	{ 0xFC, 3, "CM", { 2 } },

	{ 0x80, 1, "ADD", { 3, 0, 7, reg } },
	{ 0x80|0x46, 2, "ADI", { 1 } },
	{ 0x88, 1, "ADC", { 3, 0, 7, reg } },
	{ 0x88|0x46, 2, "ACI", { 1 } },
	{ 0x90, 1, "SUB", { 3, 0, 7, reg } },
	{ 0x90|0x46, 2, "SUI", { 1 } },
	{ 0x98, 1, "SBB", { 3, 0, 7, reg } },
	{ 0x98|0x46, 2, "SBI", { 1 } },
	{ 0xA0, 1, "ANA", { 3, 0, 7, reg } },
	{ 0xA0|0x46, 2, "ANI", { 1 } },
	{ 0xA8, 1, "XRA", { 3, 0, 7, reg } },
	{ 0xA8|0x46, 2, "XRI", { 1 } },
	{ 0xB0, 1, "ORA", { 3, 0, 7, reg } },
	{ 0xB0|0x46, 2, "ORI", { 1 } },
	{ 0xB8, 1, "CMP", { 3, 0, 7, reg } },
	{ 0xB8|0x46, 2, "CPI", { 1 } },

	{ 0x08, 1, "'NOP" },
	{ 0x10, 1, "'NOP" },
	{ 0x18, 1, "'NOP" },
	{ 0x20, 1, "'NOP" },
	{ 0x28, 1, "'NOP" },
	{ 0x30, 1, "'NOP" },
	{ 0x38, 1, "'NOP" },

	{ 0xCB, 3, "'JMP", { 2 } },
	{ 0xD9, 1, "'RET" },

	{ 0xDD, 3, "'CALL", { 2 } },
	{ 0xED, 3, "'CALL", { 2 } },
	{ 0xFD, 3, "'CALL", { 2 } },

	{ 0x00, 0 }
};

// -----------------------------------------------------------------------------
// Дисассемблер
// -----------------------------------------------------------------------------

- (uint32_t) dasm:(uint32_t)addr out:(NSMutableString *)out mode:(BOOL)mode
{
	if (offset)
		[out appendFormat:@"%04X  [%04X]:  ", addr & 0xFFFF, (addr + offset) & 0xFFFF];
	else
		[out appendFormat:@"%04X:  ", addr & 0xFFFF];

	const uint8_t *ptr = [self pointerFromAddress:addr]; inc(&addr);

	if (ptr)
	{
		unichar chr0 = *ptr < unicode.length ? [unicode characterAtIndex:*ptr] : '.';

		uint8_t cmd = *ptr; for (struct opcode_t const *op = &opcodes[0]; op->size && (mode || op->name[0] != '\''); op++)
		{
			uint8_t grp = cmd & ~((op->arg1.mask << op->arg1.shift) | (op->arg2.mask << op->arg2.shift));

			if (grp == op->cmd)
			{
				NSString *byte1 = @"  "; unichar chr1 = ' '; if (op->size >= 2)
				{
					const uint8_t *ptr = [self pointerFromAddress:addr]; inc(&addr);
					byte1 = ptr ? [NSString stringWithFormat:@"%02X", *ptr] : @"??";
					chr1 = ptr && *ptr < unicode.length ? [unicode characterAtIndex:*ptr] : '.';
				}

				NSString *byte2 = @"  "; unichar chr2 = ' '; if (op->size >= 3)
				{
					const uint8_t *ptr = [self pointerFromAddress:addr]; inc(&addr);
					byte2 = ptr ? [NSString stringWithFormat:@"%02X", *ptr] : @"??";
					chr2 = ptr && *ptr < unicode.length ? [unicode characterAtIndex:*ptr] : '.';
				}

				[out appendFormat:@"%02X %@ %@  %C%C%C   %-8s", cmd, byte1, byte2, chr0, chr1, chr2, op->name];

				if (op->arg1.type == 3)
					[out appendFormat:@"%s", op->arg1.fmt[(cmd >> op->arg1.shift) & op->arg1.mask]];
				else if (op->arg1.type == 2)
					[out appendFormat:@"%@%@", byte2, byte1];
				else if (op->arg1.type == 1)
					[out appendString:byte1];

				if (op->arg2.type == 3)
					[out appendFormat:@", %s", op->arg2.fmt[(cmd >> op->arg2.shift) & op->arg2.mask]];
				else if (op->arg2.type == 2)
					[out appendFormat:@", %@%@", byte2, byte1];
				else if (op->arg2.type == 1)
					[out appendFormat:@", %@", byte1];

				[out appendString:@"\n"];
				return addr;
			}
		}

		[out appendFormat:@"%02X        %C     DB      %02X\n", *ptr, chr0, *ptr];
		return addr;
	}
	else
	{
		[out appendString:@"??        .     DS      1\n"];
		return addr;
	}
}

// -----------------------------------------------------------------------------
// dump памяти
// -----------------------------------------------------------------------------

- (uint32_t) dump:(uint32_t)addr end:(uint16_t)end out:(NSMutableString *)out
{
	NSMutableString *chr = [NSMutableString stringWithFormat:@"%*s", addr & 0xF, ""];

	if (offset)
		[out appendFormat:@"%04X  [%04X]:%*s", addr & 0xFFF0, ((addr & 0xFFF0) + offset) & 0xFFFF, (addr & 0xF) * 3 + 2, ""];
	else
		[out appendFormat:@"%04X:%*s", addr & 0xFFF0, (addr & 0xF) * 3 + 2, ""];

	do
	{
		const uint8_t *ptr = [self pointerFromAddress:addr];

		if (ptr)
		{
			[out appendFormat:@"%02X ", *ptr];

			if (*ptr < unicode.length)
				[chr appendFormat:@"%C", [unicode characterAtIndex:*ptr]];
			else
				[chr appendString:@"."];
		}
		else
		{
			[out appendString:@"?? "];
			[chr appendString:@"."];
		}

	} while ((*(uint16_t *)&addr)++ != end && addr & 0xF);

	[out appendFormat:@" %*s%@\n", (0x10 - addr & 0x0F) * 3, "", chr];

	return addr;
}

// -----------------------------------------------------------------------------
// Текущие регистры процессора
// -----------------------------------------------------------------------------

- (void) regs:(NSMutableString *)out
{
	[out appendFormat:@"A=%02X   BC=%04X DE=%04X HL=%04X SP=%04X   F=%02X (%c%c%c%c%c)   %cI", AF.A, BC.BC, DE.DE, HL.HL, SP, AF.F,
	 AF.F & 0x80 ? 'S' : '-', AF.F & 0x40 ? 'Z' : '-', AF.F & 0x10 ? 'A' : '-', AF.F & 0x04 ? 'P' : '-', AF.F & 0x01 ? 'C' : '-',
	 IF ? 'E' : 'D'
	 ];

	if (PAGE)
		[out appendFormat:@"   PAGE:%X\n", PAGE];
	else
		[out appendString:@"\n"];

	offset = 0; lastL = [self dasm:(PAGE << 16) | PC out:out mode:TRUE];
}

// -----------------------------------------------------------------------------
// Отладчик
// -----------------------------------------------------------------------------

- (NSString *) debugCommand:(NSString *)command
{
	NSMutableString *out = [[NSMutableString alloc] init];

	@try
	{
		if (command == nil)
		{
			if (unicode == nil)
				unicode = [X8080 koi7];

			[out appendString:@"\n"];
			[self regs:out];

			if ((lastD >> 16) != PAGE)
				lastD = PAGE << 16;

			if ((lastM >> 16) != PAGE)
				lastM = PAGE << 16;

			if ((lastA >> 16) != PAGE)
				lastA = PAGE << 16;

			dbgCmd = 0;

			STOP1 = -1;
			STOP2 = -1;
		}

		else if ([command isEqualToString:@"."])
		{
			dbgCmd = 0;
		}

		else if (dbgCmd == 'M')
		{
			if (command.length)
			{
				uint8_t *ptr = [self pointerFromAddress:lastM];
				if (ptr == 0) @throw @"Невозможно записать";
				*ptr = [self byteFromString:command];
			}

			inc(&lastM); const uint8_t *ptr = [self pointerFromAddress:lastM];
			return [NSString stringWithFormat:@"%04X:  %@ ", lastM & 0xFFFF, ptr ? [NSString stringWithFormat:@"%02X", *ptr] : @"??"];
		}

		else if (dbgCmd == 'A')
		{
			if (command.length != 0) @try
			{
				NSArray *array = [command componentsSeparatedByString:@" "];
				command = array.firstObject;

				for (struct opcode_t const *op = &opcodes[0]; op->size; op++) if ([[NSString stringWithFormat:@"%s", op->name] isEqualToString:command])
				{
					NSUInteger index = [array indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
						return idx && [obj length] != 0;
					}];

					if (index != NSNotFound)
						command = [[array subarrayWithRange:NSMakeRange(index, array.count - index)] componentsJoinedByString:@" "];
					else
						command = @"";

					array = [command componentsSeparatedByString:@","];

					if (array.count > 2 || (op->arg2.type == 0 && array.count > 1) || (op->arg2.type && array.count < 2) || (op->arg1.type == 0 && [array.firstObject length]) || (op->arg1.type && [array.firstObject length] == 0))
						@throw @"Неверное число аргументов";

					uint8_t cmd = op->cmd; if (op->arg1.type == 3)
					{
						NSString *arg = [array.firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
						for (unsigned i = 0;; i++) if (op->arg1.fmt[i] == 0) @throw @"Недопустимый аргумент";
						else if ([arg isEqualToString:[NSString stringWithFormat:@"%s", op->arg1.fmt[i]]])
						{
							cmd |= i << op->arg1.shift;
							break;
						}
					}

					if (op->arg2.type == 3)
					{
						NSString *arg = [array[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
						for (unsigned i = 0;; i++) if (op->arg2.fmt[i] == 0) @throw @"Недопустимый аргумент";
						else if ([arg isEqualToString:[NSString stringWithFormat:@"%s", op->arg2.fmt[i]]])
						{
							cmd |= i << op->arg2.shift;
							break;
						}
					}

					unsigned data = 0; if (op->size == 2 || op->size == 3)
					{
						NSString *arg = [array.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
						data = op->size == 2 ? [self byteFromString:arg] : [self wordFromString:arg];
					}

					uint8_t *ptr = [self pointerFromAddress:lastA];
					if (ptr == 0) @throw @"Невозможно записать";
					*ptr = cmd; inc(&lastA);

					if (op->size >= 2)
					{
						uint8_t *ptr = [self pointerFromAddress:lastA];
						if (ptr == 0) @throw @"Невозможно записать";
						*ptr = data & 0xFF; inc(&lastA);
					}

					if (op->size == 3)
					{
						uint8_t *ptr = [self pointerFromAddress:lastA];
						if (ptr == 0) @throw @"Невозможно записать";
						*ptr = data >> 8; inc(&lastA);
					}

					return [NSString stringWithFormat:@"%04X:  ", lastA & 0xFFFF];
				}

				@throw @"Недопустимый опкод";
			}

			@catch (NSString *error)
			{
				return [NSString stringWithFormat:@"%@\n%04X:  ", error, lastA & 0xFFFF];
			}
		}

		else if (dbgCmd == '1' || dbgCmd == 1)
		{
			if (command.length)
				PC = [self wordFromString:command];

			if (dbgCmd++ == 1)
				return [NSString stringWithFormat:@"  HL:  %04X ", HL.HL];
		}

		else if (dbgCmd == '2' || dbgCmd == 2)
		{
			if (command.length)
				HL.HL = [self wordFromString:command];

			if (dbgCmd++ == 2)
				return [NSString stringWithFormat:@"  BC:  %04X ", BC.BC];
		}

		else if (dbgCmd == '3' || dbgCmd == 3)
		{
			if (command.length)
				BC.BC = [self wordFromString:command];

			if (dbgCmd++ == 3)
				return [NSString stringWithFormat:@"  DE:  %04X ", DE.DE];
		}
		
		else if (dbgCmd == '4' || dbgCmd == 4)
		{
			if (command.length)
				DE.DE = [self wordFromString:command];

			if (dbgCmd++ == 4)
				return [NSString stringWithFormat:@"  SP:  %04X ", SP];
		}

		else if (dbgCmd == '5' || dbgCmd == 5)
		{
			if (command.length)
				SP = [self wordFromString:command];

			if (dbgCmd++ == 5)
				return [NSString stringWithFormat:@"  AF:  %04X ", AF.AF];
		}

		else if (dbgCmd == '6' || dbgCmd == 6)
		{
			if (command.length)
				AF.AF = [self wordFromString:command];
		}

		else if (command.length != 0)
		{
			NSArray *array = [command componentsSeparatedByString:@","];
			unichar cmd = [command characterAtIndex:0];

			if (cmd == 'L' || cmd == 'U')
			{
				if (array.count > 3)
					@throw @"Неверное число аргументов";

				uint32_t start = lastL; if ([array.firstObject length] > 1 && ![self addr:&start fromString:[array.firstObject substringFromIndex:1]])
					@throw @"Ошибка в начальном адресе";

				uint32_t org = (start & 0xF0000) | ((start + offset) & 0xFFFF); if (array.count == 3)
				{
					org = start; if ([array[2] length] && ![self addr:&org fromString:array[2]])
						@throw @"Ошибка в оригинальном адресе";
				}

				if (array.count > 1 && [array[1] length] != 0)
				{
					uint32_t end = start; if (![self addr:&end fromString:[array objectAtIndex:1]] || (end & 0xF0000) != (start & 0xF0000) || end < start)
						@throw @"Ошибка в конечном адресе";

					offset = org - start;

					lastL = start; while (lastL < end && lastL >= start)
						lastL = [self dasm:start = lastL out:out mode:cmd == 'U'];
				}

				else
				{
					offset = org - start;

					lastL = start; for (int i = 0; i < 16; i++)
						lastL = [self dasm:lastL out:out mode:cmd == 'U'];
				}
			}

			else if (cmd == 'D')
			{
				if (array.count > 3)
					@throw @"Неверное число аргументов";

				uint32_t start = lastD; if ([array.firstObject length] > 1 && ![self addr:&start fromString:[array.firstObject substringFromIndex:1]])
					@throw @"Ошибка в начальном адресе";

				uint32_t org = (start & 0xF0000) | ((start + offset) & 0xFFFF); if (array.count == 3)
				{
					org = start; if ([array[2] length] && ![self addr:&org fromString:array[2]])
						@throw @"Ошибка в оригинальном адресе";
				}

				if (array.count > 1 && [array[1] length] != 0)
				{
					uint32_t end = start; if (![self addr:&end fromString:[array objectAtIndex:1]] || (end & 0xF0000) != (start & 0xF0000) || end < start)
						@throw @"Ошибка в конечном адресе";

					offset = org - start;

					lastD = start; while (lastD < end && lastD >= start)
						lastD = [self dump:start = lastD end:end & 0xFFFF out:out];
				}

				else
				{
					offset = org - start;

					lastD = start; for (int i = 0; i < 16; i++)
						lastD = [self dump:lastD end:0xFFFF out:out];
				}
			}

			else if (cmd == 'G')
			{
				if (array.count > 3)
					@throw @"Неверное число аргументов";

				uint32_t start = (PAGE << 16) | PC;

				if ([array.firstObject length] > 1 && ([array.firstObject characterAtIndex:1] != '=' || ![self addr:&start fromString:[array.firstObject substringFromIndex:2]]))
					@throw @"Ошибка в стартовом адресе";

				uint32_t stop1 = start; if (array.count > 1 && (![self addr:&stop1 fromString:[array objectAtIndex:1]] || stop1 == start))
					@throw @"Ошибка в первом адресе останова";

				uint32_t stop2 = start; if (array.count > 2 && (![self addr:&stop2 fromString:[array objectAtIndex:2]] || stop2 == start))
					@throw @"Ошибка во втором адресе останова";

				STOP1 = stop1 == start ? -1 : stop1;
				STOP2 = stop2 == start ? -1 : stop2;
				PC = start & 0xFFFF;
				PAGE = start >> 16;
				return nil;
			}

			else if (cmd == 'Q')
			{
				if (array.count > 1 || [array.firstObject length] > 1)
					@throw @"Неверное число аргументов";

				return nil;
			}

			else if (cmd == 'R')
			{
				if (array.count > 1 || [array.firstObject length] > 1)
					@throw @"Неверное число аргументов";

				[self regs:out];
			}

			else if (cmd == 'T' && array.count == 1)
			{
				if ([array.firstObject length] > 1)
				{
					uint32_t start = (PAGE << 16) | PC;

					if ([array.firstObject characterAtIndex:1] != '=' || ![self addr:&start fromString:[array.firstObject substringFromIndex:2]])
						@throw @"Ошибка в стартовом адресе";

					PC = start & 0xFFFF;
					PAGE = start >> 16;
				}
				else
				{
					[self execute:CLK + 1];
				}

				[self regs:out];
			}

			else if (cmd == 'P')
			{
				if (array.count > 1)
					@throw @"Неверное число аргументов";

				if ([array.firstObject length] > 1)
				{
					uint32_t start = (PAGE << 16) | PC;

					if ([array.firstObject characterAtIndex:1] != '=' || ![self addr:&start fromString:[array.firstObject substringFromIndex:2]])
						@throw @"Ошибка в стартовом адресе";

					PC = start & 0xFFFF;
					PAGE = start >> 16;
				}

				uint32_t start = (PAGE << 16) | PC;

				if ([array.firstObject length] > 1 && ([array.firstObject characterAtIndex:1] != '=' || ![self addr:&start fromString:[array.firstObject substringFromIndex:2]]))
					@throw @"Ошибка в стартовом адресе";

				PC = start & 0xFFFF;
				PAGE = start >> 16;

				const uint8_t *ptr = [self pointerFromAddress:(PAGE << 16) | PC];

				if (ptr && (((*ptr & 0xCF) == 0xCD) || ((*ptr & 0xC7) == 0xC4)|| (*ptr & 0xC7) == 0xC2))	// CALL/Ccc/Jcc
				{
					STOP1 = (PAGE << 16) | ((PC + 3) & 0xFFFF);
					return nil;
				}

				if (ptr && (*ptr & 0xC7) == 0xC7)	// RST n
				{
					STOP1 = (PAGE << 16) | ((PC + 1) & 0xFFFF);
					return nil;
				}

				[self execute:CLK + 1];
				[self regs:out];
			}

			else if (cmd == 'F')
			{
				if (array.count < 2 || array.count > 3)
					@throw @"Неверное число аргументов";

				uint32_t start = PAGE << 16;

				if ([array.firstObject length] > 1 && ![self addr:&start fromString:[array.firstObject substringFromIndex:1]])
					@throw @"Ошибка в начальном адресе";

				uint32_t end = start; if (![self addr:&end fromString:[array objectAtIndex:1]] || (end & 0xF0000) != (start & 0xF0000) || end < start)
					@throw @"Ошибка в конечном адресе";

				uint8_t data = array.count == 3 && [array.lastObject length] != 0 ? [self byteFromString:array.lastObject] : 0x00;

				while (start <= end)
				{
					uint8_t *ptr = [self pointerFromAddress:start];

					if (ptr == 0)
						@throw [NSString stringWithFormat:@"Невозможно записать: %04X", start & 0xFFFF];

					*ptr = data;
					start++;
				}
			}

			else if (cmd == 'T')
			{
				if (array.count < 2 || array.count > 3)
					@throw @"Неверное число аргументов";

				uint32_t start1 = PAGE << 16;

				if ([array.firstObject length] > 1 && ![self addr:&start1 fromString:[array.firstObject substringFromIndex:1]])
					@throw @"Ошибка в начальном адресе";

				uint32_t end = start1; if (![self addr:&end fromString:[array objectAtIndex:1]] || (end & 0xF0000) != (start1 & 0xF0000) || end < start1)
					@throw @"Ошибка в конечном адресе";

				uint32_t start2 = start1 & 0xF0000; if (array.count == 3 && [array.lastObject length] != 0 && ![self addr:&start2 fromString:array.lastObject])
					@throw @"Ошибка в адресе назначения";

				while (start1 <= end)
				{
					const uint8_t *ptr1 = [self pointerFromAddress:start1];
					uint8_t *ptr2 = [self pointerFromAddress:start2];

					if (ptr1)
					{
						if (ptr2 == 0)
							@throw [NSString stringWithFormat:@"Невозможно записать: %04X", start2 & 0xFFFF];

						*ptr2 = *ptr1;
					}

					start1++; inc(&start2);
				}
			}
			
			else if (cmd == 'C')
			{
				if (array.count < 2 || array.count > 3)
					@throw @"Неверное число аргументов";

				uint32_t start1 = PAGE << 16;

				if ([array.firstObject length] > 1 && ![self addr:&start1 fromString:[array.firstObject substringFromIndex:1]])
					@throw @"Ошибка в начальном адресе";

				uint32_t end = start1; if (![self addr:&end fromString:[array objectAtIndex:1]] || (end & 0xF0000) != (start1 & 0xF0000) || end < start1)
					@throw @"Ошибка в конечном адресе";

				uint32_t start2 = start1 & 0xF0000; if (array.count == 3 && [array.lastObject length] != 0 && ![self addr:&start2 fromString:array.lastObject])
					@throw @"Ошибка в адресе для сравнения";

				while (start1 <= end)
				{
					const uint8_t *ptr1 = [self pointerFromAddress:start1];
					const uint8_t *ptr2 = [self pointerFromAddress:start2];

					NSString *byte1 = ptr1 ? [NSString stringWithFormat:@"%02X", *ptr1] : @"??";
					NSString *byte2 = ptr2 ? [NSString stringWithFormat:@"%02X", *ptr2] : @"??";

					if (![byte1 isEqualToString:byte2])
					{
						unichar chr1 = ptr1 && *ptr1 < unicode.length ? [unicode characterAtIndex:*ptr1] : '.';
						unichar chr2 = ptr2 && *ptr2 < unicode.length ? [unicode characterAtIndex:*ptr2] : '.';

						[out appendFormat:@"%04X:  %@  %C    %04X:  %@  %C\n", start1 & 0xFFFF, byte1, chr1, start2 & 0xFFFF, byte2, chr2];
					}

					start1++; inc(&start2);
				}
			}
			
			else if (cmd == 'S')
			{
				if (array.count < 2 || array.count > 3)
					@throw @"Неверное число аргументов";

				uint32_t start = PAGE << 16;

				if ([array.firstObject length] > 1 && ![self addr:&start fromString:[array.firstObject substringFromIndex:1]])
					@throw @"Ошибка в стартовом адресе";

				uint32_t end = start; if (![self addr:&end fromString:[array objectAtIndex:1]] || (end & 0xF0000) != (start & 0xF0000) || end < start)
					@throw @"Ошибка в конечном адресе";

				NSString *search = array.count == 3 && [array.lastObject length] != 0 ? array.lastObject : @"00";

				unsigned length = (unsigned)search.length; if (length == 1)
				{
					search = [@"0" stringByAppendingString:search]; length++;
				}

				if (length > ((end - start + 1) << 1) || length & 1)
					@throw @"Ошибка в строке поиска";

				NSString *data = @""; while (start + (length >> 1) - 1 <= end)
				{
					while (data.length < length)
					{
						const uint8_t *ptr = [self pointerFromAddress:start];
						data = ptr ? [data stringByAppendingFormat:@"%02X", *ptr] : [data stringByAppendingString:@"??"];
					}

					unsigned i; for (i = 0; i < length && ([search characterAtIndex:i] == '?' || [search characterAtIndex:i] == [data characterAtIndex:i]); i++);

					if (i == length)
						[out appendFormat:@"%04X:  %@\n", start & 0xFFFF, data];

					data = [data substringFromIndex:2];
					start++;
				}
			}
			
			else if (cmd == 'M')
			{
				if (array.count != 1)
					@throw @"Неверное число аргументов";

				if ([array.firstObject length] > 1 && ![self addr:&lastM fromString:[array.firstObject substringFromIndex:1]])
					@throw @"Ошибка в начальном адресе";

				uint8_t *ptr = [self pointerFromAddress:lastM]; dbgCmd = 'M';
				return [NSString stringWithFormat:@"%04X:  %@ ", lastM & 0xFFFF, ptr ? [NSString stringWithFormat:@"%02X", *ptr] : @"??"];
			}

			else if (cmd == 'A')
			{
				if (array.count != 1)
					@throw @"Неверное число аргументов";

				if ([array.firstObject length] > 1 && ![self addr:&lastA fromString:[array.firstObject substringFromIndex:1]])
					@throw @"Ошибка в начальном адресе";

				dbgCmd = 'A'; return [NSString stringWithFormat:@"%04X:  ", lastA & 0xFFFF];
			}

			else if (cmd == 'X')
			{
				if (array.count > 1)
					@throw @"Неверное число аргументов";

				if ([command isEqualToString:@"X"])
				{
					dbgCmd = 1; return [NSString stringWithFormat:@"  PC:  %04X ", PC];
				}

				if ([command isEqualToString:@"XPC"] || [command isEqualToString:@"XP"])
				{
					dbgCmd = '1'; return [NSString stringWithFormat:@"  PC:  %04X ", PC];
				}

				if ([command isEqualToString:@"XHL"] || [command isEqualToString:@"XH"])
				{
					dbgCmd = '2'; return [NSString stringWithFormat:@"  HL:  %04X ", HL.HL];
				}

				if ([command isEqualToString:@"XBC"] || [command isEqualToString:@"XB"])
				{
					dbgCmd = '3'; return [NSString stringWithFormat:@"  BC:  %04X ", BC.BC];
				}

				if ([command isEqualToString:@"XDE"] || [command isEqualToString:@"XD"])
				{
					dbgCmd = '4'; return [NSString stringWithFormat:@"  DE:  %04X ", DE.DE];
				}

				if ([command isEqualToString:@"XSP"] || [command isEqualToString:@"XS"])
				{
					dbgCmd = '5'; return [NSString stringWithFormat:@"  SP:  %04X ", SP];
				}

				if ([command isEqualToString:@"XAF"] || [command isEqualToString:@"XA"])
				{
					dbgCmd = '6'; return [NSString stringWithFormat:@"  AF:  %04X ", AF.AF];
				}

				@throw @"Недопустимое имя регистра";
			}
			
			else if (cmd == 'O')
			{
				if (array.count != 2)
					@throw @"Неверное число аргументов";

				uint32_t start = PAGE << 16;

				if ([array.firstObject length] > 1 && ![self addr:&start fromString:[array.firstObject substringFromIndex:1]])
					@throw @"Ошибка в начальном адресе";

				uint32_t end = start; if (![self addr:&end fromString:[array objectAtIndex:1]] || (end & 0xF0000) != (start & 0xF0000) || end < start)
					@throw @"Ошибка в конечном адресе";

				NSMutableData *data = [NSMutableData dataWithLength:end - start + 1];
				uint8_t *mutableBytes = data.mutableBytes;

				[out appendFormat:@"%04X\n", start & 0xFFFF];

				while (start <= end)
				{
					const uint8_t *ptr = [self pointerFromAddress:start++];
					*mutableBytes++ = ptr ? *ptr : 0x00;
				}

				[out appendFormat:@"%04X\n", (start - 1) & 0xFFFF];

				NSSavePanel *panel = [NSSavePanel savePanel];
				panel.allowedFileTypes = @[@"bin"];
				panel.allowsOtherFileTypes = TRUE;

				if ([panel runModal] == NSFileHandlingPanelOKButton)
					[data writeToURL:panel.URL atomically:TRUE];
			}

			else if (cmd == 'I')
			{
				if (array.count > 3)
					@throw @"Неверное число аргументов";

				uint32_t start = PAGE << 16;

				if ([array.firstObject length] > 1 && ![self addr:&start fromString:[array.firstObject substringFromIndex:1]])
					@throw @"Ошибка в начальном адресе";

				uint32_t end = start | 0xFFFF; if (array.count > 1 && [array[1] length] != 0 && (![self addr:&end fromString:array[1]] || (end & 0xF0000) != (start & 0xF0000) || end < start))
					@throw @"Ошибка в конечном адресе";

				uint16_t pos = array.count == 3 && [array.lastObject length] != 0 ? [self wordFromString:array.lastObject] : 0;

				NSOpenPanel *panel = [NSOpenPanel openPanel]; if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
				{
					NSData *data = [NSData dataWithContentsOfURL:panel.URLs.firstObject];
					unsigned length = (unsigned) data.length;
					const uint8_t *bytes = [data bytes];

					if (length > pos)
					{
						length -= pos;
						bytes += pos;

						[out appendFormat:@"%04X\n", start & 0xFFFF];

						while (start <= end && length--)
						{
							uint8_t *ptr = [self pointerFromAddress:start];
							if (ptr == 0) break;

							*ptr = *bytes++;
							start++;
						}

						[out appendFormat:@"%04X\n", (start - 1) & 0xFFFF];
					}
				}
			}

			else if (cmd == '7')
			{
				[out appendString:@"КОИ-7\n"];
				unicode = [X8080 koi7];
			}

			else if (cmd == '8')
			{
				[out appendString:@"КОИ-8\n"];
				unicode = [X8080 koi8];
			}

			else
			{
				[out appendString:@"Неизвестная директива\n"];
			}
		}
		
	}

	@catch (NSException *exception)
	{
		[out appendFormat:@"%@\n# ", exception];
		dbgCmd = 0; return out;
	}

	@catch (NSString *string)
	{
		[out appendFormat:@"%@\n# ", string];
		dbgCmd = 0; return out;
	}

	[out appendString:@"# "];
	dbgCmd = 0; return out;
}

// -----------------------------------------------------------------------------
// DEBUG: dealloc
// -----------------------------------------------------------------------------

#ifdef DEBUG
- (void) dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
