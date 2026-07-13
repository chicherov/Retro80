/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2026 Andrey Chicherov <andrey@chicherov.ru>

*****/

#include "dasm.h"
#include <algorithm>
#include <array>
#include <cctype>
#include <charconv>
#include <cstring>
#include <iomanip>
#include <sstream>

namespace
{
	const char* rst[8][4] = {
			{"0", "00", "00", "00"},
			{"1", "08", "08", "08"},
			{"2", "10", "10", "10"},
			{"3", "18", "18", "18"},
			{"4", "20", "20", "20"},
			{"5", "28", "28", "28"},
			{"6", "30", "30", "30"},
			{"7", "38", "38", "38"}
	};

	const char* reg[8][4] = {
			{"B", "B",    "B",      "B"},
			{"C", "C",    "C",      "C"},
			{"D", "D",    "D",      "D"},
			{"E", "E",    "E",      "E"},
			{"H", "H",    "IXH",    "IYH"},
			{"L", "L",    "IXL",    "IYL"},
			{"M", "(HL)", "(IX+@)", "(IY+@)"},
			{"A", "A",    "A",      "A"}
	};

	const char* push_rp[4][4] = {
			{"B",   "BC", "BC", "BC"},
			{"D",   "DE", "DE", "DE"},
			{"H",   "HL", "IX", "IY"},
			{"PSW", "AF", "AF", "AF"}
	};

	const char* rp[4][4] = {
			{"B",  "BC", "BC", "BC"},
			{"D",  "DE", "DE", "DE"},
			{"H",  "HL", "IX", "IY"},
			{"SP", "SP", "SP", "SP"}
	};

	const char* bit[8][4] = {
			{nullptr, "0", "0", "0"},
			{nullptr, "1", "1", "1"},
			{nullptr, "2", "2", "2"},
			{nullptr, "3", "3", "3"},
			{nullptr, "4", "4", "4"},
			{nullptr, "5", "5", "5"},
			{nullptr, "6", "6", "6"},
			{nullptr, "7", "7", "7"}
	};

	struct opcode_t
	{
		uint16_t cmd;
		uint8_t size;

		const char* name[2];

