/*****

Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2024 Andrey Chicherov <andrey@chicherov.ru>

 *****/

#include "cpu80.h"
#include <utility>

namespace
{
	template<CPU::Type cpuType>
	struct ALU
	{
		uint8_t flags[256]{};

		uint8_t INR[0x100]{};
		uint8_t DCR[0x100]{};

		uint16_t RLC[0x10000]{};
		uint16_t RRC[0x10000]{};
		uint16_t RAL[0x10000]{};
		uint16_t RAR[0x10000]{};
		uint16_t DAA[0x10000]{};

		uint16_t ADD[0x100][0x100]{};
		uint16_t ADC[0x100][0x100]{};
		uint16_t SUB[0x100][0x100]{};
		uint8_t CMP[0x100][0x100]{};
		uint16_t SBB[0x100][0x100]{};
		uint16_t AND[0x100][0x100]{};

		ALU()
		{
			for(unsigned byte = 0x00; byte <= 0xFF; byte++)
			{
				uint8_t flag = (byte ? 0x04 : 0x44) | (cpuType == CPU::Type::Z80 ? 0x00 : 0x02) | (byte & (cpuType == CPU::Type::Z80 ? 0xA8 : 0x80));

				if(byte & 0x01) flag ^= 0x04;
				if(byte & 0x02) flag ^= 0x04;
				if(byte & 0x04) flag ^= 0x04;
				if(byte & 0x08) flag ^= 0x04;
				if(byte & 0x10) flag ^= 0x04;
				if(byte & 0x20) flag ^= 0x04;
				if(byte & 0x40) flag ^= 0x04;
				if(byte & 0x80) flag ^= 0x04;

				flags[byte] = flag;
			}

			for(unsigned byte = 0x00; byte <= 0xFF; byte++)
			{
				INR[byte] = flags[byte] | ((byte & 0x0F) == 0x00 ? 0x10 : 0x00);
				if(cpuType == CPU::Type::Z80) INR[byte] = (INR[byte] & 0xFB) | ((byte == 0x80) << 2);

				DCR[byte] = flags[byte] | ((byte & 0x0F) != 0x0F ? 0x10 : 0x00);
				if(cpuType == CPU::Type::Z80) DCR[byte] = ((DCR[byte] & 0xFB) | ((byte == 0x7F) << 2) | 0x02) ^ 0x10;

				for(unsigned data = 0x00; data <= 0xFF; data++)
				{
					ADD[byte][data] = ((byte + data) << 8) | flags[(byte + data) & 0xFF] | ((byte & 0x0F) + (data & 0x0F) > 0x0F ? 0x10 : 0x00) | (byte + data > 0xFF ? 0x01 : 0x00);
					if(cpuType == CPU::Type::Z80) ADD[byte][data] = (ADD[byte][data] & 0xFFFB) | (((ADD[byte][data] & 1) << 2) ^ (((byte ^ data ^ (byte + data)) & 0x80) >> 5));

					ADC[byte][data] = ((byte + data + 1) << 8) | flags[(byte + data + 1) & 0xFF] | ((byte & 0x0F) + (data & 0x0F) + 1 > 0x0F ? 0x10 : 0x00) | (byte + data + 1 > 0xFF ? 0x01 : 0x00);
					if(cpuType == CPU::Type::Z80) ADC[byte][data] = (ADC[byte][data] & 0xFFFB) | (((ADC[byte][data] & 1) << 2) ^ (((byte ^ data ^ (byte + data + 1)) & 0x80) >> 5));

					SUB[byte][data] = ((byte - data) << 8) | flags[(byte - data) & 0xFF] | ((byte & 0x0F) < (data & 0x0F) ? 0x00 : 0x10) | (byte < data ? 0x01 : 0x00);
					if(cpuType == CPU::Type::Z80) SUB[byte][data] = (SUB[byte][data] & 0xFFEB) | (((SUB[byte][data] & 1) << 2) ^ (((byte ^ data ^ (byte - data)) & 0x80) >> 5)) | ((byte ^ data ^ (byte - data)) & 0x10) | 0x02;

					CMP[byte][data] = SUB[byte][data] & 0xFF;
					if(cpuType == CPU::Type::Z80) CMP[byte][data] = (CMP[byte][data] & 0xD7) | (data & 0x28);

					SBB[byte][data] = ((byte - data - 1) << 8) | flags[(byte - data - 1) & 0xFF] | ((byte & 0x0F) < (data & 0x0F) + 1 ? 0x00 : 0x10) | (byte < data + 1 ? 0x01 : 0x00);
					if(cpuType == CPU::Type::Z80) SBB[byte][data] = (SBB[byte][data] & 0xFFEB) | (((SBB[byte][data] & 1) << 2) ^ (((byte ^ data ^ (byte - data - 1)) & 0x80) >> 5)) | ((byte ^ data ^ (byte - data - 1)) & 0x10) | 0x02;

					AND[byte][data] = ((byte & data) << 8) | flags[byte & data] | (cpuType == CPU::Type::Z80 || (byte | data) & 0x08 ? 0x10 : 0x00);
				}
			}

			for(unsigned word = 0x0000; word <= 0xFFFF; word++)
			{
				uint8_t F = word & 0xFF;
				uint8_t A = word >> 8;

				uint8_t RLC_A = (A << 1) | (A >> 7);
				uint8_t RLC_F = (F & ~1) | (RLC_A & 1);
				if(cpuType == CPU::Type::Z80) RLC_F = (RLC_F & 0xC5) | (RLC_A & 0x28);
				RLC[word] = ((RLC_A) << 8) | RLC_F;

				uint8_t RRC_F = (F & ~1) | (A & 1);
				uint8_t RRC_A = (A >> 1) | (A << 7);
				if(cpuType == CPU::Type::Z80) RRC_F = (RRC_F & 0xC5) | (RRC_A & 0x28);
				RRC[word] = ((RRC_A) << 8) | RRC_F;

				uint8_t RAL_A = (A << 1) | (F & 1);
				uint8_t RAL_F = (F & ~1) | (A >> 7);
				if(cpuType == CPU::Type::Z80) RAL_F = (RAL_F & 0xC5) | (RAL_A & 0x28);
				RAL[word] = ((RAL_A) << 8) | RAL_F;

				uint8_t RAR_A = (A >> 1) | (F << 7);
				uint8_t RAR_F = (F & ~1) | (A & 1);
				if(cpuType == CPU::Type::Z80) RAR_F = (RAR_F & 0xC5) | (RAR_A & 0x28);
				RAR[word] = ((RAR_A) << 8) | RAR_F;

				if(cpuType != CPU::Type::Z80)
				{
					uint8_t T = ((A & 0x0F) > 0x09 || F & 0x10) ? 0x06 : 0x00;
					if(A + T > 0x9F || F & 0x01) T += 0x60;
					DAA[word] = ADD[A][T] | (F & 1);
				}
				else if(F & 0x02)
				{
					if(((A & 0x0F) > 0x09 || F & 0x10))
						F &= ~((((A -= 0x06) & 0x0F) < 0x0A) << 4);

					if(word > 0x99FF || F & 0x01)
					{
						A -= 0x60;
						F |= 0x01;
					}

					DAA[word] |= (A << 8) | flags[A] | 0x02 | (F & 0x11);
				}
				else
				{
					uint8_t T = ((A & 0x0F) > 0x09 || F & 0x10) ? 0x06 : 0x00;
					if(A + T > 0x9F || F & 0x01) T += 0x60;
					DAA[word] = (ADD[A][T] | (F & 1)) & ~0x04;
					DAA[word] |= flags[(A + T) & 0xFF] & 0x04;
				}
			}
		}
	};

	template<CPU::Type cpuType>
	struct Core
	{
		ICore *m_core;
		CPU *m_cpu;

		static const unsigned timings[256];

		explicit Core(CPU *cpu) : m_cpu(cpu), m_core(cpu->m_core)
		{
		}

		uint8_t fetch(uint16_t PC)
		{
			if(m_cpu->m_breakpoints && m_cpu->m_breakpoints[PC] & 0x01 && (m_cpu->m_break & ~0xFFFF) == 0)
				m_cpu->m_break |= ((uint64_t) PC << 16) | 0x0100000000;

			m_core->CLOCK += 18;
			uint8_t data = m_core->MEMR(PC, 0xA2);

			if constexpr(cpuType == CPU::Type::Z80)
			{
				m_core->CLOCK += timings[data];
			}
			else
			{
				if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
					m_core->CLOCK += timings[data];
			}

			return data;
		}

		uint8_t get(uint16_t addr, uint8_t status)
		{
			if(m_cpu->m_breakpoints && m_cpu->m_breakpoints[addr] & 0x01 && (m_cpu->m_break & ~0xFFFF) == 0)
				m_cpu->m_break |= ((uint64_t) addr << 16) | 0x0100000000;

			m_core->CLOCK += 18;
			uint8_t data = m_core->MEMR(addr, status);

			if constexpr(cpuType == CPU::Type::Z80)
			{
				m_core->CLOCK += 9;
			}
			else
			{
				if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
					m_core->CLOCK += 9;
			}

			return data;
		}

