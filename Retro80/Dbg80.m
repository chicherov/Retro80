/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Отладчик для центрального процессора из класса X8080

 *****/

#import "Dbg80.h"

@implementation Dbg80
{
	uint8_t breakpoints[0x10000];

	NSString *unicode;
	unichar dbgCmd;

	uint16_t lastL;
	uint16_t lastD;

	uint16_t lastA;
	uint16_t lastM;
}

@synthesize debug;
@synthesize cpu;

- (instancetype)initWithDebug:(Debug *)object
{
	if (self = [super init])
		debug = object;

	return self;
}

+ (instancetype)dbg80WithDebug:(Debug *)debug
{
	return [[self alloc] initWithDebug:debug];
}

- (void)run
{
	[cpu setBreakpoints:breakpoints];

	uint16_t addr = 0x0000;
	do
		breakpoints[addr++] &= ~0x20;
	while (addr);

	if (unicode == nil)
		unicode = koi7();

	if (cpu.BREAK & 0x2000000000)
	{
		[self regs];
	}

	else if (cpu.BREAK & 0xFFFFFFFF00000000)
	{
		[debug print:@"%c %04X/%04X\n",
				cpu.BREAK & 0x0100000000 ? 'R' :
				cpu.BREAK & 0x0200000000 ? 'W' :
				cpu.BREAK & 0x0400000000 ? 'I' :
				cpu.BREAK & 0x0800000000 ? 'O' :
				cpu.BREAK & 0x1000000000 ? 'X' :
				'?',
				lastD = (cpu.BREAK >> 16) & 0xFFFF,
				lastL = cpu.BREAK & 0xFFFF
		];
	}

	[debug print:@"# "];
	[debug flush];
	dbgCmd = 0;

	[debug run];
}

// -----------------------------------------------------------------------------
// Данные для ассемблера/дисассемблера
// -----------------------------------------------------------------------------

static const char *rst[8][4] = {
	{"0", "00", "00", "00"},
	{"1", "08", "08", "08"},
	{"2", "10", "10", "10"},
	{"3", "18", "18", "18"},
	{"4", "20", "20", "20"},
	{"5", "28", "28", "28"},
	{"6", "30", "30", "30"},
	{"7", "38", "38", "38"}
};

static const char *reg[8][4] = {
	{"B", "B",    "B",       "B"},
	{"C", "C",    "C",       "C"},
	{"D", "D",    "D",       "D"},
	{"E", "E",    "E",       "E"},
	{"H", "H",    "IXH",     "IYH"},
	{"L", "L",    "IXL",     "IYL"},
	{"M", "(HL)", "(IX+%@)", "(IY+%@)"},
	{"A", "A",    "A",       "A"}
};

static const char *push_rp[4][4] = {
	{"B",   "BC", "BC", "BC"},
	{"D",   "DE", "DE", "DE"},
	{"H",   "HL", "IX", "IY"},
	{"PSW", "AF", "AF", "AF"}
};

static const char *rp[4][4] = {
	{"B",  "BC", "BC", "BC"},
	{"D",  "DE", "DE", "DE"},
	{"H",  "HL", "IX", "IY"},
	{"SP", "SP", "SP", "SP"}
};

static const char *bit[8][4] = {
	{0, "0", "0", "0"},
	{0, "1", "1", "1"},
	{0, "2", "2", "2"},
	{0, "3", "3", "3"},
	{0, "4", "4", "4"},
	{0, "5", "5", "5"},
	{0, "6", "6", "6"},
	{0, "7", "7", "7"}
};

static struct opcode_t {

	uint16_t cmd; uint8_t size;
	const char *name[2];