		struct arg_t
		{
			int type, shift, mask;
			const char* (*fmt)[4];

		} arg[2];

	} opcodes[] = {

			{0x00,   1, {"NOP",   "NOP"}},
			{0x00,   1, {"NOP*",  nullptr},    {{0,  3, 7}}},

			{0x01,   3, {"LXI",   "LD "},      {{3,  4, 3, rp},      {2}}},
			{0x02,   1, {"STAX",  nullptr},    {{3,  4, 1, rp}}},
			{0x02,   1, {nullptr, "LD "},      {{13, 4, 1, rp},      {3,  0, 0, reg + 7}}},
			{0x03,   1, {"INX",   "INC "},     {{3,  4, 3, rp}}},
			{0x04,   1, {"INR",   "INC "},     {{3,  3, 7, reg}}},
			{0x05,   1, {"DCR",   "DEC "},     {{3,  3, 7, reg}}},
			{0x06,   2, {"MVI",   "LD "},      {{3,  3, 7, reg},     {1}}},
			{0x07,   1, {"RLC",   "RLCA"}},
			{0x08,   1, {nullptr, "EX AF,AF'"}},
			{0x09,   1, {"DAD",   nullptr},    {{3,  4, 3, rp}}},
			{0x09,   1, {nullptr, "ADD "},     {{3,  0, 0, rp + 2},  {3,  4, 3, rp}}},
			{0x0A,   1, {"LDAX",  nullptr},    {{3,  4, 1, rp}}},
			{0x0A,   1, {nullptr, "LD "},      {{3,  0, 0, reg + 7}, {13, 4, 1, rp}}},
			{0x0B,   1, {"DCX",   "DEC "},     {{3,  4, 3, rp}}},
			{0x0F,   1, {"RRC",   "RRCA"}},

			{0x10,   2, {nullptr, "DJNZ "},    {{4}}},
			{0x17,   1, {"RAL",   "RLA"}},
			{0x18,   2, {nullptr, "JR "},      {{4}}},
			{0x1F,   1, {"RAR",   "RRA"}},

			{0x20,   2, {nullptr, "JR NZ,"},   {{4}}},
			{0x22,   3, {"SHLD",  nullptr},    {{2}}},
			{0x22,   3, {nullptr, "LD "},      {{12},                {3,  0, 0, rp + 2}}},
			{0x27,   1, {"DAA",   "DAA"}},
			{0x28,   2, {nullptr, "JR Z,"},    {{4}}},
			{0x2A,   3, {"LHLD",  nullptr},    {{2}}},
			{0x2A,   3, {nullptr, "LD "},      {{3,  0, 0, rp + 2},  {12}}},
			{0x2F,   1, {"CMA",   "CPL"}},

			{0x30,   2, {nullptr, "JR NC,"},   {{4}}},
			{0x32,   3, {"STA",   nullptr},    {{2}}},
			{0x32,   3, {nullptr, "LD "},      {{12},                {3,  0, 0, reg + 7}}},
			{0x37,   1, {"STC",   "SCF"}},
			{0x38,   2, {nullptr, "JR C,"},    {{4}}},
			{0x3A,   3, {"LDA",   nullptr},    {{2}}},
			{0x3A,   3, {nullptr, "LD "},      {{3,  0, 0, reg + 7}, {12}}},
			{0x3F,   1, {"CMC",   "CCF"}},

			{0x76,   1, {"HLT",   "HALT"}},
			{0x40,   1, {"MOV",   "LD "},      {{3,  3, 7, reg},     {3,  0, 7, reg}}},

			{0x80,   1, {"ADD",   "ADD A,"},   {{3,  0, 7, reg}}},
			{0x88,   1, {"ADC",   "ADC A,"},   {{3,  0, 7, reg}}},
			{0x90,   1, {"SUB",   "SUB "},     {{3,  0, 7, reg}}},
			{0x98,   1, {"SBB",   "SBC A,"},   {{3,  0, 7, reg}}},
			{0xA0,   1, {"ANA",   "AND "},     {{3,  0, 7, reg}}},
			{0xA8,   1, {"XRA",   "XOR "},     {{3,  0, 7, reg}}},
			{0xB0,   1, {"ORA",   "OR "},      {{3,  0, 7, reg}}},
			{0xB8,   1, {"CMP",   "CP "},      {{3,  0, 7, reg}}},

			{0xC0,   1, {"RNZ",   "RET NZ"}},
			{0xC1,   1, {"POP",   "POP "},     {{3,  4, 3, push_rp}}},
			{0xC2,   3, {"JNZ",   "JP NZ,"},   {{2}}},
			{0xC3,   3, {"JMP",   "JP "},      {{2}}},
			{0xC4,   3, {"CNZ",   "CALL NZ,"}, {{2}}},
			{0xC5,   1, {"PUSH",  "PUSH "},    {{3,  4, 3, push_rp}}},
			{0xC6,   2, {"ADI",   "ADD A,"},   {{1}}},
			{0xC7,   1, {"RST",   "RST "},     {{3,  3, 7, rst}}},
			{0xC8,   1, {"RZ",    "RET Z"}},
			{0xC9,   1, {"RET",   "RET"}},
			{0xCA,   3, {"JZ",    "JP Z,"},    {{2}}},
			{0xCB,   3, {"JMP*",  nullptr},    {{2}}},
			{0xCC,   3, {"CZ",    "CALL Z,"},  {{2}}},
			{0xCD,   3, {"CALL",  "CALL "},    {{2}}},
			{0xCE,   2, {"ACI",   "ADC A,"},   {{1}}},

			{0xD0,   1, {"RNC",   "RET NC"}},
			{0xD2,   3, {"JNC",   "JP NC,"},   {{2}}},
			{0xD3,   2, {"OUT",   nullptr},    {{1}}},
			{0xD3,   2, {nullptr, "OUT "},     {{11},                {3,  0, 0, reg + 7}}},
			{0xD4,   3, {"CNC",   "CALL NC,"}, {{2}}},
			{0xD6,   2, {"SUI",   "SUB "},     {{1}}},
			{0xD8,   1, {"RC",    "RET C"}},
			{0xD9,   1, {"RET*",  "EXX"}},
			{0xDA,   3, {"JC",    "JP C,"},    {{2}}},
			{0xDB,   2, {"IN",    nullptr},    {{1}}},
			{0xDB,   2, {nullptr, "IN "},      {{3,  0, 0, reg + 7}, {11}}},
			{0xDC,   3, {"CC",    "CALL C,"},  {{2}}},
			{0xDD,   3, {"CALL*", nullptr},    {{2}}},
			{0xDE,   2, {"SBI",   "SBC A,"},   {{1}}},

			{0xE0,   1, {"RPO",   "RET PO"}},
			{0xE2,   3, {"JPO",   "JP PO,"},   {{2}}},
			{0xE3,   1, {"XTHL",  nullptr}},
			{0xE3,   1, {nullptr, "EX (SP),"}, {{3,  0, 0, rp + 2}}},

			{0xE4,   3, {"CPO",   "CALL PO,"}, {{2}}},
			{0xE6,   2, {"ANI",   "AND "},     {{1}}},
			{0xE8,   1, {"RPE",   "RET PE"}},
			{0xE9,   1, {"PCHL",  nullptr}},
			{0xE9,   1, {nullptr, "JP "},      {{13, 0, 0, rp + 2}}},
			{0xEA,   3, {"JPE",   "JP PE,"},   {{2}}},
			{0xEB,   1, {"XCHG",  "EX DE,HL"}},
			{0xEC,   3, {"CPE",   "CALL PE,"}, {{2}}},
			{0xEE,   2, {"XRI",   "XOR "},     {{1}}},
			{0xED,   3, {"CALL*", nullptr},    {{2}}},

			{0xF0,   1, {"RP",    "RET P"}},
			{0xF2,   3, {"JP",    "JP P,"},    {{2}}},
			{0xF3,   1, {"DI",    "DI"}},
			{0xF4,   3, {"CP",    "CALL P,"},  {{2}}},
			{0xF6,   2, {"ORI",   "OR "},      {{1}}},
			{0xF8,   1, {"RM",    "RET M"}},
			{0xF9,   1, {"SPHL"}},
			{0xF9,   1, {nullptr, "LD SP,"},   {{3,  0, 0, rp + 2}}},
			{0xFA,   3, {"JM",    "JP M,"},    {{2}}},
			{0xFB,   1, {"EI",    "EI"}},
			{0xFC,   3, {"CM",    "CALL M,"},  {{2}}},
			{0xFE,   2, {"CPI",   "CP "},      {{1}}},
			{0xFD,   3, {"CALL*", nullptr},    {{2}}},

			{0xCB00, 1, {nullptr, "RLC "},     {{3,  0, 7, reg}}},
			{0xCB08, 1, {nullptr, "RRC "},     {{3,  0, 7, reg}}},
			{0xCB10, 1, {nullptr, "RL "},      {{3,  0, 7, reg}}},
			{0xCB18, 1, {nullptr, "RR "},      {{3,  0, 7, reg}}},
			{0xCB20, 1, {nullptr, "SLA "},     {{3,  0, 7, reg}}},
			{0xCB28, 1, {nullptr, "SRA "},     {{3,  0, 7, reg}}},
			{0xCB30, 1, {nullptr, "SLL "},     {{3,  0, 7, reg}}},
			{0xCB38, 1, {nullptr, "SRL "},     {{3,  0, 7, reg}}},

			{0xCB40, 1, {nullptr, "BIT "},     {{3,  3, 7, bit},     {3,  0, 7, reg}}},
			{0xCB80, 1, {nullptr, "RES "},     {{3,  3, 7, bit},     {3,  0, 7, reg}}},
			{0xCBC0, 1, {nullptr, "SET "},     {{3,  3, 7, bit},     {3,  0, 7, reg}}},

			{0xED70, 1, {nullptr, "IN (C)"}},
			{0xED40, 1, {nullptr, "IN "},      {{3,  3, 7, reg},     {13, 0, 0, reg + 1}}},
			{0xED71, 1, {nullptr, "OUT (C),0"}},
			{0xED41, 1, {nullptr, "OUT "},     {{13, 0, 0, reg + 1}, {3,  3, 7, reg}}},
			{0xED42, 1, {nullptr, "SBC HL,"},  {{3,  4, 3, rp}}},
			{0xED43, 3, {nullptr, "LD "},      {{12},                {3,  4, 3, rp}}},
			{0xED44, 1, {nullptr, "NEG "}},
			{0xED45, 1, {nullptr, "RETN"}},
			{0xED46, 1, {nullptr, "IM 0"}},
			{0xED47, 1, {nullptr, "LD I,A"}},
			{0xED4A, 1, {nullptr, "ADC HL,"},  {{3,  4, 3, rp}}},
			{0xED4B, 3, {nullptr, "LD "},      {{3,  4, 3, rp},      {12}}},
			{0xED4C, 1, {nullptr, "NEG*"}},
			{0xED4D, 1, {nullptr, "RETI"}},
			{0xED4E, 1, {nullptr, "IM 0*"}},
			{0xED4F, 1, {nullptr, "LD R,A"}},

			{0xED54, 1, {nullptr, "NEG*"}},
			{0xED55, 1, {nullptr, "RETN*"}},
			{0xED56, 1, {nullptr, "IM 1"}},
			{0xED57, 1, {nullptr, "LD A,I"}},
			{0xED5C, 1, {nullptr, "NEG*"}},
			{0xED5D, 1, {nullptr, "RETN*"}},
			{0xED5E, 1, {nullptr, "IM 2"}},
			{0xED5F, 1, {nullptr, "LD A,R"}},

			{0xED64, 1, {nullptr, "NEG*"}},
			{0xED65, 1, {nullptr, "RETN*"}},
			{0xED66, 1, {nullptr, "IM 0*"}},
			{0xED67, 1, {nullptr, "RRD"}},
			{0xED6C, 1, {nullptr, "NEG*"}},
			{0xED6D, 1, {nullptr, "RETN*"}},
			{0xED6E, 1, {nullptr, "IM 0*"}},
			{0xED6F, 1, {nullptr, "RLD"}},

			{0xED74, 1, {nullptr, "NEG*"}},
			{0xED75, 1, {nullptr, "RETN*"}},
			{0xED76, 1, {nullptr, "IM 1*"}},
			{0xED7C, 1, {nullptr, "NEG*"}},
			{0xED7D, 1, {nullptr, "RETN*"}},
			{0xED7E, 1, {nullptr, "IM 2*"}},

			{0xEDA0, 1, {nullptr, "LDI"}},
			{0xEDA1, 1, {nullptr, "CPI"}},
			{0xEDA2, 1, {nullptr, "INI"}},
			{0xEDA3, 1, {nullptr, "OUTI"}},

			{0xEDA8, 1, {nullptr, "LDD"}},
			{0xEDA8, 1, {nullptr, "CPD"}},
			{0xEDAA, 1, {nullptr, "IND"}},
			{0xEDAB, 1, {nullptr, "OUTD"}},

			{0xEDB0, 1, {nullptr, "LDIR"}},
			{0xEDB1, 1, {nullptr, "CPIR"}},
			{0xEDB2, 1, {nullptr, "INIR"}},
			{0xEDB3, 1, {nullptr, "OTIR"}},

			{0xEDB8, 1, {nullptr, "LDDR"}},
			{0xEDB8, 1, {nullptr, "CPDR"}},
			{0xEDBA, 1, {nullptr, "INDR"}},
			{0xEDBB, 1, {nullptr, "OTDR"}},

			// --

			{0xDD,   1, {nullptr, "NONI"}, {{0, 5, 1}}},
			{0xED00, 1, {nullptr, "NONI"}, {{0, 0, 255}}},

			{0x00,   0, {"???",   "???"}}
	};
}