		void put(uint16_t addr, uint8_t data, uint8_t status)
		{
			if(m_cpu->m_breakpoints && m_cpu->m_breakpoints[addr] & 0x02 && (m_cpu->m_break & ~0xFFFF) == 0)
				m_cpu->m_break |= ((uint64_t) addr << 16) | 0x0200000000;

			m_core->CLOCK += 18;
			m_core->MEMW(addr, data, status);

			if constexpr(cpuType == CPU::Type::Z80)
			{
				m_core->CLOCK += 9;
			}
			else
			{
				if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(true))
					m_core->CLOCK += 9;
			}
		}

		uint8_t inp(uint16_t addr)
		{
			if(m_cpu->m_breakpoints && m_cpu->m_breakpoints[addr] & 0x04 && (m_cpu->m_break & ~0xFFFF) == 0)
				m_cpu->m_break |= ((uint64_t) addr << 16) | 0x0400000000;

			if constexpr(cpuType == CPU::Type::Z80)
				m_core->CLOCK += 27;
			else
				m_core->CLOCK += 18;

			uint8_t data = m_core->IOR(addr, 0x42);

			if constexpr(cpuType == CPU::Type::Z80)
			{
				m_core->CLOCK += 9;
			}
			else
			{
				if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
					m_core->CLOCK += 9;
			}

			return data;
		}

		void out(uint16_t addr, uint8_t data)
		{
			if(m_cpu->m_breakpoints && m_cpu->m_breakpoints[addr] & 0x08 && (m_cpu->m_break & ~0xFFFF) == 0)
				m_cpu->m_break |= ((uint64_t) addr << 16) | 0x0800000000;

			if constexpr(cpuType == CPU::Type::Z80)
				m_core->CLOCK += 27;
			else
				m_core->CLOCK += 18;

			m_core->IOW(addr, data, 0x10);

			if constexpr(cpuType == CPU::Type::Z80)
			{
				m_core->CLOCK += 9;
			}
			else
			{
				if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(true))
					m_core->CLOCK += 9;
			}
		}

		uint8_t inta(uint16_t PC, uint8_t status)
		{
			m_core->CLOCK += 18;
			uint8_t data = m_core->INTA(PC, status);

			if constexpr(cpuType == CPU::Type::Z80)
			{
				m_core->CLOCK += 27;
			}
			else
			{
				if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
					m_core->CLOCK += 18;
			}

			return data;
		}

		void hlta(uint16_t PC, uint8_t status)
		{
			m_core->CLOCK += 18;
			m_core->HLTA(PC, status);

			if constexpr(cpuType == CPU::Type::Z80)
			{
				m_core->CLOCK += 18;
			}
			else
			{
				if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
					m_core->CLOCK += 18;
			}
		}
	};

	template<>
	constinit const unsigned Core<CPU::Type::I8080>::timings[256] = {
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
		27, 18, 18, 18, 27, 27, 18, 27, 27, 27, 18, 18, 27, 27, 18, 27,
		27, 18, 18, 18, 27, 27, 18, 27, 27, 27, 18, 18, 27, 27, 18, 27
	};

	template<>
	constinit const unsigned Core<CPU::Type::I8085>::timings[256] = {
	};

	template<>
	constinit const unsigned Core<CPU::Type::VM1>::timings[256] = {
	};

	template<>
	constinit const unsigned Core<CPU::Type::Z80>::timings[256] = {
		18, 18, 18, 36, 18, 18, 18, 18, 18, 81, 18, 36, 18, 18, 18, 18,
		27, 18, 18, 36, 18, 18, 18, 18, 18, 81, 18, 36, 18, 18, 18, 18,
		18, 18, 18, 36, 18, 18, 18, 18, 18, 81, 18, 36, 18, 18, 18, 18,
		18, 18, 18, 36, 18, 18, 18, 18, 18, 81, 18, 36, 18, 18, 18, 18,

		18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
		18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
		18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
		18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,

		18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
		18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
		18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
		18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,

		27, 18, 18, 18, 18, 27, 18, 27, 27, 18, 18, 18, 18, 18, 18, 27,
		27, 18, 18, 18, 18, 27, 18, 27, 27, 18, 18, 18, 18, 18, 18, 27,
		27, 18, 18, 18, 18, 27, 18, 27, 27, 18, 18, 18, 18, 18, 18, 27,
		27, 18, 18, 18, 18, 27, 18, 27, 27, 36, 18, 18, 18, 18, 18, 27
	};
}