	struct arg_t
	{
		int type, shift, mask;
		const char *(*fmt)[4];

	} arg[2];

} opcodes[] = {

	{ 0x00, 1, {"NOP", "NOP"} }, { 0x00, 1, {"NOP*", 0}, {{0, 3, 7} }},

	{ 0x01, 3, {"LXI", "LD "}, {{ 3, 4, 3, rp }, { 2 }} },
	{ 0x02, 1, {"STAX", 0}, { {3, 4, 1, rp} } }, { 0x02, 1, {0, "LD "}, {{ 13, 4, 1, rp }, {3, 0, 0, reg + 7 }}},
	{ 0x03, 1, {"INX", "INC "}, { {3, 4, 3, rp} } },
	{ 0x04, 1, {"INR", "INC "}, { {3, 3, 7, reg} } },
	{ 0x05, 1, {"DCR", "DEC "}, { {3, 3, 7, reg} } },
	{ 0x06, 2, {"MVI", "LD "}, {{ 3, 3, 7, reg }, { 1 }} },
	{ 0x07, 1, {"RLC", "RLCA"} },
	{ 0x08, 1, {0, "EX AF,AF'"} },
	{ 0x09, 1, {"DAD", 0}, { {3, 4, 3, rp} } }, { 0x09, 1, {0, "ADD "}, {{ 3, 0, 0, rp + 2 }, { 3, 4, 3, rp }}},
	{ 0x0A, 1, {"LDAX", 0}, { {3, 4, 1, rp} } }, { 0x0A, 1, {0, "LD "}, {{ 3, 0, 0, reg + 7 }, { 13, 4, 1, rp }}},
	{ 0x0B, 1, {"DCX", "DEC "}, { {3, 4, 3, rp} } },
	{ 0x0F, 1, {"RRC", "RRCA"} },

	{ 0x10, 2, {0, "DJNZ "}, { {4} } },
	{ 0x17, 1, {"RAL", "RLA"} },
	{ 0x18, 2, {0, "JR "}, { {4} } },
	{ 0x1F, 1, {"RAR", "RRA"} },

	{ 0x20, 2, {0, "JR NZ,"}, { {4} } },
	{ 0x22, 3, {"SHLD", 0}, { {2} } }, { 0x22, 3, {0, "LD "}, {{ 12 }, { 3, 0, 0, rp + 2 }}},
	{ 0x27, 1, {"DAA", "DAA"} },
	{ 0x28, 2, {0, "JR Z,"}, { {4} } },
	{ 0x2A, 3, {"LHLD", 0}, { {2} } }, { 0x2A, 3, {0, "LD "}, {{ 3, 0, 0, rp + 2 }, { 12 }}},
	{ 0x2F, 1, {"CMA", "CPL"} },

	{ 0x30, 2, {0, "JR NC,"}, { {4} } },
	{ 0x32, 3, {"STA", 0}, { {2} } }, { 0x32, 3, {0, "LD "}, {{ 12 }, {3, 0, 0, reg + 7 }}},
	{ 0x37, 1, {"STC", "SCF"} },
	{ 0x38, 2, {0, "JR C,"}, { {4} } },
	{ 0x3A, 3, {"LDA", 0}, { {2} } }, { 0x3A, 3, {0, "LD "}, {{3, 0, 0, reg + 7 }, { 12 }}},
	{ 0x3F, 1, {"CMC", "CCF"} },

	{ 0x76, 1, {"HLT", "HALT"} },
	{ 0x40, 1, {"MOV", "LD "}, {{ 3, 3, 7, reg }, { 3, 0, 7, reg }} },

	{ 0x80, 1, {"ADD", "ADD A,"}, { {3, 0, 7, reg} } },
	{ 0x88, 1, {"ADC", "ADC A,"}, { {3, 0, 7, reg} } },
	{ 0x90, 1, {"SUB", "SUB "}, { {3, 0, 7, reg} } },
	{ 0x98, 1, {"SBB", "SBC A,"}, { {3, 0, 7, reg} } },
	{ 0xA0, 1, {"ANA", "AND "}, { {3, 0, 7, reg} } },
	{ 0xA8, 1, {"XRA", "XOR "}, { {3, 0, 7, reg} } },
	{ 0xB0, 1, {"ORA", "OR "}, { {3, 0, 7, reg} } },
	{ 0xB8, 1, {"CMP", "CP "}, { {3, 0, 7, reg} } },

	{ 0xC0, 1, {"RNZ", "RET NZ"} },
	{ 0xC1, 1, {"POP", "POP "}, { {3, 4, 3, push_rp} } },
	{ 0xC2, 3, {"JNZ", "JP NZ,"}, { {2} } },
	{ 0xC3, 3, {"JMP", "JP "}, { {2} } },
	{ 0xC4, 3, {"CNZ", "CALL NZ,"}, { {2} } },
	{ 0xC5, 1, {"PUSH", "PUSH "}, { {3, 4, 3, push_rp} } },
	{ 0xC6, 2, {"ADI", "ADD A,"}, { {1} } },
	{ 0xC7, 1, {"RST", "RST "}, { {3, 3, 7, rst} } },
	{ 0xC8, 1, {"RZ", "RET Z"} },
	{ 0xC9, 1, {"RET", "RET"} },
	{ 0xCA, 3, {"JZ", "JP Z,"}, { {2} } },
	{ 0xCB, 3, {"JMP*", 0}, { {2} } },
	{ 0xCC, 3, {"CZ", "CALL Z,"}, { {2} } },
	{ 0xCD, 3, {"CALL", "CALL "}, { {2} } },
	{ 0xCE, 2, {"ACI", "ADC A,"}, { {1} } },

	{ 0xD0, 1, {"RNC", "RET NC"} },
	{ 0xD2, 3, {"JNC", "JP NC,"}, { {2} } },
	{ 0xD3, 2, {"OUT", 0}, { {1} } },
	{ 0xD3, 2, {0, "OUT "}, {{ 11 }, { 3, 0, 0, reg + 7 }}},
	{ 0xD4, 3, {"CNC", "CALL NC,"}, { {2} } },
	{ 0xD6, 2, {"SUI", "SUB "}, { {1} } },
	{ 0xD8, 1, {"RC", "RET C"} },
	{ 0xD9, 1, {"RET*", "EXX"} },
	{ 0xDA, 3, {"JC", "JP C,"}, { {2} } },
	{ 0xDB, 2, {"IN", 0}, { {1} } },
	{ 0xDB, 2, {0, "IN "}, {{ 3, 0, 0, reg + 7 }, { 11 } }},
	{ 0xDC, 3, {"CC", "CALL C,"}, { {2} } },
	{ 0xDD, 3, {"CALL*", 0}, { {2} } },
	{ 0xDE, 2, {"SBI", "SBC A,"}, { {1} } },

	{ 0xE0, 1, {"RPO", "RET PO"} },
	{ 0xE2, 3, {"JPO", "JP PO,"}, { {2} } },
	{ 0xE3, 1, {"XTHL", 0} }, { 0xE3, 1, {0, "EX (SP),"}, { {3, 0, 0, rp + 2} }},

	{ 0xE4, 3, {"CPO", "CALL PO,"}, { {2} } },
	{ 0xE6, 2, {"ANI", "AND "}, { {1} } },
	{ 0xE8, 1, {"RPE", "RET PE"} },
	{ 0xE9, 1, {"PCHL", 0} }, { 0xE9, 1, {0, "JP "}, { {13, 0, 0, rp + 2} }},
	{ 0xEA, 3, {"JPE", "JP PE,"}, { {2} } },
	{ 0xEB, 1, {"XCHG", "EX DE,HL"} },
	{ 0xEC, 3, {"CPE", "CALL PE,"}, { {2} } },
	{ 0xEE, 2, {"XRI", "XOR "}, { {1} } },
	{ 0xED, 3, {"CALL*", 0}, { {2} } },

	{ 0xF0, 1, {"RP", "RET P"} },
	{ 0xF2, 3, {"JP", "JP P,"}, { {2} } },
	{ 0xF3, 1, {"DI", "DI"} },
	{ 0xF4, 3, {"CP", "CALL P,"}, { {2} } },
	{ 0xF6, 2, {"ORI", "OR "}, { {1} } },
	{ 0xF8, 1, {"RM", "RET M"} },
	{ 0xF9, 1, {"SPHL"}}, { 0xF9, 1, {0, "LD SP,"}, { {3, 0, 0, rp + 2} }},
	{ 0xFA, 3, {"JM", "JP M,"}, { {2} } },
	{ 0xFB, 1, {"EI", "EI"} },
	{ 0xFC, 3, {"CM", "CALL M,"}, { {2} } },
	{ 0xFE, 2, {"CPI", "CP "}, { {1} } },
	{ 0xFD, 3, {"CALL*", 0}, { {2} } },

	{ 0xCB00, 1, {0, "RLC "}, { {3, 0, 7, reg} } },
	{ 0xCB08, 1, {0, "RRC "}, { {3, 0, 7, reg} } },
	{ 0xCB10, 1, {0, "RL "}, { {3, 0, 7, reg} } },
	{ 0xCB18, 1, {0, "RR "}, { {3, 0, 7, reg} } },
	{ 0xCB20, 1, {0, "SLA "}, { {3, 0, 7, reg} } },
	{ 0xCB28, 1, {0, "SRA "}, { {3, 0, 7, reg} } },
	{ 0xCB30, 1, {0, "SLL "}, { {3, 0, 7, reg} } },
	{ 0xCB38, 1, {0, "SRL "}, { {3, 0, 7, reg} } },

	{ 0xCB40, 1, {0, "BIT "}, {{ 3, 3, 7, bit }, { 3, 0, 7, reg }}},
	{ 0xCB80, 1, {0, "RES "}, {{ 3, 3, 7, bit }, { 3, 0, 7, reg }}},
	{ 0xCBC0, 1, {0, "SET "}, {{ 3, 3, 7, bit }, { 3, 0, 7, reg }}},

	{ 0xED70, 1, {0, "IN (C)"} }, { 0xED40, 1, {0, "IN "}, {{ 3, 3, 7, reg }, { 13, 0, 0, reg + 1 }}},
	{ 0xED71, 1, {0, "OUT (C),0"} }, { 0xED41, 1, {0, "OUT "}, {{ 13, 0, 0, reg + 1 }, { 3, 3, 7, reg }}},
	{ 0xED42, 1, {0, "SBC HL,"}, { {3, 4, 3, rp} }},
	{ 0xED43, 3, {0, "LD "}, {{ 12 }, { 3, 4, 3, rp }}},
	{ 0xED44, 1, {0, "NEG "} },
	{ 0xED45, 1, {0, "RETN"} },
	{ 0xED46, 1, {0, "IM 0"} },
	{ 0xED47, 1, {0, "LD I,A"} },
	{ 0xED4A, 1, {0, "ADC HL,"}, { {3, 4, 3, rp} }},
	{ 0xED4B, 3, {0, "LD "}, {{ 3, 4, 3, rp }, { 12 }}},
	{ 0xED4C, 1, {0, "NEG*"} },
	{ 0xED4D, 1, {0, "RETI"} },
	{ 0xED4E, 1, {0, "IM 0*"} },
	{ 0xED4F, 1, {0, "LD R,A"} },

	{ 0xED54, 1, {0, "NEG*"} },
	{ 0xED55, 1, {0, "RETN*"} },
	{ 0xED56, 1, {0, "IM 1"} },
	{ 0xED57, 1, {0, "LD A,I"} },
	{ 0xED5C, 1, {0, "NEG*"} },
	{ 0xED5D, 1, {0, "RETN*"} },
	{ 0xED5E, 1, {0, "IM 2"} },
	{ 0xED5F, 1, {0, "LD A,R"} },

	{ 0xED64, 1, {0, "NEG*"} },
	{ 0xED65, 1, {0, "RETN*"} },
	{ 0xED66, 1, {0, "IM 0*"} },
	{ 0xED67, 1, {0, "RRD"} },
	{ 0xED6C, 1, {0, "NEG*"} },
	{ 0xED6D, 1, {0, "RETN*"} },
	{ 0xED6E, 1, {0, "IM 0*"} },
	{ 0xED6F, 1, {0, "RLD"} },

	{ 0xED74, 1, {0, "NEG*"} },
	{ 0xED75, 1, {0, "RETN*"} },
	{ 0xED76, 1, {0, "IM 1*"} },
	{ 0xED7C, 1, {0, "NEG*"} },
	{ 0xED7D, 1, {0, "RETN*"} },
	{ 0xED7E, 1, {0, "IM 2*"} },

	{ 0xEDA0, 1, {0, "LDI"} },
	{ 0xEDA1, 1, {0, "CPI"} },
	{ 0xEDA2, 1, {0, "INI"} },
	{ 0xEDA3, 1, {0, "OUTI"} },

	{ 0xEDA8, 1, {0, "LDD"} },
	{ 0xEDA8, 1, {0, "CPD"} },
	{ 0xEDAA, 1, {0, "IND"} },
	{ 0xEDAB, 1, {0, "OUTD"} },

	{ 0xEDB0, 1, {0, "LDIR"} },
	{ 0xEDB1, 1, {0, "CPIR"} },
	{ 0xEDB2, 1, {0, "INIR"} },
	{ 0xEDB3, 1, {0, "OTIR"} },

	{ 0xEDB8, 1, {0, "LDDR"} },
	{ 0xEDB8, 1, {0, "CPDR"} },
	{ 0xEDBA, 1, {0, "INDR"} },
	{ 0xEDBB, 1, {0, "OTDR"} },

	// --

	{ 0xED00, 1, {0, "NOP*"}, {{0, 0, 255}}},
	{ 0x00, 1, {0, "NOP*"}, {{0, 0, 255}}},

	{ 0x00, 0, {"???", "???"} }
};