std::pair<std::vector<std::optional<uint8_t>>, std::string> dasm(uint16_t addr, const std::function<std::optional<uint8_t>(uint16_t)>& read, bool z80)
{
	std::vector<std::optional<uint8_t>> data;
	std::ostringstream source;

	data.push_back(read(addr++));

	uint16_t cmd = data.front() ? *data.front() : -1;
	std::optional<uint8_t> index;
	int HL = 0;

	if(z80)
	{
		if(cmd == 0xCB || cmd == 0xED)
		{
			data.push_back(read(addr++));
			cmd = data.back() ? (cmd << 8) | *data.back() : -1;
		}

		else if(cmd == 0xDD || cmd == 0xFD)
		{
			if(auto next = read(addr); next && *next != 0xDD && *next != 0xFD && *next != 0xED)
			{
				data.push_back(next);
				addr++;

				HL = cmd == 0xDD ? 1 : 2;
				cmd = *next;

				if(cmd == 0xCB)
				{
					data.push_back(read(addr++));
					index = data.back();

					data.push_back(read(addr++));

					if(data.back())
					{
						if(((cmd = *data.back()) & 0x07) != 0x06)
							source << "LD " << reg[cmd & 0x07][1] << ",";

						cmd = 0xCB06 | (cmd & 0xF8);
					}
					else
					{
						cmd = -1;
					}
				}
			}
		}
	}

	auto op = std::find_if(std::begin(opcodes), std::end(opcodes) - 1, [z80, cmd](const auto& op) {
		return op.name[z80] && (cmd & ~((op.arg[0].mask << op.arg[0].shift) | (op.arg[1].mask << op.arg[1].shift))) == op.cmd;
	});

	if(HL && (cmd & 0xFF00) != 0xCB00 && ((op->arg[0].fmt == reg && (cmd >> (op->arg[0].shift) & op->arg[0].mask) == 6) || (op->arg[1].fmt == reg && (cmd >> (op->arg[1].shift) & op->arg[1].mask) == 6)))
	{
		data.push_back(read(addr++));
		index = data.back();
	}

	if(op->size >= 2)
		data.push_back(read(addr++));

	if(op->size >= 3)
		data.push_back(read(addr++));

	source << op->name[z80] << std::hex << std::uppercase << std::setfill('0');

	for(int i = 0; i < 2 && op->arg[i].type; i++)
	{
		source << (op->arg[i].type > 10 ? (i ? ",(" : "(") : i ? "," : z80 ? "" : " ");
		auto it = std::end(data);

		switch(op->arg[i].type % 10)
		{
			case 2:

				if(*--it)
					source << std::setw(2) << (unsigned) **it;
				else
					source << "??";

			case 1:

				if(*--it)
					source << std::setw(2) << (unsigned) **it;
				else
					source << "??";

				break;

			case 3:
			{
				const char* arg = op->arg[i].fmt[(cmd >> op->arg[i].shift) & op->arg[i].mask][z80 ? 1 + HL : 0];

				if(const char* p = strchr(arg, '@'); p)
				{
					source.write(arg, p - arg);

					if(index)
						source << std::setw(2) << (unsigned) *index;
					else
						source << "??";

					source << ++p;
				}
				else
				{
					source << arg;
				}

				break;
			}

			case 4:

				if(*--it)
					source << std::setw(4) << ((addr + (int8_t) **it) & 0xFFFF);
				else
					source << "????";

				break;
		}

		if(op->arg[i].type > 10)
			source << ")";
	}

	return {data, source.str()};
}