template<CPU::Type cpuType>
bool CPU::internal(uint64_t limit)
{
	if(m_breakpoints && m_break & 0x4000000000 && m_breakpoints[PC] & 0x30)
	{
		m_break = ((uint64_t) m_breakpoints[PC] << 32) | ((uint64_t) PC << 16) | (m_break & 0xFFFF);
		return false;
	}

	static const ALU<cpuType> ALU;
	Core<cpuType> core(this);

	while(m_core->CLOCK < limit)
	{
		if constexpr(cpuType == Type::Z80)
		{
			if(m_core->NMI < m_core->CLOCK)
			{
				m_core->NMI = std::numeric_limits<uint64_t>::max();

				m_core->CLOCK += 45;

				m_core->INTE(IF = false);
				HLT = false;

				core.put(--SP, PCH, 0x04);
				core.put(--SP, PCL, 0x04);

				PC = 0x0066;
				continue;
			}
		}

		if(IF && m_core->IRQ < m_core->CLOCK)
		{
			if(m_core->IRQLoop)
				m_core->IRQ = m_core->CLOCK - (m_core->CLOCK - m_core->IRQ) % m_core->IRQLoop + m_core->IRQLoop;
			else
				m_core->IRQ = std::numeric_limits<uint64_t>::max();

			uint8_t RST = core.inta(PC, HLT ? 0x2B : 0x23);

			m_core->INTE(IF = IFF2 = false);
			HLT = false;

			core.put(--SP, PCH, 0x04);
			core.put(--SP, PCL, 0x04);

			switch(IM)
			{
				case 0:    // IM 0

					PC = RST & 0x0038;
					break;

				case 1:    // IM 1

					PC = 0x0038;
					break;

				case 2:    // IM 2

					PCL = core.get(((I << 8) | RST) + 0, 0x82);
					PCH = core.get(((I << 8) | RST) + 1, 0x82);
					break;
			}

			continue;
		}

		union { uint16_t HL; struct { uint8_t L; uint8_t H; }; } *pHL = static_cast<decltype(pHL)>((void *) &HL);

		union { uint16_t WZ; struct { uint8_t Z; uint8_t W; }; };

		m_break = PC;

		uint8_t CMD = HLT ? core.hlta(PC, 0x88), 0x00 : core.fetch(PC++);

		while(true)
		{
			if constexpr(cpuType == Type::Z80)
			{
				if((R & 0x7F) == 0x7F)
					R &= 0x80;
				else
					R++;
			}

			switch(CMD)
			{
				case 0x00:    // NOP
				{
					break;
				}

				case 0x01:    // LXI B,nnnn; LD BC,nnnn
				{
					C = core.get(PC++, 0x82);
					B = core.get(PC++, 0x82);
					break;
				}

				case 0x02:    // STAX B; LD (BC),A
				{
					core.put(BC, A, 0x00);
					break;
				}

				case 0x03:    // INX B; INC BC
				{
					BC++;
					break;
				}

				case 0x04:    // INR B; INC B
				{
					F = (F & 0x01) | ALU.INR[++B];
					break;
				}

				case 0x05:    // DCR B; DEC B
				{
					F = (F & 0x01) | ALU.DCR[--B];
					break;
				}

				case 0x06:    // MVI B,nn; LD B,nn
				{
					B = core.get(PC++, 0x82);
					break;
				}

				case 0x07:    // RLC; RLCA
				{
					AF = ALU.RLC[AF];
					break;
				}

				case 0x08:    // ?NOP; EX AF,AF'
				{
					if constexpr (cpuType == Type::Z80)
					{
						std::swap(AF, AF1);
					}

					break;
				}

				case 0x09:    // DAD B; ADD HL,BC
				{
					uint32_t sum = pHL->HL + BC;

					if constexpr (cpuType == Type::Z80)
						F = (F & 0xC4) | ((sum & 0x10000) >> 16) | ((sum & 0x2800) >> 8) | (((pHL->HL ^ BC ^ sum) & 0x1000) >> 8);
					else
						F = (F & 0xFE) | ((sum & 0x10000) >> 16);

					if constexpr (cpuType != Type::Z80)
					{
						m_core->CLOCK += 18;
						if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
							m_core->CLOCK += 9;

						m_core->CLOCK += 18;
						if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
							m_core->CLOCK += 9;
					}

					pHL->HL = sum;
					break;
				}

				case 0x0A:    // LDAX B; LD A,(BC)
				{
					A = core.get(BC, 0x82);
					break;
				}

				case 0x0B:    // DCX B; DEC BC
				{
					BC--;
					break;
				}

				case 0x0C:    // INR C; INC C
				{
					F = (F & 0x01) | ALU.INR[++C];
					break;
				}

				case 0x0D:    // DCR C; DEC C
				{
					F = (F & 0x01) | ALU.DCR[--C];
					break;
				}

				case 0x0E:    // MVI C,nn; LD C,nn
				{
					C = core.get(PC++, 0x82);
					break;
				}

				case 0x0F:    // RRC; RRCA
				{
					AF = ALU.RRC[AF];
					break;
				}

				case 0x10:    // ?NOP; DJNZ dd
				{
					if constexpr (cpuType == Type::Z80)
					{
						int8_t addr = core.get(PC++, 0x82);

						if(--B)
						{
							m_core->CLOCK += 45;
							PC += addr;
						}
					}

					break;
				}

				case 0x11:    // LXI D,nnnn; LD DE,nnnn
				{
					E = core.get(PC++, 0x82);
					D = core.get(PC++, 0x82);
					break;
				}

				case 0x12:    // STAX D; LD (DE),A
				{
					core.put(DE, A, 0x00);
					break;
				}

				case 0x13:    // INX D; INC DE
				{
					DE++;
					break;
				}

				case 0x14:    // INR D; INC D
				{
					F = (F & 0x01) | ALU.INR[++D];
					break;
				}

				case 0x15:    // DCR D; DEC D
				{
					F = (F & 0x01) | ALU.DCR[--D];
					break;
				}

				case 0x16:    // MVI D,nn; LD D,nn
				{
					D = core.get(PC++, 0x82);
					break;
				}

				case 0x17:    // RAL; RLA
				{
					AF = ALU.RAL[AF];
					break;
				}

				case 0x18:    // ?NOP; JR dd
				{
					if constexpr(cpuType == Type::Z80)
					{
						int8_t addr = core.get(PC++, 0x82);
						m_core->CLOCK += 45;
						PC += addr;
					}

					break;
				}

				case 0x19:    // DAD D; ADD HL,DE
				{
					uint32_t sum = pHL->HL + DE;

					if constexpr (cpuType == Type::Z80)
						F = (F & 0xC4) | ((sum & 0x10000) >> 16) | ((sum & 0x2800) >> 8) | (((pHL->HL ^ DE ^ sum) & 0x1000) >> 8);
					else
						F = (F & 0xFE) | ((sum & 0x10000) >> 16);

					if constexpr (cpuType != Type::Z80)
					{
						m_core->CLOCK += 18;
						if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
							m_core->CLOCK += 9;

						m_core->CLOCK += 18;
						if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
							m_core->CLOCK += 9;
					}

					pHL->HL = sum;
					break;
				}

				case 0x1A:    // LDAX D; LD A,(DE)
				{
					A = core.get(DE, 0x82);
					break;
				}

				case 0x1B:    // DCX B; DEC BC
				{
					DE--;
					break;
				}

				case 0x1C:    // INR E; INC E
				{
					F = (F & 0x01) | ALU.INR[++E];
					break;
				}

				case 0x1D:    // DCR E; DEC E
				{
					F = (F & 0x01) | ALU.DCR[--E];
					break;
				}

				case 0x1E:    // MVI E,nn; LD E,nn
				{
					E = core.get(PC++, 0x82);
					break;
				}

				case 0x1F:    // RAR; RRA
				{
					AF = ALU.RAR[AF];
					break;
				}

				case 0x20:    // ?NOP; JR NZ,dd
				{
					if constexpr(cpuType == Type::Z80)
					{
						int8_t addr = core.get(PC++, 0x82);

						if((F & 0x40) == 0)
						{
							m_core->CLOCK += 45;
							PC += addr;
						}
					}

					break;
				}

				case 0x21:    // LXI H,nnnn; LD HL,nnnn
				{
					pHL->L = core.get(PC++, 0x82);
					pHL->H = core.get(PC++, 0x82);
					break;
				}

				case 0x22:    // SHLD nnnn; LD (nnnn),HL
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					core.put(WZ++, pHL->L, 0x00);
					core.put(WZ, pHL->H, 0x00);
					break;
				}

				case 0x23:    // INX H; INC HL
				{
					pHL->HL++;
					break;
				}

				case 0x24:    // INR H; INC H
				{
					F = (F & 0x01) | ALU.INR[++pHL->H];
					break;
				}

				case 0x25:    // DCR H; DEC H
				{
					F = (F & 0x01) | ALU.DCR[--pHL->H];
					break;
				}

				case 0x26:    // MVI H,nn; LD H,nn
				{
					pHL->H = core.get(PC++, 0x82);
					break;
				}

				case 0x27:    // DAA
				{
					AF = ALU.DAA[AF];
					break;
				}

				case 0x28:    // ?NOP; JR Z,dd
				{
					if constexpr(cpuType == Type::Z80)
					{
						int8_t addr = core.get(PC++, 0x82);

						if(F & 0x40)
						{
							m_core->CLOCK += 45;
							PC += addr;
						}
					}

					break;
				}

				case 0x29:    // DAD H; ADD HL,HL
				{
					uint32_t sum = pHL->HL + pHL->HL;

					if constexpr (cpuType == Type::Z80)
						F = (F & 0xC4) | ((sum & 0x10000) >> 16) | ((sum & 0x2800) >> 8) | ((sum & 0x1000) >> 8);
					else
						F = (F & 0xFE) | ((sum & 0x10000) >> 16);

					if constexpr (cpuType != Type::Z80)
					{
						m_core->CLOCK += 18;
						if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
							m_core->CLOCK += 9;

						m_core->CLOCK += 18;
						if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
							m_core->CLOCK += 9;
					}

					pHL->HL = sum;
					break;
				}

				case 0x2A:    // LHLD nnnn; LD HL,(nnnn)
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					pHL->L = core.get(WZ++, 0x82);
					pHL->H = core.get(WZ, 0x82);
					break;
				}

				case 0x2B:    // DCX H; DEC HL
				{
					pHL->HL--;
					break;
				}

				case 0x2C:    // INR L; INC L
				{
					F = (F & 0x01) | ALU.INR[++pHL->L];
					break;
				}

				case 0x2D:    // DCR L; DEC L
				{
					F = (F & 0x01) | ALU.DCR[--pHL->L];
					break;
				}

				case 0x2E:    // MVI L,nn; LD L,nn
				{
					pHL->L = core.get(PC++, 0x82);
					break;
				}

				case 0x2F:    // CMA; CPL
				{
					A = ~A;

					if constexpr(cpuType == Type::Z80)
					{
						F = (F & 0xC5) | (A & 0x28) | 0x12;
					}

					break;
				}

				case 0x30:    // ?NOP; JR NC,dd
				{
					if constexpr(cpuType == Type::Z80)
					{
						int8_t addr = core.get(PC++, 0x82);

						if((F & 0x01) == 0)
						{
							m_core->CLOCK += 45;
							PC += addr;
						}
					}

					break;
				}

				case 0x31:    // LXI SP,nnnn; LD SP,nnnn
				{
					SPL = core.get(PC++, 0x82);
					SPH = core.get(PC++, 0x82);
					break;
				}

				case 0x32:    // STA nnnn; LD (nnnn),A
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);
					core.put(WZ, A, 0x00);
					break;
				}

				case 0x33:    // INX SP; INC SP
				{
					SP++;
					break;
				}

				case 0x34:    // INR M; INC (HL)
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					uint8_t M = core.get(addr, 0x82);

					if constexpr(cpuType == Type::Z80)
					{
						m_core->CLOCK += 9;
					}

					F = (F & 0x01) | ALU.INR[++M];
					core.put(addr, M, 0x00);
					break;
				}

				case 0x35:    // DCR M; DEC (HL)
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					uint8_t M = core.get(addr, 0x82);

					if constexpr(cpuType == Type::Z80)
					{
						m_core->CLOCK += 9;
					}

					F = (F & 0x01) | ALU.DCR[--M];
					core.put(addr, M, 0x00);
					break;
				}

				case 0x36:    // MVI M,nn; LD (HL),nn
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					uint8_t M = core.get(PC++, 0x82);
					core.put(addr, M, 0x00);
					break;
				}

				case 0x37:    // STC; SCF
				{
					F |= 0x01;

					if constexpr(cpuType == Type::Z80)
					{
						F = (F & 0xC5) | (A & 0x28);
					}

					break;
				}

				case 0x38:    // ?NOP; JR C,dd
				{
					if constexpr(cpuType == Type::Z80)
					{
						int8_t addr = core.get(PC++, 0x82);

						if(F & 0x01)
						{
							m_core->CLOCK += 45;
							PC += addr;
						}
					}

					break;
				}

				case 0x39:    // DAD SP; ADD HL,SP
				{
					uint32_t sum = pHL->HL + SP;

					if constexpr (cpuType == Type::Z80)
						F = (F & 0xC4) | ((sum & 0x10000) >> 16) | ((sum & 0x2800) >> 8) | (((pHL->HL ^ SP ^ sum) & 0x1000) >> 8);
					else
						F = (F & 0xFE) | ((sum & 0x10000) >> 16);

					if constexpr (cpuType != Type::Z80)
					{
						m_core->CLOCK += 18;
						if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
							m_core->CLOCK += 9;

						m_core->CLOCK += 18;
						if(m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
							m_core->CLOCK += 9;
					}

					pHL->HL = sum;
					break;
				}

				case 0x3A:    // LDA nnnn; LD A,(nnnn)
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);
					A = core.get(WZ, 0x82);
					break;
				}

				case 0x3B:    // DCX SP; DEC SP
				{
					SP--;
					break;
				}

				case 0x3C:    // INR A; INC A
				{
					F = (F & 0x01) | ALU.INR[++A];
					break;
				}

				case 0x3D:    // DCR A; DEC A
				{
					F = (F & 0x01) | ALU.DCR[--A];
					break;
				}

				case 0x3E:    // MVI A,nn; LD A,nn
				{
					A = core.get(PC++, 0x82);
					break;
				}

				case 0x3F:    // CMC; CCF
				{
					if constexpr (cpuType == Type::Z80)
						F = (F & 0xC4) | (A & 0x28) | ((F & 0x01) << 4) | (~F & 0x01);
					else
						F ^= 0x01;

					break;
				}

				case 0x40:    // MOV B, B
				{
					B = B;
					break;
				}

				case 0x41:    // MOV B, C
				{
					B = C;
					break;
				}

				case 0x42:    // MOV B, D
				{
					B = D;
					break;
				}

				case 0x43:    // MOV B, E
				{
					B = E;
					break;
				}

				case 0x44:    // MOV B, H
				{
					B = pHL->H;
					break;
				}

				case 0x45:    // MOV B, L
				{
					B = pHL->L;
					break;
				}

				case 0x46:    // MOV B, M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					B = core.get(addr, 0x82);
					break;
				}

				case 0x47:    // MOV B, A
				{
					B = A;
					break;
				}

				case 0x48:    // MOV C, B
				{
					C = B;
					break;
				}

				case 0x49:    // MOV C, C
				{
					C = C;
					break;
				}

				case 0x4A:    // MOV C, D
				{
					C = D;
					break;
				}

				case 0x4B:    // MOV C, E
				{
					C = E;
					break;
				}

				case 0x4C:    // MOV C, H
				{
					C = pHL->H;
					break;
				}

				case 0x4D:    // MOV C, L
				{
					C = pHL->L;
					break;
				}

				case 0x4E:    // MOV C, M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					C = core.get(addr, 0x82);
					break;
				}

				case 0x4F:    // MOV C, A
				{
					C = A;
					break;
				}

				case 0x50:    // MOV D, B
				{
					D = B;
					break;
				}

				case 0x51:    // MOV D, C
				{
					D = C;
					break;
				}

				case 0x52:    // MOV D, D
				{
					D = D;
					break;
				}

				case 0x53:    // MOV D, E
				{
					D = E;
					break;
				}

				case 0x54:    // MOV D, H
				{
					D = pHL->H;
					break;
				}

				case 0x55:    // MOV D, L
				{
					D = pHL->L;
					break;
				}

				case 0x56:    // MOV D, M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					D = core.get(addr, 0x82);
					break;
				}

				case 0x57:    // MOV D, A
				{
					D = A;
					break;
				}

				case 0x58:    // MOV E, B
				{
					E = B;
					break;
				}

				case 0x59:    // MOV E, C
				{
					E = C;
					break;
				}

				case 0x5A:    // MOV E, D
				{
					E = D;
					break;
				}

				case 0x5B:    // MOV E, E
				{
					E = E;
					break;
				}

				case 0x5C:    // MOV E, H
				{
					E = pHL->H;
					break;
				}

				case 0x5D:    // MOV E, L
				{
					E = pHL->L;
					break;
				}

				case 0x5E:    // MOV E, M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					E = core.get(addr, 0x82);
					break;
				}

				case 0x5F:    // MOV E, A
				{
					E = A;
					break;
				}

				case 0x60:    // MOV H, B
				{
					pHL->H = B;
					break;
				}

				case 0x61:    // MOV H, C
				{
					pHL->H = C;
					break;
				}

				case 0x62:    // MOV H, D
				{
					pHL->H = D;
					break;
				}

				case 0x63:    // MOV H, E
				{
					pHL->H = E;
					break;
				}

				case 0x64:    // MOV H, H
				{
					pHL->H = pHL->H;
					break;
				}

				case 0x65:    // MOV H, L
				{
					pHL->H = pHL->L;
					break;
				}

				case 0x66:    // MOV H, M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					H = core.get(addr, 0x82);
					break;
				}

				case 0x67:    // MOV H, A
				{
					pHL->H = A;
					break;
				}

				case 0x68:    // MOV L, B
				{
					pHL->L = B;
					break;
				}

				case 0x69:    // MOV L, C
				{
					pHL->L = C;
					break;
				}

				case 0x6A:    // MOV L, D
				{
					pHL->L = D;
					break;
				}

				case 0x6B:    // MOV L, E
				{
					pHL->L = E;
					break;
				}

				case 0x6C:    // MOV L, H
				{
					pHL->L = pHL->H;
					break;
				}

				case 0x6D:    // MOV L, L
				{
					pHL->L = pHL->L;
					break;
				}

				case 0x6E:    // MOV L, M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					L = core.get(addr, 0x82);
					break;
				}

				case 0x6F:    // MOV L, A
				{
					pHL->L = A;
					break;
				}

				case 0x70:    // MOV M, B
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					core.put(addr, B, 0x00);
					break;
				}

				case 0x71:    // MOV M, C
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					core.put(addr, C, 0x00);
					break;
				}

				case 0x72:    // MOV M, D
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					core.put(addr, D, 0x00);
					break;
				}

				case 0x73:    // MOV M, E
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					core.put(addr, E, 0x00);
					break;
				}

				case 0x74:    // MOV M, H
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					core.put(addr, H, 0x00);
					break;
				}

				case 0x75:    // MOV M, L
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					core.put(addr, L, 0x00);
					break;
				}

				case 0x76:    // HLT
				{
					HLT = true;
					break;
				}

				case 0x77:    // MOV M, A
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					core.put(addr, A, 0x00);
					break;
				}

				case 0x78:    // MOV A, B
				{
					A = B;
					break;
				}

				case 0x79:    // MOV A, C
				{
					A = C;
					break;
				}

				case 0x7A:    // MOV A, D
				{
					A = D;
					break;
				}

				case 0x7B:    // MOV A, E
				{
					A = E;
					break;
				}

				case 0x7C:    // MOV A, H
				{
					A = pHL->H;
					break;
				}

				case 0x7D:    // MOV A, L
				{
					A = pHL->L;
					break;
				}

				case 0x7E:    // MOV A, M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					A = core.get(addr, 0x82);
					break;
				}

				case 0x7F:    // MOV A, A
				{
					A = A;
					break;
				}

				case 0x80:    // ADD B
				{
					AF = ALU.ADD[A][B];
					break;
				}

				case 0x81:    // ADD C
				{
					AF = ALU.ADD[A][C];
					break;
				}

				case 0x82:    // ADD D
				{
					AF = ALU.ADD[A][D];
					break;
				}

				case 0x83:    // ADD E
				{
					AF = ALU.ADD[A][E];
					break;
				}

				case 0x84:    // ADD H
				{
					AF = ALU.ADD[A][pHL->H];
					break;
				}

				case 0x85:    // ADD L
				{
					AF = ALU.ADD[A][pHL->L];
					break;
				}

				case 0x86:    // ADD M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					AF = ALU.ADD[A][core.get(addr, 0x82)];
					break;
				}

				case 0x87:    // ADD A
				{
					AF = ALU.ADD[A][A];
					break;
				}

				case 0x88:    // ADC B
				{
					if(F & 1)
						AF = ALU.ADC[A][B];
					else
						AF = ALU.ADD[A][B];

					break;
				}

				case 0x89:    // ADC C
				{
					if(F & 1)
						AF = ALU.ADC[A][C];
					else
						AF = ALU.ADD[A][C];

					break;
				}

				case 0x8A:    // ADC D
				{
					if(F & 1)
						AF = ALU.ADC[A][D];
					else
						AF = ALU.ADD[A][D];

					break;
				}

				case 0x8B:    // ADC E
				{
					if(F & 1)
						AF = ALU.ADC[A][E];
					else
						AF = ALU.ADD[A][E];

					break;
				}

				case 0x8C:    // ADC H
				{
					if(F & 1)
						AF = ALU.ADC[A][pHL->H];
					else
						AF = ALU.ADD[A][pHL->H];

					break;
				}

				case 0x8D:    // ADC L
				{
					if(F & 1)
						AF = ALU.ADC[A][pHL->L];
					else
						AF = ALU.ADD[A][pHL->L];

					break;
				}

				case 0x8E:    // ADC M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					if(F & 1)
						AF = ALU.ADC[A][core.get(addr, 0x82)];
					else
						AF = ALU.ADD[A][core.get(addr, 0x82)];

					break;
				}

				case 0x8F:    // ADC A
				{
					if(F & 1)
						AF = ALU.ADC[A][A];
					else
						AF = ALU.ADD[A][A];

					break;
				}

				case 0x90:    // SUB B
				{
					AF = ALU.SUB[A][B];
					break;
				}

				case 0x91:    // SUB C
				{
					AF = ALU.SUB[A][C];
					break;
				}

				case 0x92:    // SUB D
				{
					AF = ALU.SUB[A][D];
					break;
				}

				case 0x93:    // SUB E
				{
					AF = ALU.SUB[A][E];
					break;
				}

				case 0x94:    // SUB H
				{
					AF = ALU.SUB[A][pHL->H];
					break;
				}

				case 0x95:    // SUB L
				{
					AF = ALU.SUB[A][pHL->L];
					break;
				}

				case 0x96:    // SUB M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					AF = ALU.SUB[A][core.get(addr, 0x82)];
					break;
				}

				case 0x97:    // SUB A
				{
					AF = ALU.SUB[A][A];
					break;
				}

				case 0x98:    // SBB B
				{
					if(F & 1)
						AF = ALU.SBB[A][B];
					else
						AF = ALU.SUB[A][B];

					break;
				}

				case 0x99:    // SBB C
				{
					if(F & 1)
						AF = ALU.SBB[A][C];
					else
						AF = ALU.SUB[A][C];

					break;
				}

				case 0x9A:    // SBB D
				{
					if(F & 1)
						AF = ALU.SBB[A][D];
					else
						AF = ALU.SUB[A][D];

					break;
				}

				case 0x9B:    // SBB E
				{
					if(F & 1)
						AF = ALU.SBB[A][E];
					else
						AF = ALU.SUB[A][E];

					break;
				}

				case 0x9C:    // SBB H
				{
					if(F & 1)
						AF = ALU.SBB[A][pHL->H];
					else
						AF = ALU.SUB[A][pHL->H];

					break;
				}

				case 0x9D:    // SBB L
				{
					if(F & 1)
						AF = ALU.SBB[A][pHL->L];
					else
						AF = ALU.SUB[A][pHL->L];

					break;
				}

				case 0x9E:    // SBB M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					if(F & 1)
						AF = ALU.SBB[A][core.get(addr, 0x82)];
					else
						AF = ALU.SUB[A][core.get(addr, 0x82)];

					break;
				}

				case 0x9F:    // SBB A
				{
					if(F & 1)
						AF = ALU.SBB[A][A];
					else
						AF = ALU.SUB[A][A];

					break;
				}

				case 0xA0:    // ANA B
				{
					AF = ALU.AND[A][B];
					break;
				}

				case 0xA1:    // ANA C
				{
					AF = ALU.AND[A][C];
					break;
				}

				case 0xA2:    // ANA D
				{
					AF = ALU.AND[A][D];
					break;
				}

				case 0xA3:    // ANA E
				{
					AF = ALU.AND[A][E];
					break;
				}

				case 0xA4:    // ANA H
				{
					AF = ALU.AND[A][pHL->H];
					break;
				}

				case 0xA5:    // ANA L
				{
					AF = ALU.AND[A][pHL->L];
					break;
				}

				case 0xA6:    // ANA M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					AF = ALU.AND[A][core.get(addr, 0x82)];
					break;
				}

				case 0xA7:    // ANA A
				{
					AF = ALU.AND[A][A];
					break;
				}

				case 0xA8:    // XRA B
				{
					F = ALU.flags[A ^= B];
					break;
				}

				case 0xA9:    // XRA C
				{
					F = ALU.flags[A ^= C];
					break;
				}

				case 0xAA:    // XRA D
				{
					F = ALU.flags[A ^= D];
					break;
				}

				case 0xAB:    // XRA E
				{
					F = ALU.flags[A ^= E];
					break;
				}

				case 0xAC:    // XRA H
				{
					F = ALU.flags[A ^= pHL->H];
					break;
				}

				case 0xAD:    // XRA L
				{
					F = ALU.flags[A ^= pHL->L];
					break;
				}

				case 0xAE:    // XRA M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					F = ALU.flags[A ^= core.get(addr, 0x82)];
					break;
				}

				case 0xAF:    // XRA A
				{
					F = ALU.flags[A ^= A];
					break;
				}

				case 0xB0:    // ORA B
				{
					F = ALU.flags[A |= B];
					break;
				}

				case 0xB1:    // ORA C
				{
					F = ALU.flags[A |= C];
					break;
				}

				case 0xB2:    // ORA D
				{
					F = ALU.flags[A |= D];
					break;
				}

				case 0xB3:    // ORA E
				{
					F = ALU.flags[A |= E];
					break;
				}

				case 0xB4:    // ORA H
				{
					F = ALU.flags[A |= pHL->H];
					break;
				}

				case 0xB5:    // ORA L
				{
					F = ALU.flags[A |= pHL->L];
					break;
				}

				case 0xB6:    // ORA M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					F = ALU.flags[A |= core.get(addr, 0x82)];
					break;
				}

				case 0xB7:    // ORA A
				{
					F = ALU.flags[A |= A];
					break;
				}

				case 0xB8:    // CMP B
				{
					F = ALU.CMP[A][B];
					break;
				}

				case 0xB9:    // CMP C
				{
					F = ALU.CMP[A][C];
					break;
				}

				case 0xBA:    // CMP D
				{
					F = ALU.CMP[A][D];
					break;
				}

				case 0xBB:    // CMP E
				{
					F = ALU.CMP[A][E];
					break;
				}

				case 0xBC:    // CMP H
				{
					F = ALU.CMP[A][pHL->H];
					break;
				}

				case 0xBD:    // CMP L
				{
					F = ALU.CMP[A][pHL->L];
					break;
				}

				case 0xBE:    // CMP M
				{
					uint16_t addr = pHL->HL;

					if constexpr(cpuType == Type::Z80)
					{
						if(&pHL->HL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);
							m_core->CLOCK += 45;
						}
					}

					F = ALU.CMP[A][core.get(addr, 0x82)];
					break;
				}

				case 0xBF:    // CMP A
				{
					F = ALU.CMP[A][A];
					break;
				}

				case 0xC0:    // RNZ
				{
					if((F & 0x40) == 0)
					{
						PCL = core.get(SP++, 0x86);
						PCH = core.get(SP++, 0x86);
					}

					break;
				}

				case 0xC1:    // POP B
				{
					C = core.get(SP++, 0x86);
					B = core.get(SP++, 0x86);
					break;
				}

				case 0xC2:    // JNZ
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if((F & 0x40) == 0)
						PC = WZ;

					break;
				}

				case 0xC3:    // JMP
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);
					PC = WZ;
					break;
				}

				case 0xC4:    // CNZ
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if((F & 0x40) == 0)
					{
						if constexpr(cpuType == Type::Z80)
						{
							m_core->CLOCK += 9;
						}

						core.put(--SP, PCH, 0x04);
						core.put(--SP, PCL, 0x04);
						PC = WZ;
					}

					break;
				}

				case 0xC5:    // PUSH B
				{
					core.put(--SP, B, 0x04);
					core.put(--SP, C, 0x04);
					break;
				}

				case 0xC6:    // ADI
				{
					AF = ALU.ADD[A][core.get(PC++, 0x82)];
					break;
				}

				case 0xC7:    // RST
				case 0xCF:
				case 0xD7:
				case 0xDF:
				case 0xE7:
				case 0xEF:
				case 0xF7:
				case 0xFF:
				{
					core.put(--SP, PCH, 0x04);
					core.put(--SP, PCL, 0x04);
					PC = CMD & 0x38;
					break;
				}

				case 0xC8:    // RZ
				{
					if(F & 0x40)
					{
						PCL = core.get(SP++, 0x86);
						PCH = core.get(SP++, 0x86);
					}

					break;
				}

				case 0xC9:    // RET
				{
					PCL = core.get(SP++, 0x86);
					PCH = core.get(SP++, 0x86);
					break;
				}

				case 0xCA:    // JZ
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if(F & 0x40)
						PC = WZ;

					break;
				}

				case 0xCC:    // CZ
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if(F & 0x40)
					{
						if constexpr(cpuType == Type::Z80)
						{
							m_core->CLOCK += 9;
						}

						core.put(--SP, PCH, 0x04);
						core.put(--SP, PCL, 0x04);
						PC = WZ;
					}

					break;
				}

				case 0xCD:    // CALL
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if constexpr(cpuType == Type::Z80)
					{
						m_core->CLOCK += 9;
					}

					core.put(--SP, PCH, 0x04);
					core.put(--SP, PCL, 0x04);
					PC = WZ;

					break;
				}

				case 0xCE:    // ACI
				{
					if(F & 1)
						AF = ALU.ADC[A][core.get(PC++, 0x82)];
					else
						AF = ALU.ADD[A][core.get(PC++, 0x82)];

					break;
				}

				case 0xD0:    // RNC
				{
					if((F & 0x01) == 0)
					{
						PCL = core.get(SP++, 0x86);
						PCH = core.get(SP++, 0x86);
					}

					break;
				}

				case 0xD1:    // POP D
				{
					E = core.get(SP++, 0x86);
					D = core.get(SP++, 0x86);
					break;
				}

				case 0xD2:    // JNC
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if((F & 0x01) == 0x00)
						PC = WZ;

					break;
				}

				case 0xD3:    // OUT
				{
					Z = core.get(PC++, 0x82);

					if constexpr(cpuType == Type::Z80)
					{
						W = A;
					}
					else
					{
						W = Z;
					}

					core.out(WZ, A);
					break;
				}

				case 0xD4:    // CNC
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if((F & 0x01) == 0x00)
					{
						if constexpr(cpuType == Type::Z80)
						{
							m_core->CLOCK += 9;
						}

						core.put(--SP, PCH, 0x04);
						core.put(--SP, PCL, 0x04);
						PC = WZ;
					}

					break;
				}

				case 0xD5:    // PUSH D
				{
					core.put(--SP, D, 0x04);
					core.put(--SP, E, 0x04);
					break;
				}

				case 0xD6:    // SUI
				{
					AF = ALU.SUB[A][core.get(PC++, 0x82)];
					break;
				}

				case 0xD8:    // RC
				{
					if(F & 0x01)
					{
						PCL = core.get(SP++, 0x86);
						PCH = core.get(SP++, 0x86);
					}

					break;
				}

				case 0xD9:    // ?RET; EXX
				{
					if constexpr(cpuType != Type::Z80)
					{
						PCL = core.get(SP++, 0x86);
						PCH = core.get(SP++, 0x86);
					}
					else
					{
						std::swap(BC,BC1);
						std::swap(DE,DE1);
						std::swap(HL,HL1);
					}

					break;
				}

				case 0xDA:    // JC
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if(F & 0x01)
						PC = WZ;

					break;
				}

				case 0xDB:    // IN
				{
					Z = core.get(PC++, 0x82);

					if constexpr(cpuType == Type::Z80)
					{
						W = A;
					}
					else
					{
						W = Z;
					}

					A = core.inp(WZ);
					break;
				}

				case 0xDC:    // CC
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if(F & 0x01)
					{
						if constexpr(cpuType == Type::Z80)
						{
							m_core->CLOCK += 9;
						}

						core.put(--SP, PCH, 0x04);
						core.put(--SP, PCL, 0x04);
						PC = WZ;
					}

					break;
				}

				case 0xDD:    // ?CALL; // DD prefix
				{
					if constexpr(cpuType != Type::Z80)
					{
						CMD = 0xCD;
						continue;
					}
					else
					{
						pHL = static_cast<decltype(pHL)>((void *) &IX);
						CMD = core.fetch(PC++);
						continue;
					}
				}

				case 0xDE:    // SBI
				{
					if(F & 1)
						AF = ALU.SBB[A][core.get(PC++, 0x82)];
					else
						AF = ALU.SUB[A][core.get(PC++, 0x82)];

					break;
				}

				case 0xE0:    // RPO
				{
					if((F & 0x04) == 0)
					{
						PCL = core.get(SP++, 0x86);
						PCH = core.get(SP++, 0x86);
					}

					break;
				}

				case 0xE1:    // POP H
				{
					pHL->L = core.get(SP++, 0x86);
					pHL->H = core.get(SP++, 0x86);
					break;
				}

				case 0xE2:    // JPO
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if((F & 0x04) == 0x00)
						PC = WZ;

					break;
				}

				case 0xE3:    // XTHL; EX (SP),HL
				{
					Z = core.get(SP, 0x86);
					W = core.get(SP + 1, 0x86);

					if constexpr(cpuType == Type::Z80)
					{
						m_core->CLOCK += 9;
					}

					core.put(SP + 1, pHL->H, 0x04);

					if constexpr(cpuType == Type::Z80)
					{
						core.put(SP, pHL->L, 0x04);
						m_core->CLOCK += 18;
					}
					else
					{
						uint64_t M5 = m_core->CLOCK + 9 * 5;
						core.put(SP, pHL->L, 0x04);

						if(m_core->CLOCK < M5)
							m_core->CLOCK = M5;
					}

					pHL->HL = WZ;
					break;
				}

				case 0xE4:    // CPO
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if((F & 0x04) == 0x00)
					{
						if constexpr(cpuType == Type::Z80)
						{
							m_core->CLOCK += 9;
						}

						core.put(--SP, PCH, 0x04);
						core.put(--SP, PCL, 0x04);
						PC = WZ;
					}

					break;
				}

				case 0xE5:    // PUSH H
				{
					core.put(--SP, pHL->H, 0x04);
					core.put(--SP, pHL->L, 0x04);
					break;
				}

				case 0xE6:    // ANI
				{
					AF = ALU.AND[A][core.get(PC++, 0x82)];
					break;
				}

				case 0xE8:    // RPE
				{
					if(F & 0x04)
					{
						PCL = core.get(SP++, 0x86);
						PCH = core.get(SP++, 0x86);
					}

					break;
				}

				case 0xE9:    // PCHL
				{
					PC = pHL->HL;
					break;
				}

				case 0xEA:    // JPE
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if(F & 0x04)
						PC = WZ;

					break;
				}

				case 0xEB:    // XCHG; EX DE,HL
				{
					std::swap(HL,DE);
					break;
				}

				case 0xEC:    // CPE
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if(F & 0x04)
					{
						if constexpr(cpuType == Type::Z80)
						{
							m_core->CLOCK += 9;
						}

						core.put(--SP, PCH, 0x04);
						core.put(--SP, PCL, 0x04);
						PC = WZ;
					}

					break;
				}

				case 0xEE:    // XRI
				{
					F = ALU.flags[A ^= core.get(PC++, 0x82)];
					break;
				}

				case 0xF0:    // RP
				{
					if((F & 0x80) == 0)
					{
						PCL = core.get(SP++, 0x86);
						PCH = core.get(SP++, 0x86);
					}

					break;
				}

				case 0xF1:    // POP PSW
				{
					F = core.get(SP++, 0x86);
					A = core.get(SP++, 0x86);
					break;
				}

				case 0xF2:    // JP
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if((F & 0x80) == 0x00)
						PC = WZ;

					break;
				}

				case 0xF3:    // DI
				{
					m_core->INTE(IF = IFF2 = false);
					break;
				}

				case 0xF4:    // CP
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if((F & 0x80) == 0x00)
					{
						if constexpr(cpuType == Type::Z80)
						{
							m_core->CLOCK += 9;
						}

						core.put(--SP, PCH, 0x04);
						core.put(--SP, PCL, 0x04);
						PC = WZ;
					}

					break;
				}

				case 0xF5:    // PUSH PSW
				{
					core.put(--SP, A, 0x04);

					if constexpr(cpuType == Type::Z80)
					{
						core.put(--SP, F, 0x04);
					}
					else
					{
						core.put(--SP, (F & 0xD7) | 0x02, 0x04);
					}

					break;
				}

				case 0xF6:    // ORI
				{
					F = ALU.flags[A |= core.get(PC++, 0x82)];
					break;
				}

				case 0xF8:    // RM
				{
					if(F & 0x80)
					{
						PCL = core.get(SP++, 0x86);
						PCH = core.get(SP++, 0x86);
					}

					break;
				}

				case 0xF9:    // SPHL; LD SP,HL
				{
					SP = pHL->HL;
					break;
				}

				case 0xFA:    // JM
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if(F & 0x80)
						PC = WZ;

					break;
				}

				case 0xFB:    // EI
				{
					m_core->INTE(IF = IFF2 = true);

					if constexpr(cpuType == Type::Z80)
					{
						CMD = core.fetch(PC++);
						continue;
					}

					break;
				}

				case 0xFC:    // CM
				{
					Z = core.get(PC++, 0x82);
					W = core.get(PC++, 0x82);

					if(F & 0x80)
					{
						if constexpr(cpuType == Type::Z80)
						{
							m_core->CLOCK += 9;
						}

						core.put(--SP, PCH, 0x04);
						core.put(--SP, PCL, 0x04);
						PC = WZ;
					}

					break;
				}

				case 0xFD:    // ?CALL; FD prefix
				{
					if constexpr(cpuType != Type::Z80)
					{
						CMD = 0xCD;
						continue;
					}

					else
					{
						pHL = static_cast<decltype(pHL)>((void *) &IY);
						CMD = core.fetch(PC++);
						continue;
					}
				}

				case 0xFE:    // CPI
				{
					F = ALU.CMP[A][core.get(PC++, 0x82)];
					break;
				}