// -----------------------------------------------------------------------------
// Дизассемблер
// -----------------------------------------------------------------------------

- (void) dasm:(BOOL)z80
{
	[debug print:@"  %04X:  ", lastL];

	const uint8_t *ptr = [cpu BYTE:lastL++];
	NSString *dumpChr = [unicode substringWithRange:NSMakeRange(ptr && *ptr < unicode.length ? *ptr : 0, 1)];
	NSString *dumpHex = ptr ? [NSString stringWithFormat:@"%02X", *ptr] : @"??";
	uint16_t cmd = ptr ? *ptr : -1;

	int ir = 0; if (z80 && (cmd == 0xDD || cmd == 0xFD) && (ptr = [cpu BYTE:lastL]) && *ptr != 0xDD && *ptr != 0xED && *ptr != 0xFD)
	{
		dumpChr = [dumpChr stringByAppendingString:[unicode substringWithRange:NSMakeRange(*ptr < unicode.length ? *ptr : 0, 1)]];
		dumpHex = [dumpHex stringByAppendingFormat:@" %02X", *ptr];
		ir = cmd == 0xDD ? 1 : 2; cmd = *ptr; lastL++;
	}

	NSString *index = nil, *source = @""; if (z80 && (cmd == 0xCB || cmd == 0xED))
	{
		if (ir && cmd == 0xCB)
		{
			dumpHex = [dumpHex stringByAppendingFormat:@" %@", index = (ptr = [cpu BYTE:lastL++]) ? [NSString stringWithFormat:@"%02X", *ptr] : @"??"];
			dumpChr = [dumpChr stringByAppendingString:[unicode substringWithRange:NSMakeRange(ptr && *ptr < unicode.length ? *ptr : 0, 1)]];

			dumpHex = (ptr = [cpu BYTE:lastL++]) ? [dumpHex stringByAppendingFormat:@" %02X", *ptr] : [dumpHex stringByAppendingString:@" ??"];
			dumpChr = [dumpChr stringByAppendingString:[unicode substringWithRange:NSMakeRange(*ptr < unicode.length ? *ptr : 0, 1)]];

			cmd = ptr ? 0xCB06 | (*ptr & 0xF8) : -1; if (ptr && (*ptr & 0x07) != 0x06)
				source = [NSString stringWithFormat:@"LD %s,", reg[*ptr & 0x07][1]];
		}
		else
		{
			dumpHex = (ptr = [cpu BYTE:lastL++]) ? [dumpHex stringByAppendingFormat:@" %02X", *ptr] : [dumpHex stringByAppendingString:@" ??"];
			dumpChr = [dumpChr stringByAppendingString:[unicode substringWithRange:NSMakeRange(*ptr < unicode.length ? *ptr : 0, 1)]];
			cmd = ptr ? (cmd << 8) | *ptr : -1;
		}
	}

	struct opcode_t const *op = opcodes; while (op->size && (op->name[z80] == 0 || (cmd & ~((op->arg[0].mask << op->arg[0].shift) | (op->arg[1].mask << op->arg[1].shift))) != op->cmd)) op++;

	if (ir && index == nil && ((op->arg[0].fmt == reg && (cmd >> (op->arg[0].shift) & op->arg[0].mask) == 6) || (op->arg[1].fmt == reg && (cmd >> (op->arg[1].shift) & op->arg[1].mask) == 6)))
	{
		dumpHex = [dumpHex stringByAppendingFormat:@" %@", index = (ptr = [cpu BYTE:lastL++]) ? [NSString stringWithFormat:@"%02X", *ptr] : @"??"];
		dumpChr = [dumpChr stringByAppendingString:[unicode substringWithRange:NSMakeRange(ptr && *ptr < unicode.length ? *ptr : 0, 1)]];
	}

	NSUInteger pos = dumpHex.length;

	if (op->size >= 2)
	{
		dumpHex = [dumpHex stringByAppendingFormat:@" %@", (ptr = [cpu BYTE:lastL++]) ? [NSString stringWithFormat:@"%02X", *ptr] : @"??"];
		dumpChr = [dumpChr stringByAppendingString:[unicode substringWithRange:NSMakeRange(ptr && *ptr < unicode.length ? *ptr : 0, 1)]];
	}

	if (op->size >= 3)
	{
		dumpHex = [dumpHex stringByAppendingFormat:@" %@", (ptr = [cpu BYTE:lastL++]) ? [NSString stringWithFormat:@"%02X", *ptr] : @"??"];
		dumpChr = [dumpChr stringByAppendingString:[unicode substringWithRange:NSMakeRange(ptr && *ptr < unicode.length ? *ptr : 0, 1)]];
	}

	dumpHex = [dumpHex stringByPaddingToLength:z80 ? 14 : 8 withString:@" " startingAtIndex:0];
	dumpChr = [dumpChr stringByPaddingToLength:z80 ? 5 : 3 withString:@" " startingAtIndex:0];

	source = [source stringByAppendingFormat:z80 ? @"%s" : @"%s ", op->name[z80]];

	for (int i = 0; i < 2 && op->arg[i].type; i++) switch (op->arg[i].type)
	{
		case 4:

			if (ptr)
				source = [source stringByAppendingFormat:i ? @",%04X" : @"%04X", (lastL + *(int8_t *)ptr) & 0xFFFF];
			else
				source = [source stringByAppendingFormat:i ? @",????" : @"????"];

			break;

		case 13:
		case 3:

			source = [source stringByAppendingFormat:[NSString stringWithFormat:op->arg[i].type > 10 ? (i ? @",(%s)" : @"(%s)") : (i ? @",%s" : @"%s"), op->arg[i].fmt[(cmd >> op->arg[i].shift) & op->arg[i].mask][index && ((cmd >> op->arg[i].shift) & op->arg[i].mask) != 6 ? z80 : z80 + ir]], index];

			break;

		case 12:
		case 2:

			source = [source stringByAppendingFormat:op->arg[i].type > 10 ? (i ? @",(%@%@)" : @"(%@%@)") : (i ? @",%@%@" : @"%@%@"), [dumpHex substringWithRange:NSMakeRange(pos + 4, 2)], [dumpHex substringWithRange:NSMakeRange(pos + 1, 2)]];

			break;

		case 11:
		case 1:

			source = [source stringByAppendingFormat:op->arg[i].type > 10 ? (i ? @",(%@)" : @"(%@)") : (i ? @",%@" : @"%@"), [dumpHex substringWithRange:NSMakeRange(pos + 1, 2)]];

			break;
	}

	NSArray<NSString *> *array = [source componentsSeparatedByString:@" "];

	if (array.count > 1)
		source = [[array.firstObject stringByPaddingToLength:z80 ? 5 : 8 withString:@" " startingAtIndex:0] stringByAppendingString:[[array subarrayWithRange:NSMakeRange(1, array.count-1)] componentsJoinedByString:@" "]];
	else
		source = array.firstObject;

	[debug print:@"%@  %@   %@\n", dumpHex, dumpChr, source];
}