std::vector<uint8_t> assembly(std::string_view source)
{
	auto sp = std::find(std::begin(source), std::end(source), ' ');

	auto opcode = std::find_if(std::begin(opcodes), std::end(opcodes), [cmd = std::string_view(std::begin(source), sp)](const auto& op) {
		return op.name[0] && cmd == op.name[0];
	});

	if(opcode == std::end(opcodes))
		return {};

	sp = std::find_if_not(sp, std::end(source), isspace);
	auto sep = std::find(sp, std::end(source), ',');
	std::array args{std::string_view(sp, sep), std::string_view(sep == std::end(source) ? sep : sep + 1, std::end(source))};

	uint8_t cmd = opcode->cmd;
	uint16_t data = 0;

	for(int i = 0; i < 2; ++i)
	{
		switch(opcode->arg[i].type)
		{
			case 0:

				break;

			case 1:

				if(auto result = std::from_chars(std::begin(args[i]), std::end(args[i]), (uint8_t&) data, 16); result.ec != std::errc() || result.ptr != std::end(args[i]))
					return {};

				break;

			case 2:

				if(auto result = std::from_chars(std::begin(args[i]), std::end(args[i]), data, 16); result.ec != std::errc() || result.ptr != std::end(args[i]))
					return {};

				break;

			case 3:
			{
				auto it = std::find_if(opcode->arg[i].fmt, opcode->arg[i].fmt + opcode->arg[i].mask + 1, [arg = args[i]](auto p) {
					return arg == *p;
				});

				if(auto index = it - opcode->arg[i].fmt; index <= opcode->arg[i].mask)
					cmd |= (index) << opcode->arg[i].shift;
				else
					return {};

				break;
			}

			default:
				return {};
		}
	}

	std::vector<uint8_t> result;
	result.push_back(cmd);

	if(opcode->size == 2 || opcode->size == 3)
		result.push_back(data & 0xFF);

	if(opcode->size == 3)
		result.push_back(data >> 8);

	return result;
}