// -------------------------------------------------------------

				case 0xCB:    // ?JMP; CB Prefix
				{
					if constexpr(cpuType != Type::Z80)
					{
						CMD = 0xC3;
						continue;
					}
					else
					{
						uint16_t addr = pHL->HL;

						if((void *) pHL != &HL)
						{
							addr += (int8_t) core.get(PC++, 0x82);

							CMD = core.get(PC++, 0x82);
							m_core->CLOCK += 18;

							W = core.get(addr, 0x82);
							m_core->CLOCK += 9;
						}

						else
						{
							CMD = core.get(PC++, 0x82);
							m_core->CLOCK += 9;

							switch(CMD & 0x07)
							{
								case 0x00:

									W = B;
									break;

								case 0x01:

									W = C;
									break;

								case 0x02:

									W = D;
									break;

								case 0x03:

									W = E;
									break;

								case 0x04:

									W = H;
									break;

								case 0x05:

									W = L;
									break;

								case 0x06:

									W = core.get(HL, 0x82);
									m_core->CLOCK += 9;
									break;

								case 0x07:

									W = A;
									break;
							}
						}

						switch(CMD & 0xC0)
						{
							case 0x00:
							{
								Z = F;

								switch(CMD & 0x38)
								{
									case 0x00:    // RLC

										F = W >> 7;
										F |= ALU.flags[W = (W << 1) | (W >> 7)];
										break;

									case 0x08:    // RRC

										F = W & 1;
										F |= ALU.flags[W = (W >> 1) | (W << 7)];
										break;

									case 0x10:    // RL

										F = W >> 7;
										F |= ALU.flags[W = (W << 1) | (Z & 1)];
										break;

									case 0x18:    // RR

										F = W & 1;
										F |= ALU.flags[W = (W >> 1) | (Z << 7)];
										break;

									case 0x20:    // SLA

										F = W >> 7;
										F |= ALU.flags[W = W << 1];
										break;

									case 0x28:    // SRA

										F = W & 1;
										F |= ALU.flags[W = (W >> 1) | (W & 0x80)];
										break;

									case 0x30:    // SLA 1

										F = W >> 7;
										F |= ALU.flags[W = ((W << 1) | 0x01)];
										break;

									case 0x38:    // SLR

										F = W & 1;
										F |= ALU.flags[W = W >> 1];
								}

								break;
							}

							case 0x40:    // BIT n,r
							{
								if(W & (1 << ((CMD >> 3) & 7)))
									F = (F & 0x01) | 0x10 | (((CMD & 0x38) == 0x38) << 7);
								else
									F = (F & 0x01) | 0x54;

								if((CMD & 0x07) != 0x06)
									F |= (W & 0x28);

								break;
							}

							case 0x80:    // RES n, r

								W &= ~(1 << ((CMD >> 3) & 7));
								break;

							case 0xC0:    // SET n, r

								W |= (1 << ((CMD >> 3) & 7));
								break;
						}

						if((CMD & 0xC0) != 0x40)
						{
							if((void*)pHL != &HL || (CMD & 0x07) == 0x06)
								core.put(addr, W, 0x00);

							switch(CMD & 0x07)
							{
								case 0:

									B = W;
									break;

								case 1:

									C = W;
									break;

								case 2:

									D = W;
									break;

								case 3:

									E = W;
									break;

								case 4:

									H = W;
									break;

								case 5:

									L = W;
									break;

								case 7:

									A = W;
									break;
							}
						}
					}

					break;
				}