// -----------------------------------------------------------------------------
// Служенные методы для отладчика
// -----------------------------------------------------------------------------

static NSString *koi7()
{
	return @".▘▝▀▗▚▐▜........▖▌▞▛▄▙▟█........ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_ЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧ.";
}

static NSString *koi8()
{
	return @".▘▝▀▗▚▐▜........▖▌▞▛▄▙▟█........ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~.................................................................юабцдефгхийклмнопярстужвьызшэщчъЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧЪ";
}

// -----------------------------------------------------------------------------
// word
// -----------------------------------------------------------------------------

- (uint16_t) word:(NSString *)string last:(uint16_t)last
{
	uint16_t result = last; if (string)
	{
		NSScanner *scanner = [NSScanner scannerWithString:string];

		while (scanner.isAtEnd == NO)
		{
			NSString *o = nil; if ([scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"+-"] intoString:&o] ? o.length > 1 || scanner.isAtEnd : scanner.scanLocation != 0)
				@throw @"Недопустимое значение";

			NSString *p = nil; if ([scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"#$'"] intoString:&p] && (p.length > 1 || scanner.isAtEnd))
				@throw @"Недопустимое значение";

			unsigned value; if (p)
			{
				if ([p isEqualToString:@"#"])
				{
					if (![scanner scanInt:(int *)&value] || (value > 0xFFFF && (value | 0x7FFF) != -1))
						@throw @"Недопустимое значение";
				}

				else if ([p isEqualToString:@"$"])
				{
					NSString *r = nil; if (![scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"+-"] intoString:&r])
						@throw @"Недопустимое значение";

					if ([r = r.lowercaseString isEqualToString:@"a"])
						value = cpu.A;
					else if ([r isEqualToString:@"b"])
						value = cpu.B;
					else if ([r isEqualToString:@"c"])
						value = cpu.C;
					else if ([r isEqualToString:@"d"])
						value = cpu.D;
					else if ([r isEqualToString:@"e"])
						value = cpu.E;
					else if ([r isEqualToString:@"h"])
						value = cpu.D;
					else if ([r isEqualToString:@"l"])
						value = cpu.E;
					else if ([r isEqualToString:@"af"])
						value = cpu.AF;
					else if ([r isEqualToString:@"bc"])
						value = cpu.BC;
					else if ([r isEqualToString:@"de"])
						value = cpu.DE;
					else if ([r isEqualToString:@"hl"])
						value = cpu.HL;
					else if ([r isEqualToString:@"pc"])
						value = cpu.PC;
					else if ([r isEqualToString:@"sp"])
						value = cpu.SP;
					else if ([r isEqualToString:@"ix"])
						value = cpu.IX;
					else if ([r isEqualToString:@"iy"])
						value = cpu.IY;
					else
						@throw @"Недопустимое значение";
				}

				else
				{
					NSString *s = nil; if (![scanner scanUpToString:@"'" intoString:&s] || s.length > 2 || ![scanner scanString:@"'" intoString:NULL])
						@throw @"Недопустимое значение";

					NSRange range; if ((range = [unicode rangeOfString:[s substringToIndex:1]]).location == NSNotFound)
						@throw @"Недопустимое значение";

					value = range.location & 0xFF;

					if (s.length == 2)
					{
						if ((range = [unicode rangeOfString:[s substringFromIndex:1]]).location == NSNotFound)
							@throw @"Недопустимое значение";

						value |= (range.location & 0xFF) << 8;
					}
				}
			}

			else if ([scanner scanString:@"^" intoString:NULL])
			{
				int offset = 0; while ([scanner scanString:@"^" intoString:NULL]) offset += 2;
				const uint8_t *ptr = [cpu BYTE:cpu.SP + offset]; value = ptr ? *ptr : 0;
				value |= ((ptr = [cpu BYTE:cpu.SP + offset + 1]) ? *ptr : 0) << 8;
			}

			else
			{
				if (![scanner scanHexInt:&value] || value > 0xFFFF)
					@throw @"Недопустимое значение";
			}

			if (o)
			{
				if ([o isEqualToString:@"+"])
					result += value;
				else
					result -= value;
			}
			else
			{
				result = value;
			}
		}
		
	}

	return result;
}