// -------------------------------------------------------------

				case 0xED:    // ?CALL; ED prefix
				{
					if constexpr(cpuType != Type::Z80)
					{
						CMD = 0xCD;
						continue;
					}
					else
					{
						CMD = core.get(PC++, 0x82);
						m_core->CLOCK += 9;

						switch(CMD)
						{
							case 0x40:    // IN B,(C)
							{
								F = (F & 0x01) | ALU.flags[B = core.inp(BC)];
								break;
							}

							case 0x41:    // OUT (C),B
							{
								core.out(BC, B);
								break;
							}

							case 0x42:    // SBC HL,BC
							{
								if(F & 1)
									WZ = ALU.SBB[L][C];
								else
									WZ = ALU.SUB[L][C];

								L = W;

								if(Z & 1)
									WZ = ALU.SBB[H][B] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
								else
									WZ = ALU.SUB[H][B] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

								H = W;
								F = Z;

								m_core->CLOCK += 63;
								break;
							}

							case 0x43:    // LD (nnnn),BC
							{
								Z = core.get(PC++, 0x82);
								W = core.get(PC++, 0x82);
								core.put(WZ++, C, 0x00);
								core.put(WZ, B, 0x00);
								break;
							}

							case 0x44:    // NEG
							case 0x4C:    // NEG∗∗
							case 0x54:    // NEG∗∗
							case 0x5C:    // NEG∗∗
							case 0x64:    // NEG∗∗
							case 0x6C:    // NEG∗∗
							case 0x74:    // NEG∗∗
							case 0x7C:    // NEG∗∗

							{
								AF = ALU.SUB[0][A];
								break;
							}

							case 0x45:    // RETN
							case 0x55:    // RETN∗∗
							case 0x5D:    // RETN∗∗
							case 0x65:    // RETN∗∗
							case 0x6D:    // RETN∗∗
							case 0x75:    // RETN∗∗
							case 0x7D:    // RETN∗∗

							{
								m_core->INTE(IF = IFF2);

								CMD = 0xC9;
								continue;
							}

							case 0x46:    // IM 0
							case 0x4E:    // IM 0∗∗
							case 0x66:    // IM 0∗∗
							case 0x6E:    // IM 0∗∗

							{
								IM = 0;
								break;
							}

							case 0x47:    // LD I,A
							{
								I = A;

								m_core->CLOCK += 9;
								break;
							}

							case 0x48:    // IN C,(C)
							{
								F = (F & 0x01) | ALU.flags[C = core.inp(BC)];
								break;
							}

							case 0x49:    // OUT (C),C
							{
								core.out(BC, C);
								break;
							}

							case 0x4A:    // ADC HL,BC
							{
								if(F & 1)
									WZ = ALU.ADC[L][C];
								else
									WZ = ALU.ADD[L][C];

								L = W;

								if(Z & 1)
									WZ = ALU.ADC[H][B] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
								else
									WZ = ALU.ADD[H][B] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

								H = W;
								F = Z;

								m_core->CLOCK += 63;
								break;
							}

							case 0x4B:    // LD BC,(nnnn)
							{
								Z = core.get(PC++, 0x82);
								W = core.get(PC++, 0x82);
								C = core.get(WZ++, 0x82);
								B = core.get(WZ, 0x82);
								break;
							}

							case 0x4D:    // RETI
							{
								m_core->INTE(IF = IFF2);

								CMD = 0xC9;
								continue;
							}

							case 0x4F:    // LD R,A
							{
								R = A;

								m_core->CLOCK += 9;
								break;
							}

							case 0x50:    // IN D,(C)
							{
								F = (F & 0x01) | ALU.flags[D = core.inp(BC)];
								break;
							}

							case 0x51:    // OUT (C),D
							{
								core.out(BC, D);
								break;
							}

							case 0x52:    // SBC HL,DE
							{
								if(F & 1)
									WZ = ALU.SBB[L][E];
								else
									WZ = ALU.SUB[L][E];

								L = W;

								if(Z & 1)
									WZ = ALU.SBB[H][D] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
								else
									WZ = ALU.SUB[H][D] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

								H = W;
								F = Z;

								m_core->CLOCK += 63;
								break;
							}

							case 0x53:    // LD (nnnn),DE
							{
								Z = core.get(PC++, 0x82);
								W = core.get(PC++, 0x82);
								core.put(WZ++, E, 0x00);
								core.put(WZ, D, 0x00);
								break;
							}

							case 0x56:    // IM 1
							case 0x76:    // IM 1∗∗
							{
								IM = 1;
								break;
							}

							case 0x57:    // LD A,I
							{
								F = (F & 0x29) | (I & 0x80) | ((I == 0) << 6) | (IFF2 << 2);
								A = I;

								m_core->CLOCK += 9;
								break;
							}

							case 0x58:    // IN E,(C)
							{
								F = (F & 0x01) | ALU.flags[E = core.inp(BC)];
								break;
							}

							case 0x59:    // OUT (C),E
							{
								core.out(BC, E);
								break;
							}

							case 0x5A:    // ADC HL,DE
							{
								if(F & 1)
									WZ = ALU.ADC[L][E];
								else
									WZ = ALU.ADD[L][E];

								L = W;

								if(Z & 1)
									WZ = ALU.ADC[H][D] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
								else
									WZ = ALU.ADD[H][D] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

								H = W;
								F = Z;

								m_core->CLOCK += 63;
								break;
							}

							case 0x5B:    // LD DE,(nnnn)
							{
								Z = core.get(PC++, 0x82);
								W = core.get(PC++, 0x82);
								E = core.get(WZ++, 0x82);
								D = core.get(WZ, 0x82);
								break;
							}

							case 0x5E:    // IM 2
							case 0x7E:    // IM 2∗∗
							{
								IM = 2;
								break;
							}

							case 0x5F:    // LD A,R
							{
								F = (F & 0x29) | (R & 0x80) | ((R == 0) << 6) | (IFF2 << 2);
								A = R;

								m_core->CLOCK += 9;
								break;
							}

							case 0x60:    // IN H,(C)
							{
								F = (F & 0x01) | ALU.flags[H = core.inp(BC)];
								break;
							}

							case 0x61:    // OUT (C),H
							{
								core.out(BC, H);
								break;
							}

							case 0x62:    // SBC HL,HL
							{
								if(F & 1)
									WZ = ALU.SBB[L][L];
								else
									WZ = ALU.SUB[L][L];

								L = W;

								if(Z & 1)
									WZ = ALU.SBB[H][H] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
								else
									WZ = ALU.SUB[H][H] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

								H = W;
								F = Z;

								m_core->CLOCK += 63;
								break;
							}

							case 0x63:    // LD (nnnn),HL
							{
								Z = core.get(PC++, 0x82);
								W = core.get(PC++, 0x82);
								core.put(WZ++, L, 0x00);
								core.put(WZ, H, 0x00);
								break;
							}

							case 0x67:    // RRD
							{
								Z = core.get(HL, 0x82);
								m_core->CLOCK += 36;

								core.put(HL, (Z >> 4) | (A << 4), 0x00);
								A = (A & 0xF0) | (Z & 0x0F);
								F = (F & 0x01) | ALU.flags[A];
								break;
							}

							case 0x68:    // IN L,(C)
							{
								F = (F & 0x01) | ALU.flags[L = core.inp(BC)];
								break;
							}

							case 0x69:    // OUT (C),L
							{
								core.out(BC, L);
								break;
							}

							case 0x6A:    // ADC HL,HL
							{
								if(F & 1)
									WZ = ALU.ADC[L][L];
								else
									WZ = ALU.ADD[L][L];

								L = W;

								if(Z & 1)
									WZ = ALU.ADC[H][H] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
								else
									WZ = ALU.ADD[H][H] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

								H = W;
								F = Z;

								m_core->CLOCK += 63;
								break;
							}

							case 0x6B:    // LD HL,(nnnn)
							{
								Z = core.get(PC++, 0x82);
								W = core.get(PC++, 0x82);
								L = core.get(WZ++, 0x82);
								H = core.get(WZ, 0x82);
								break;
							}

							case 0x6F:    // RLD
							{
								Z = core.get(HL, 0x82);
								m_core->CLOCK += 36;

								core.put(HL, (Z << 4) | (A & 0x0F), 0x00);
								A = (A & 0xF0) | (Z >> 4);
								F = (F & 0x01) | ALU.flags[A];
								break;
							}

							case 0x70:    // IN (C)
							{
								F = (F & 0x01) | ALU.flags[core.inp(BC)];
								break;
							}

							case 0x71:    // OUT (C), 0
							{
								core.out(BC, 0);
								break;
							}

							case 0x72:    // SBC HL,SP
							{
								if(F & 1)
									WZ = ALU.SBB[L][SPL];
								else
									WZ = ALU.SUB[L][SPL];

								L = W;

								if(Z & 1)
									WZ = ALU.SBB[H][SPH] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
								else
									WZ = ALU.SUB[H][SPH] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

								H = W;
								F = Z;

								m_core->CLOCK += 63;
								break;
							}

							case 0x73:    // LD (xxxx),SP
							{
								Z = core.get(PC++, 0x82);
								W = core.get(PC++, 0x82);
								core.put(WZ++, SPL, 0x00);
								core.put(WZ, SPH, 0x00);
								break;
							}

							case 0x77:    // NOP**
							{
								break;
							}

							case 0x78:    // IN A,(C)
							{
								F = (F & 0x01) | ALU.flags[A = core.inp(BC)];
								break;
							}

							case 0x79:    // OUT (C),A
							{
								core.out(BC, A);
								break;
							}

							case 0x7A:    // ADC HL,SP
							{
								if(F & 1)
									WZ = ALU.ADC[L][SPL];
								else
									WZ = ALU.ADD[L][SPL];

								L = W;

								if(Z & 1)
									WZ = ALU.ADC[H][SPH] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
								else
									WZ = ALU.ADD[H][SPH] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

								H = W;
								F = Z;

								m_core->CLOCK += 63;
								break;
							}

							case 0x7B:    // LD SP,(nnnn)
							{
								Z = core.get(PC++, 0x82);
								W = core.get(PC++, 0x82);
								SPL = core.get(WZ++, 0x82);
								SPH = core.get(WZ, 0x82);
								break;
							}

							case 0x7F:    // NOP∗∗
							{
								break;
							}

							case 0xA0:    // LDI
							case 0xB0:    // LDIR
							{
								W = core.get(HL++, 0x82);
								core.put(DE++, W, 0x00);
								m_core->CLOCK += 18;
								BC--;

								W += A;

								F = (F & 0xC1) | (W & 0x08) | ((W & 0x02) << 4) | ((BC != 0) << 2);

								if(CMD == 0xB0 && BC)
								{
									m_core->CLOCK += 45;
									PC -= 2;
								}

								break;
							}

							case 0xA1:    // CPI
							case 0xB1:    // CPIR
							{
								WZ = ALU.SUB[A][core.get(HL++, 0x82)];
								m_core->CLOCK += 45;
								BC--;

								W -= (Z & 0x10) >> 4;
								F = (F & 0x01) | (Z & 0xD2) | (W & 0x08) | ((W & 0x02) << 4) | ((BC != 0) << 2);

								if(CMD == 0xB1 && (F & 0x44) == 0x04)
								{
									m_core->CLOCK += 45;
									PC -= 2;
								}

								break;
							}

							case 0xA2:    // INI
							case 0xB2:    // INIR
							{
								m_core->CLOCK += 9;
								Z = core.inp(BC);
								core.put(HL++, Z, 0x00);

								F = (F & 0x01) | ALU.DCR[--B] | (Z & 0x80) >> 6;

								if(CMD == 0xB2 && (F & 0x40) == 0x40)
								{
									m_core->CLOCK += 45;
									PC -= 2;
								}

								break;
							}

							case 0xA3:    // OUTI
							case 0xB3:    // OTIR
							{
								m_core->CLOCK += 9;
								Z = core.get(HL++, 0x82);
								core.out(BC, Z);

								F = (F & 0x01) | ALU.DCR[--B] | (Z & 0x80) >> 6;

								if(CMD == 0xB3 && (F & 0x40) == 0x40)
								{
									m_core->CLOCK += 45;
									PC -= 2;
								}

								break;
							}

							case 0xA8:    // LDD
							case 0xB8:    // LDDR
							{
								W = core.get(HL--, 0x82);
								core.put(DE--, W, 0x00);
								m_core->CLOCK += 18;
								BC--;

								W += A;
								F = (F & 0xC1) | (W & 0x08) | ((W & 0x02) << 4) | ((BC != 0) << 2);

								if(CMD == 0xB8 && BC)
								{
									m_core->CLOCK += 45;
									PC -= 2;
								}

								break;
							}

							case 0xA9:    // CPD
							case 0xB9:    // CPDR
							{
								WZ = ALU.SUB[A][core.get(HL--, 0x82)];
								m_core->CLOCK += 45;
								BC--;

								W -= (Z & 0x10) >> 4;
								F = (F & 0x01) | (Z & 0xD2) | (W & 0x08) | ((W & 0x02) << 4) | ((BC != 0) << 2);

								if(CMD == 0xB9 && (F & 0x44) == 0x04)
								{
									m_core->CLOCK += 45;
									PC -= 2;
								}

								break;
							}

							case 0xAA:    // IND
							case 0xBA:    // INDR
							{
								m_core->CLOCK += 9;
								Z = core.inp(BC);
								core.put(HL--, Z, 0x00);

								F = (F & 0x01) | ALU.DCR[--B] | (Z & 0x80) >> 6;

								if(CMD == 0xBA && (F & 0x40) == 0x40)
								{
									m_core->CLOCK += 45;
									PC -= 2;
								}

								break;
							}

							case 0xAB:    // OUTD
							case 0xBB:    // OTDR
							{
								m_core->CLOCK += 9;
								Z = core.get(pHL->HL--, 0x82);
								core.out(BC, Z);

								F = (F & 0x01) | ALU.DCR[--B] | (Z & 0x80) >> 6;

								if(CMD == 0xBB && (F & 0x40) == 0x40)
								{
									m_core->CLOCK += 45;
									PC -= 2;
								}

								break;
							}

							default:

								break;
						}

					}

					break;
				}

			}

			break;
		}

		if(m_breakpoints)
		{
			if((m_break & ~0xFFFF) == 0 && m_breakpoints[PC] & 0x30)
				m_break |= ((uint64_t) PC << 16) | ((uint64_t) m_breakpoints[PC] << 32);

			if(m_break & 0x3F00000000)
				return false;
		}
	}

	return true;
}

void CPU::reset(uint16_t start)
{
	m_break = (PC = start) | 0x4000000000;
	HLT = false;

	m_core->INTE(IF = IFF2 = false);
	IM = 0;
}

bool CPU::execute(uint64_t limit)
{
	switch(m_cpuType)
	{
		case Type::I8080:
			return internal<Type::I8080>(limit);
		case Type::I8085:
			return internal<Type::I8085>(limit);
		case Type::VM1:
			return internal<Type::VM1>(limit);
		case Type::Z80:
			return internal<Type::Z80>(limit);
	}
}