// -----------------------------------------------------------------------------
// byte
// -----------------------------------------------------------------------------

- (uint16_t) byte:(NSString *)string
{
	uint16_t value = [self word:string last:0x00];

	if (value > 0xFF && value < 0xFF80)
		@throw @"Недопустимое значение";

	return value;
}

// -----------------------------------------------------------------------------
// Текущие регистры процессора
// -----------------------------------------------------------------------------

- (void) regs
{
	if (cpu.Z80)
		[debug print:@"  A=%02X   BC=%04X DE=%04X HL=%04X SP=%04X  IX=%04X IY=%04X  F=%02X (%c%c%c%c%c%c)  IM%d/%cI\n",
		 cpu.A,
		 cpu.BC,
		 cpu.DE,
		 cpu.HL,
		 cpu.SP,
		 cpu.IX,
		 cpu.IY,
		 cpu.F,
		 cpu.F & 0x80 ? 'S' : '-',
		 cpu.F & 0x40 ? 'Z' : '-',
		 cpu.F & 0x10 ? 'A' : '-',
		 cpu.F & 0x04 ? 'P' : '-',
		 cpu.F & 0x02 ? 'N' : '-',
		 cpu.F & 0x01 ? 'C' : '-',
		 cpu.IM,
		 cpu.IF ? 'E' : 'D'
		 ];
	else
		[debug print:@"  A=%02X   BC=%04X DE=%04X HL=%04X SP=%04X   F=%02X (%c%c%c%c%c)   %cI\n",
		 cpu.A,
		 cpu.BC,
		 cpu.DE,
		 cpu.HL,
		 cpu.SP,
		 cpu.F,
		 cpu.F & 0x80 ? 'S' : '-',
		 cpu.F & 0x40 ? 'Z' : '-',
		 cpu.F & 0x10 ? 'A' : '-',
		 cpu.F & 0x04 ? 'P' : '-',
		 cpu.F & 0x01 ? 'C' : '-',
		 cpu.IF ? 'E' : 'D'
		 ];

	lastL = cpu.PC;
	lastD = cpu.HL;
	[self dasm:cpu.Z80];
}

// -----------------------------------------------------------------------------
// Отладчик
// -----------------------------------------------------------------------------

- (BOOL) Debugger:(NSString *)command
{
	@try
	{
		if ([command isEqualToString:@"."])
		{
			dbgCmd = 0;
		}

		else if (dbgCmd == 'M')
		{
			if (command.length)
			{
				uint8_t *ptr; if ((ptr = [cpu BYTE:lastM]))
					*ptr = [self byte:command];
			}

			const uint8_t *ptr; if ((ptr = [cpu BYTE:++lastM]))
				[debug print:@"  %04X:  %02X ", lastM, *ptr];
			else
				[debug print:@"  %04X:  ?? ", lastM];

			return NO;
		}

		else if (dbgCmd == 'A')
		{
			if (command.length)
			{
				NSArray<NSString *> *array = [command componentsSeparatedByString:@" "];
				command = array.firstObject.uppercaseString ;

				for (struct opcode_t const *op = &opcodes[0]; op->size; op++) if ([[NSString stringWithFormat:@"%s", op->name[0]] isEqualToString:command])
				{
					NSUInteger index = [array indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
						return idx && [obj length] != 0;
					}];

					if (index != NSNotFound)
						command = [[array subarrayWithRange:NSMakeRange(index, array.count - index)]
								   componentsJoinedByString:@" "];
					else
						command = @"";

					array = [command componentsSeparatedByString:@","];

					if (array.count > 2 || (op->arg[1].type == 0 && array.count > 1) || (op->arg[1].type && array.count < 2) || (op->arg[0].type == 0 && [array.firstObject length]) || (op->arg[0].type && [array.firstObject length] == 0))
						@throw @"Неверное количество аргументов";

					uint8_t cmd = op->cmd; for (unsigned i = 0; i < 2; i++) if (op->arg[i].type == 3)
					{
						NSString *arg = [array[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].uppercaseString;

						unsigned j; for (j = 0; j <= op->arg[i].mask; j++)
						{
							if ([arg isEqualToString:[NSString stringWithFormat:@"%s", op->arg[i].fmt[j][0]]])
							{
								cmd |= j << op->arg[i].shift; break;
							}
						}

						if (j > op->arg[i].mask)
							@throw @"Недопустимый аргумент";
					}

					uint16_t data = 0; if (op->size == 2 || op->size == 3)
					{
						NSString *arg = [array.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
						data = op->size == 2 ? [self byte:arg] : [self word:arg last:0];
					}

					uint8_t *ptr; if ((ptr = [cpu BYTE:lastA++]))
						*ptr = cmd;

					if (op->size >= 2 && (ptr = [cpu BYTE:lastA++]))
						*ptr = data & 0xFF;

					if (op->size >= 3 && (ptr = [cpu BYTE:lastA++]))
						*ptr = data >> 8;

					[debug print:@"  %04X:  ", lastA];
					return NO;
				}
				
				@throw @"Недопустимый опкод";
			}

		}

		else if (dbgCmd == '1')
		{
			if (command.length)
				cpu.PC = [self word:command last:0];

			[debug print:@"  HL-%04X  ", cpu.HL];
			dbgCmd++; return NO;
		}

		else if (dbgCmd == '2')
		{
			if (command.length)
				cpu.HL = [self word:command last:0];

			[debug print:@"  BC-%04X  ", cpu.BC];
			dbgCmd++; return NO;
		}

		else if (dbgCmd == '3')
		{
			if (command.length)
				cpu.BC = [self word:command last:0];

			[debug print:@"  DE-%04X  ", cpu.DE];
			dbgCmd++; return NO;
		}

		else if (dbgCmd == '4')
		{
			if (command.length)
				cpu.DE = [self word:command last:0];

			[debug print:@"  SP-%04X  ", cpu.SP];
			dbgCmd++; return NO;
		}

		else if (dbgCmd == '5')
		{
			if (command.length)
				cpu.SP = [self word:command last:0];

			[debug print:@"  AF-%04X  ", cpu.AF];
			dbgCmd++; return NO;
		}

		else if (dbgCmd == '6')
		{
			if (command.length)
				cpu.AF = [self word:command last:0];
		}

		else if (command.length != 0)
		{
			NSArray<NSString *> *array = command.length == 1 ? nil : [[command substringFromIndex:1] componentsSeparatedByString:@","];

			unichar cmd = [command.uppercaseString characterAtIndex:0];

			if (cmd == 'Q')
			{
				if (array.count)
					@throw @"Неверное число аргументов";

				cpu.breakpoints = 0;
				[debug clear];
				return YES;
			}

			else if (cmd == '7')
			{
				if (array.count)
					@throw @"Неверное число аргументов";

				[debug print:@"КОИ-7\n"];
				unicode = koi7();
			}

			else if (cmd == '8')
			{
				if (array.count)
					@throw @"Неверное число аргументов";

				[debug print:@"КОИ-8\n"];
				unicode = koi8();
			}

			else if (cmd == 'G')
			{
				cpu.PC = [self word:array.firstObject last:cpu.PC];

				for (NSUInteger i = 1; i < array.count && array[i].length; i++)
					breakpoints[[self word:array[i] last:cpu.PC]] |= 0x20;

				return YES;
			}

			else if (cmd == 'B')
			{
				if (array.count > 3)
					@throw @"Неверное число аргументов";

				if (array.count == 0)
				{
					uint16_t addr = 0x0000; do if (breakpoints[addr])
					{
						uint16_t start = addr; while (addr != 0xFFFF && breakpoints[addr] == breakpoints[addr + 1]) addr++;

						[debug print:addr == start ? @"%c%c%c%c%c %04X\n" : @"%c%c%c%c%c %04X-%04X\n",
						 breakpoints[start] & 0x10 ? 'X' : ' ',
						 breakpoints[start] & 0x08 ? 'O' : ' ',
						 breakpoints[start] & 0x04 ? 'I' : ' ',
						 breakpoints[start] & 0x02 ? 'W' : ' ',
						 breakpoints[start] & 0x01 ? 'R' : ' ',
						 start,
						 addr];

					} while (addr++ != 0xFFFF);
				}

				else if (array.count == 1)
				{
					breakpoints[[self word:array.firstObject last:cpu.PC]] ^= 0x10;
				}

				else
				{
					uint16_t start = [self word:array.firstObject last:0];
					uint16_t end = [self word:array[1] last:start];

					if (array.count == 2)
					{
						do breakpoints[start] ^= 0x02;
						while (start++ != end);
					}
					else
					{
						uint8_t set = 0x00; for (NSUInteger i = 0; i < array.lastObject.length; i++)
						{
							switch ([array.lastObject.uppercaseString characterAtIndex:i])
							{
								case 'R':
									set |= 0x01;
									break;

								case 'W':
									set |= 0x02;
									break;

								case 'I':
									set |= 0x04;
									break;

								case 'O':
									set |= 0x08;
									break;

								case 'X':
									set |= 0x10;
									break;
							}
						}

						do breakpoints[start] = set;
						while (start++ != end);
					}
				}
			}

			else if (cmd == 'R')
			{
				if (array.count)
					@throw @"Неверное число аргументов";

				[self regs];
			}

			else if ((cmd == 'T' && array.count == 0) || cmd == 'P')
			{
				if (array.count)
					@throw @"Неверное число аргументов";

				const uint8_t *ptr; if (cmd == 'P' && (ptr = [cpu BYTE:cpu.PC]))
				{
					if ((cpu.Z80 ? *ptr : *ptr & 0xCF) == 0xCD || (*ptr & 0xC7) == 0xC4 || (*ptr & 0xC7) == 0xC2)	// CALL/Ccc/Jcc
					{
						breakpoints[cpu.PC + 3] |= 0x20;
						return YES;
					}

					else if ((*ptr & 0xC7) == 0xC7)	// RST
					{
						breakpoints[cpu.PC + 1] |= 0x20;
						return YES;
					}

					else if (cpu.Z80)
					{
						if (*ptr == 0x10 || *ptr == 0x20 || *ptr == 0x28 || *ptr == 0x30 || *ptr == 38)
						{
							breakpoints[cpu.PC + 2] |= 0x20;
							return YES;
						}

						else if (*ptr == 0xED)
						{
							if ((ptr = [cpu BYTE:cpu.PC + 1]) && *ptr >= 0xB0 && *ptr <= 0xBB)
							{
								breakpoints[cpu.PC + 2] |= 0x20;
								return YES;
							}
						}
					}
				}

				[cpu execute:cpu.CLK + 1];
				[self regs];
			}

			else if (cmd == 'L' || cmd == 'U' || cmd == 'Z')
			{
				if (array.count > 2)
					@throw @"Неверное число аргументов";

				if (array.count)
					lastL = [self word:array.firstObject last:0];

				uint16_t end = lastL; if (array.count > 1)
					end = [self word:array[1] last:lastL];

				if (lastL < end) while (lastL < end)
					[self dasm:cmd == 'L' ? cpu.Z80 : cmd == 'Z'];
				else for (int i = 0; i < 16; i++)
					[self dasm:cmd == 'L' ? cpu.Z80 : cmd == 'Z'];
			}
			
			else if (cmd == 'D')
			{
				if (array.count > 2)
					@throw @"Неверное число аргументов";

				if (array.count)
					lastD = [self word:array.firstObject last:0];

				uint16_t end = (lastD + 0x100) & 0xFFF0; if (array.count > 1)
					end = [self word:array[1] last:lastD] + 1;

				do
				{
					NSMutableString *chr = [NSMutableString stringWithFormat:@"%*s", lastD & 0xF, ""];
					[debug print:@"  %04X:%*s", lastD & 0xFFF0, (lastD & 0xF) * 3 + 2, ""];

					do
					{
						const uint8_t *ptr; if ((ptr = [cpu BYTE:lastD++]) && *ptr < unicode.length)
							[chr appendFormat:@"%C", [unicode characterAtIndex:*ptr]];
						else
							[chr appendString:@"."];

						if (ptr)
							[debug print:@"%02X ", *ptr];
						else
							[debug print:@"?? "];

					} while (lastD != end && lastD & 0xF);

					[debug print:@" %*s%@\n", (0x10 - lastD & 0x0F) * 3, "", chr];

				} while (lastD != end);
			}

			else if (cmd == 'F' || cmd == 'S')
			{
				if (array.count < 2 || array.count > 3)
					@throw @"Неверное число аргументов";

				uint16_t start = [self word:array.firstObject last:0];
				uint16_t end = [self word:array[1] last:start];

				uint8_t byte = 0x00; if (array.count > 2)
					byte = [self byte:array[2]];

				do
				{
					uint8_t *ptr; if ((ptr = [cpu BYTE:start]))
					{
						if (cmd == 'F')
							*ptr = byte;

						else if (*ptr == byte)
							[debug print:@"  %04X:  %02X\n", start, *ptr];
					}

				} while (start++ != end);
			}

			else if (cmd == 'T' || cmd == 'C')
			{
				if (array.count < 2 || array.count > 3)
					@throw @"Неверное число аргументов";

				uint16_t start = [self word:array.firstObject last:0];
				uint16_t end = [self word:array[1] last:start];

				uint16_t dest = 0; if (array.count > 2)
					dest = [self word:array[2] last:0];

				do
				{
					uint8_t *ptr, *dst; if ((ptr = [cpu BYTE:start]) && (dst = [cpu BYTE:dest]))
					{
						if (cmd == 'T')
							*dst = *ptr;

						else if (*dst != *ptr)
							[debug print:@"  %04X/%04X:  %02X/%02X\n", start, dest, *ptr, *dst];
					}

					dest++;

				} while (start++ != end);
			}

			else if (cmd == 'I')
			{
				if (array.count > 4)
					@throw @"Неверное число аргументов";

				uint16_t start = [self word:array.firstObject last:0];

				uint16_t end = 0xFFFF; if (array.count >= 2 && array[1].length)
					end = [self word:array[1] last:start];

				if (end < start)
					@throw @"Ошибка в конечном адресе";

				uint16_t pos = 0; if (array.count >= 3)
				{
					pos = [self word:array[2] last:0]; if (array.count >= 4)
						end = start + [self word:array[3] last:pos] - pos;
				}

				NSOpenPanel *panel = [NSOpenPanel openPanel];

				if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
				{
					NSData *data = [NSData dataWithContentsOfURL:panel.URLs.firstObject];

					if (data.length > pos)
					{
						const uint8_t *bytes = [data bytes] + pos;
						NSUInteger length = data.length - pos;

						[debug print:@"  %04X\n", lastD = start];

						do
						{
							uint8_t *ptr; if ((ptr = [cpu BYTE:start]))
								*ptr = *bytes;

							bytes++;

						} while (start++ != end && --length);

						[debug print:@"  %04X\n", (start - 1) & 0xFFFF];
					}
				}
			}

			else if (cmd == 'O')
			{
				if (array.count != 2)
					@throw @"Неверное число аргументов";

				uint16_t start = [self word:array.firstObject last:0];
				uint16_t end = [self word:array[1] last:start];

				if (end < start)
					@throw @"Ошибка в конечном адресе";

				NSMutableData *data = [NSMutableData dataWithLength:end - start + 1];
				uint8_t *mutableBytes = data.mutableBytes;

				[debug print:@"  %04X\n", start];

				const uint8_t *ptr; do
					*mutableBytes++ = (ptr = [cpu BYTE:start]) ? *ptr : 0xFF;
				while (start++ != end);

				[debug print:@"  %04X\n", (start - 1) & 0xFFFF];

				NSSavePanel *panel = [NSSavePanel savePanel];
				panel.allowedFileTypes = @[@"bin"];
				panel.allowsOtherFileTypes = YES;

				if ([panel runModal] == NSFileHandlingPanelOKButton)
					[data writeToURL:panel.URL atomically:YES];
			}

			else if (cmd == 'M')
			{
				if (array.count > 1)
					@throw @"Неверное число аргументов";

				lastM = [self word:array.firstObject last:0];

				uint8_t *ptr; if ((ptr = [cpu BYTE:lastM]))
					[debug print:@"  %04X:  %02X ", lastM, *ptr];
				else
					[debug print:@"  %04X:  ?? ", lastM];

				dbgCmd = 'M';
				return NO;
			}

			else if (cmd == 'A')
			{
				if (array.count > 1)
					@throw @"Неверное число аргументов";

				if (array.count)
					lastA = [self word:array.firstObject last:0];

				[debug print:@"  %04X:  ", lastA];

				dbgCmd = 'A';
				return NO;
			}
			
			else if (cmd == 'X')
			{
				if (array.count)
					@throw @"Неверное число аргументов";

				[debug print:@"  PC-%04X  ", cpu.PC];

				dbgCmd = '1';
				return NO;
			}

			else if (cmd == 'H')
			{
				if (array.count == 1)
				{
					uint16_t value = [self word:array.firstObject last:0];

					if (value < unicode.length)
						[debug print:@"  %04X #%u '%@'\n", value, value, [unicode substringWithRange:NSMakeRange(value, 1)]];
					else
						[debug print:@"  %04X #%u\n", value, value];
				}

				else if (array.count == 2)
				{
					uint16_t v1 = [self word:array.firstObject last:0];
					uint16_t v2 = [self word:array[1] last:v1];

					[debug print:@"  %04X %04X\n", (v1 + v2) & 0xFFFF, (v1 - v2) & 0xFFFF];
				}

				else
				{
					@throw @"Неверное число аргументов";
				}
			}

			else
			{
				@throw @"Неизвестная директива";
			}
		}
	}
	
	@catch (NSException *exception)
	{
		[debug print:@"%@\n# ", exception];
		dbgCmd = 0; return NO;
	}
	
	@catch (NSString *string)
	{
		[debug print:@"%@\n# ", string];
		dbgCmd = 0; return NO;
	}
	
	[debug print:@"# "];
	dbgCmd = 0; return NO;
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
