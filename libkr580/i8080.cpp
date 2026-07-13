/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2026 Andrey Chicherov <andrey@chicherov.ru>

 Эмуляция микропроцессоров КР580ВМ80А и Zilog Z80

*****/

#include "i8080.h"
#include <type_traits>
#include <utility>

namespace
{
	template <typename cpuType> requires std::is_base_of_v<I8080, cpuType>
	struct ALU
	{
		static constexpr bool i8080 = std::is_same_v<cpuType, I8080>;
		static constexpr bool i8085 = std::is_same_v<cpuType, I8085>;
		static constexpr bool z80 = std::is_same_v<cpuType, Z80>;
		static constexpr bool vm1 = std::is_same_v<cpuType, VM1>;

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
				uint8_t flag = (byte ? 0x04 : 0x44) | (z80 ? 0x00 : 0x02) | (byte & (z80 ? 0xA8 : 0x80));

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
				if constexpr(z80) INR[byte] = (INR[byte] & 0xFB) | ((byte == 0x80) << 2);

				DCR[byte] = flags[byte] | ((byte & 0x0F) != 0x0F ? 0x10 : 0x00);
				if constexpr(z80) DCR[byte] = ((DCR[byte] & 0xFB) | ((byte == 0x7F) << 2) | 0x02) ^ 0x10;

				for(unsigned data = 0x00; data <= 0xFF; data++)
				{
					ADD[byte][data] = ((byte + data) << 8) | flags[(byte + data) & 0xFF] | ((byte & 0x0F) + (data & 0x0F) > 0x0F ? 0x10 : 0x00) | (byte + data > 0xFF ? 0x01 : 0x00);
					if constexpr(z80) ADD[byte][data] = (ADD[byte][data] & 0xFFFB) | (((ADD[byte][data] & 1) << 2) ^ (((byte ^ data ^ (byte + data)) & 0x80) >> 5));

					ADC[byte][data] = ((byte + data + 1) << 8) | flags[(byte + data + 1) & 0xFF] | ((byte & 0x0F) + (data & 0x0F) + 1 > 0x0F ? 0x10 : 0x00) | (byte + data + 1 > 0xFF ? 0x01 : 0x00);
					if constexpr(z80) ADC[byte][data] = (ADC[byte][data] & 0xFFFB) | (((ADC[byte][data] & 1) << 2) ^ (((byte ^ data ^ (byte + data + 1)) & 0x80) >> 5));

					SUB[byte][data] = ((byte - data) << 8) | flags[(byte - data) & 0xFF] | ((byte & 0x0F) < (data & 0x0F) ? 0x00 : 0x10) | (byte < data ? 0x01 : 0x00);
					if constexpr(z80) SUB[byte][data] = (SUB[byte][data] & 0xFFEB) | (((SUB[byte][data] & 1) << 2) ^ (((byte ^ data ^ (byte - data)) & 0x80) >> 5)) | ((byte ^ data ^ (byte - data)) & 0x10) | 0x02;

					CMP[byte][data] = SUB[byte][data] & 0xFF;
					if constexpr(z80) CMP[byte][data] = (CMP[byte][data] & 0xD7) | (data & 0x28);

					SBB[byte][data] = ((byte - data - 1) << 8) | flags[(byte - data - 1) & 0xFF] | ((byte & 0x0F) < (data & 0x0F) + 1 ? 0x00 : 0x10) | (byte < data + 1 ? 0x01 : 0x00);
					if constexpr(z80) SBB[byte][data] = (SBB[byte][data] & 0xFFEB) | (((SBB[byte][data] & 1) << 2) ^ (((byte ^ data ^ (byte - data - 1)) & 0x80) >> 5)) | ((byte ^ data ^ (byte - data - 1)) & 0x10) | 0x02;

					AND[byte][data] = ((byte & data) << 8) | flags[byte & data] | (z80 || (byte | data) & 0x08 ? 0x10 : 0x00);
				}
			}

			for(unsigned word = 0x0000; word <= 0xFFFF; word++)
			{
				uint8_t F = word & 0xFF;
				uint8_t A = word >> 8;

				uint8_t RLC_A = (A << 1) | (A >> 7);
				uint8_t RLC_F = (F & ~1) | (RLC_A & 1);
				if constexpr(z80) RLC_F = (RLC_F & 0xC5) | (RLC_A & 0x28);
				RLC[word] = ((RLC_A) << 8) | RLC_F;

				uint8_t RRC_F = (F & ~1) | (A & 1);
				uint8_t RRC_A = (A >> 1) | (A << 7);
				if constexpr(z80) RRC_F = (RRC_F & 0xC5) | (RRC_A & 0x28);
				RRC[word] = ((RRC_A) << 8) | RRC_F;

				uint8_t RAL_A = (A << 1) | (F & 1);
				uint8_t RAL_F = (F & ~1) | (A >> 7);
				if constexpr(z80) RAL_F = (RAL_F & 0xC5) | (RAL_A & 0x28);
				RAL[word] = ((RAL_A) << 8) | RAL_F;

				uint8_t RAR_A = (A >> 1) | (F << 7);
				uint8_t RAR_F = (F & ~1) | (A & 1);
				if constexpr(z80) RAR_F = (RAR_F & 0xC5) | (RAR_A & 0x28);
				RAR[word] = ((RAR_A) << 8) | RAR_F;

				if constexpr(!z80)
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

	template <typename cpuType> requires std::is_base_of_v<I8080, cpuType>
	struct CPU: public I8080::Impl
	{
		static constexpr bool i8080 = std::is_same_v<cpuType, I8080>;
		static constexpr bool i8085 = std::is_same_v<cpuType, I8085>;
		static constexpr bool z80 = std::is_same_v<cpuType, Z80>;
		static constexpr bool vm1 = std::is_same_v<cpuType, VM1>;

		cpuType *m_cpu;
		I8080::Core *m_core;

		explicit CPU(cpuType *cpu, I8080::Core *core) : m_cpu(cpu), m_core(core)
		{
		}

		static const unsigned timings[256];

		uint8_t fetch(uint16_t PC)
		{
			m_core->CLOCK += 18;
			uint8_t data = m_core->MEMR(PC, 0xA2);

			if(z80 || m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
				m_core->CLOCK += timings[data];

			return data;
		}

		uint8_t get(uint16_t addr, uint8_t status)
		{
			m_core->CLOCK += 18;
			uint8_t data = m_core->MEMR(addr, status);

			if(z80 || m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
				m_core->CLOCK += 9;

			return data;
		}

		void put(uint16_t addr, uint8_t data, uint8_t status)
		{
			m_core->CLOCK += 18;
			m_core->MEMW(addr, data, status);

			if(z80 || m_core->HOLD > m_core->CLOCK || !m_core->HLDA(true))
				m_core->CLOCK += 9;
		}

		uint8_t inp(uint16_t addr)
		{
			m_core->CLOCK += z80 ? 27 : 18;
			uint8_t data = m_core->IOR(addr, 0x42);

			if(z80 || m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
				m_core->CLOCK += 9;

			return data;
		}

		void out(uint16_t addr, uint8_t data)
		{
			m_core->CLOCK += z80 ? 27 : 18;
			m_core->IOW(addr, data, 0x10);

			if(z80 || m_core->HOLD > m_core->CLOCK || !m_core->HLDA(true))
				m_core->CLOCK += 9;
		}

		uint8_t inta(uint16_t PC, uint8_t status)
		{
			m_core->CLOCK += 18;
			uint8_t data = m_core->INTA(PC, status);

			if(z80 || m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
				m_core->CLOCK += z80 ? 27 : 18;

			return data;
		}

		void hlta(uint16_t PC, uint8_t status)
		{
			m_core->CLOCK += 18;
			m_core->HLTA(PC, status);

			if(z80 || m_core->HOLD > m_core->CLOCK || !m_core->HLDA(false))
				m_core->CLOCK += 18;
		}

		void execute(uint64_t limit) final
		{
			static const ALU<cpuType> ALU;
			while(m_core->CLOCK < limit)
			{
				if constexpr(z80)
				{
					if(m_core->NMI < m_core->CLOCK)
					{
						m_core->NMI = std::numeric_limits<uint64_t>::max();

						m_core->CLOCK += 45;

						m_cpu->IFF2 = m_cpu->IF;
						m_core->INTE(m_cpu->IF = false);
						m_cpu->HLT = false;

						put(--m_cpu->SP, m_cpu->PCH, 0x04);
						put(--m_cpu->SP, m_cpu->PCL, 0x04);

						m_cpu->PC = 0x0066;
						continue;
					}
				}

				if(m_cpu->IF && m_core->IRQ < m_core->CLOCK)
				{
					if(m_core->IRQLoop)
						m_core->IRQ = m_core->CLOCK - (m_core->CLOCK - m_core->IRQ) % m_core->IRQLoop + m_core->IRQLoop;
					else
						m_core->IRQ = std::numeric_limits<uint64_t>::max();

					uint8_t RST = inta(m_cpu->PC, m_cpu->HLT ? 0x2B : 0x23);

					m_core->INTE(m_cpu->IF = false);
					if constexpr(z80)
						m_cpu->IFF2 = false;

					m_cpu->HLT = false;

					put(--m_cpu->SP, m_cpu->PCH, 0x04);
					put(--m_cpu->SP, m_cpu->PCL, 0x04);

					if constexpr(z80)
					{
						switch(m_cpu->IM)
						{
						case 0: // IM 0

							m_cpu->PC = RST & 0x0038;
							break;

						case 1: // IM 1

							m_cpu->PC = 0x0038;
							break;

						case 2: // IM 2

							m_cpu->PCL = get(((m_cpu->I << 8) | RST) + 0, 0x82);
							m_cpu->PCH = get(((m_cpu->I << 8) | RST) + 1, 0x82);
							break;
						}
					}
					else
					{
						m_cpu->PC = RST & 0x0038;
					}

					continue;
				}

				union { uint16_t HL; struct { uint8_t L; uint8_t H; }; } *pHL = static_cast<decltype(pHL)>((void *) &m_cpu->HL);

				union { uint16_t WZ; struct { uint8_t Z; uint8_t W; }; };

				uint8_t CMD = m_cpu->HLT ? hlta(m_cpu->PC, 0x88), 0x00 : fetch(m_cpu->PC++);

				while(true)
				{
					if constexpr(z80)
					{
						if((m_cpu->R & 0x7F) == 0x7F)
							m_cpu->R &= 0x80;
						else
							m_cpu->R++;
					}

					switch(CMD)
					{

						case 0x00: // NOP
						{
							break;
						}

						case 0x01: // LXI B,nnnn; LD BC,nnnn
						{
							m_cpu->C = get(m_cpu->PC++, 0x82);
							m_cpu->B = get(m_cpu->PC++, 0x82);
							break;
						}

						case 0x02: // STAX B; LD (BC),A
						{
							put(m_cpu->BC, m_cpu->A, 0x00);
							break;
						}

						case 0x03: // INX B; INC BC
						{
							m_cpu->BC++;
							break;
						}

						case 0x04: // INR B; INC B
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.INR[++m_cpu->B];
							break;
						}

						case 0x05: // DCR B; DEC B
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.DCR[--m_cpu->B];
							break;
						}

						case 0x06: // MVI B,nn; LD B,nn
						{
							m_cpu->B = get(m_cpu->PC++, 0x82);
							break;
						}

						case 0x07: // RLC; RLCA
						{
							m_cpu->AF = ALU.RLC[m_cpu->AF];
							break;
						}

						case 0x08: // ?NOP; EX AF,AF'
						{
							if constexpr(z80)
								std::swap(m_cpu->AF, m_cpu->AF1);

							break;
						}

						case 0x09: // DAD B; ADD HL,BC
						{
							uint32_t sum = pHL->HL + m_cpu->BC;

							if constexpr(z80)
								m_cpu->F = (m_cpu->F & 0xC4) | ((sum & 0x10000) >> 16) | ((sum & 0x2800) >> 8) | (((pHL->HL ^ m_cpu->BC ^ sum) & 0x1000) >> 8);
							else
								m_cpu->F = (m_cpu->F & 0xFE) | ((sum & 0x10000) >> 16);

							if constexpr(!z80)
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

						case 0x0A: // LDAX B; LD A,(BC)
						{
							m_cpu->A = get(m_cpu->BC, 0x82);
							break;
						}

						case 0x0B: // DCX B; DEC BC
						{
							m_cpu->BC--;
							break;
						}

						case 0x0C: // INR C; INC C
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.INR[++m_cpu->C];
							break;
						}

						case 0x0D: // DCR C; DEC C
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.DCR[--m_cpu->C];
							break;
						}

						case 0x0E: // MVI C,nn; LD C,nn
						{
							m_cpu->C = get(m_cpu->PC++, 0x82);
							break;
						}

						case 0x0F: // RRC; RRCA
						{
							m_cpu->AF = ALU.RRC[m_cpu->AF];
							break;
						}

						case 0x10: // ?NOP; DJNZ dd
						{
							if constexpr(z80)
							{
								int8_t addr = get(m_cpu->PC++, 0x82);

								if(--m_cpu->B)
								{
									m_core->CLOCK += 45;
									m_cpu->PC += addr;
								}
							}

							break;
						}

						case 0x11: // LXI D,nnnn; LD DE,nnnn
						{
							m_cpu->E = get(m_cpu->PC++, 0x82);
							m_cpu->D = get(m_cpu->PC++, 0x82);
							break;
						}

						case 0x12: // STAX D; LD (DE),A
						{
							put(m_cpu->DE, m_cpu->A, 0x00);
							break;
						}

						case 0x13: // INX D; INC DE
						{
							m_cpu->DE++;
							break;
						}

						case 0x14: // INR D; INC D
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.INR[++m_cpu->D];
							break;
						}

						case 0x15: // DCR D; DEC D
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.DCR[--m_cpu->D];
							break;
						}

						case 0x16: // MVI D,nn; LD D,nn
						{
							m_cpu->D = get(m_cpu->PC++, 0x82);
							break;
						}

						case 0x17: // RAL; RLA
						{
							m_cpu->AF = ALU.RAL[m_cpu->AF];
							break;
						}

						case 0x18: // ?NOP; JR dd
						{
							if constexpr(z80)
							{
								int8_t addr = get(m_cpu->PC++, 0x82);
								m_core->CLOCK += 45;
								m_cpu->PC += addr;
							}

							break;
						}

						case 0x19: // DAD D; ADD HL,DE
						{
							uint32_t sum = pHL->HL + m_cpu->DE;

							if constexpr(z80)
								m_cpu->F = (m_cpu->F & 0xC4) | ((sum & 0x10000) >> 16) | ((sum & 0x2800) >> 8) | (((pHL->HL ^ m_cpu->DE ^ sum) & 0x1000) >> 8);
							else
								m_cpu->F = (m_cpu->F & 0xFE) | ((sum & 0x10000) >> 16);

							if constexpr(!z80)
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

						case 0x1A: // LDAX D; LD A,(DE)
						{
							m_cpu->A = get(m_cpu->DE, 0x82);
							break;
						}

						case 0x1B: // DCX B; DEC BC
						{
							m_cpu->DE--;
							break;
						}

						case 0x1C: // INR E; INC E
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.INR[++m_cpu->E];
							break;
						}

						case 0x1D: // DCR E; DEC E
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.DCR[--m_cpu->E];
							break;
						}

						case 0x1E: // MVI E,nn; LD E,nn
						{
							m_cpu->E = get(m_cpu->PC++, 0x82);
							break;
						}

						case 0x1F: // RAR; RRA
						{
							m_cpu->AF = ALU.RAR[m_cpu->AF];
							break;
						}

						case 0x20: // ?NOP; JR NZ,dd
						{
							if constexpr(z80)
							{
								int8_t addr = get(m_cpu->PC++, 0x82);

								if((m_cpu->F & 0x40) == 0)
								{
									m_core->CLOCK += 45;
									m_cpu->PC += addr;
								}
							}

							break;
						}

						case 0x21: // LXI H,nnnn; LD HL,nnnn
						{
							pHL->L = get(m_cpu->PC++, 0x82);
							pHL->H = get(m_cpu->PC++, 0x82);
							break;
						}

						case 0x22: // SHLD nnnn; LD (nnnn),HL
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							put(WZ++, pHL->L, 0x00);
							put(WZ, pHL->H, 0x00);
							break;
						}

						case 0x23: // INX H; INC HL
						{
							pHL->HL++;
							break;
						}

						case 0x24: // INR H; INC H
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.INR[++pHL->H];
							break;
						}

						case 0x25: // DCR H; DEC H
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.DCR[--pHL->H];
							break;
						}

						case 0x26: // MVI H,nn; LD H,nn
						{
							pHL->H = get(m_cpu->PC++, 0x82);
							break;
						}

						case 0x27: // DAA
						{
							m_cpu->AF = ALU.DAA[m_cpu->AF];
							break;
						}

						case 0x28: // ?NOP; JR Z,dd
						{
							if constexpr(z80)
							{
								int8_t addr = get(m_cpu->PC++, 0x82);

								if(m_cpu->F & 0x40)
								{
									m_core->CLOCK += 45;
									m_cpu->PC += addr;
								}
							}

							break;
						}

						case 0x29: // DAD H; ADD HL,HL
						{
							uint32_t sum = pHL->HL + pHL->HL;

							if constexpr(z80)
								m_cpu->F = (m_cpu->F & 0xC4) | ((sum & 0x10000) >> 16) | ((sum & 0x2800) >> 8) | ((sum & 0x1000) >> 8);
							else
								m_cpu->F = (m_cpu->F & 0xFE) | ((sum & 0x10000) >> 16);

							if constexpr(!z80)
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

						case 0x2A: // LHLD nnnn; LD HL,(nnnn)
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							pHL->L = get(WZ++, 0x82);
							pHL->H = get(WZ, 0x82);
							break;
						}

						case 0x2B: // DCX H; DEC HL
						{
							pHL->HL--;
							break;
						}

						case 0x2C: // INR L; INC L
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.INR[++pHL->L];
							break;
						}

						case 0x2D: // DCR L; DEC L
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.DCR[--pHL->L];
							break;
						}

						case 0x2E: // MVI L,nn; LD L,nn
						{
							pHL->L = get(m_cpu->PC++, 0x82);
							break;
						}

						case 0x2F: // CMA; CPL
						{
							m_cpu->A = ~m_cpu->A;

							if constexpr(z80)
								m_cpu->F = (m_cpu->F & 0xC5) | (m_cpu->A & 0x28) | 0x12;

							break;
						}

						case 0x30: // ?NOP; JR NC,dd
						{
							if constexpr(z80)
							{
								int8_t addr = get(m_cpu->PC++, 0x82);

								if((m_cpu->F & 0x01) == 0)
								{
									m_core->CLOCK += 45;
									m_cpu->PC += addr;
								}
							}

							break;
						}

						case 0x31: // LXI SP,nnnn; LD SP,nnnn
						{
							m_cpu->SPL = get(m_cpu->PC++, 0x82);
							m_cpu->SPH = get(m_cpu->PC++, 0x82);
							break;
						}

						case 0x32: // STA nnnn; LD (nnnn),A
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);
							put(WZ, m_cpu->A, 0x00);
							break;
						}

						case 0x33: // INX SP; INC SP
						{
							m_cpu->SP++;
							break;
						}

						case 0x34: // INR M; INC (HL)
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							uint8_t M = get(addr, 0x82);

							if constexpr(z80)
								m_core->CLOCK += 9;

							m_cpu->F = (m_cpu->F & 0x01) | ALU.INR[++M];
							put(addr, M, 0x00);
							break;
						}

						case 0x35: // DCR M; DEC (HL)
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							uint8_t M = get(addr, 0x82);

							if constexpr(z80)
								m_core->CLOCK += 9;

							m_cpu->F = (m_cpu->F & 0x01) | ALU.DCR[--M];
							put(addr, M, 0x00);
							break;
						}

						case 0x36: // MVI M,nn; LD (HL),nn
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							uint8_t M = get(m_cpu->PC++, 0x82);
							put(addr, M, 0x00);
							break;
						}

						case 0x37: // STC; SCF
						{
							m_cpu->F |= 0x01;

							if constexpr(z80)
								m_cpu->F = (m_cpu->F & 0xC5) | (m_cpu->A & 0x28);

							break;
						}

						case 0x38: // ?NOP; JR C,dd
						{
							if constexpr(z80)
							{
								int8_t addr = get(m_cpu->PC++, 0x82);

								if(m_cpu->F & 0x01)
								{
									m_core->CLOCK += 45;
									m_cpu->PC += addr;
								}
							}

							break;
						}

						case 0x39: // DAD SP; ADD HL,SP
						{
							uint32_t sum = pHL->HL + m_cpu->SP;

							if constexpr(z80)
								m_cpu->F = (m_cpu->F & 0xC4) | ((sum & 0x10000) >> 16) | ((sum & 0x2800) >> 8) | (((pHL->HL ^ m_cpu->SP ^ sum) & 0x1000) >> 8);
							else
								m_cpu->F = (m_cpu->F & 0xFE) | ((sum & 0x10000) >> 16);

							if constexpr(!z80)
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

						case 0x3A: // LDA nnnn; LD A,(nnnn)
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);
							m_cpu->A = get(WZ, 0x82);
							break;
						}

						case 0x3B: // DCX SP; DEC SP
						{
							m_cpu->SP--;
							break;
						}

						case 0x3C: // INR A; INC A
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.INR[++m_cpu->A];
							break;
						}

						case 0x3D: // DCR A; DEC A
						{
							m_cpu->F = (m_cpu->F & 0x01) | ALU.DCR[--m_cpu->A];
							break;
						}

						case 0x3E: // MVI A,nn; LD A,nn
						{
							m_cpu->A = get(m_cpu->PC++, 0x82);
							break;
						}

						case 0x3F: // CMC; CCF
						{
							if constexpr(z80)
								m_cpu->F = (m_cpu->F & 0xC4) | (m_cpu->A & 0x28) | ((m_cpu->F & 0x01) << 4) | (~m_cpu->F & 0x01);
							else
								m_cpu->F ^= 0x01;

							break;
						}

						case 0x40: // MOV B, B
						{
							m_cpu->B = m_cpu->B;
							break;
						}

						case 0x41: // MOV B, C
						{
							m_cpu->B = m_cpu->C;
							break;
						}

						case 0x42: // MOV B, D
						{
							m_cpu->B = m_cpu->D;
							break;
						}

						case 0x43: // MOV B, E
						{
							m_cpu->B = m_cpu->E;
							break;
						}

						case 0x44: // MOV B, H
						{
							m_cpu->B = pHL->H;
							break;
						}

						case 0x45: // MOV B, L
						{
							m_cpu->B = pHL->L;
							break;
						}

						case 0x46: // MOV B, M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->B = get(addr, 0x82);
							break;
						}

						case 0x47: // MOV B, A
						{
							m_cpu->B = m_cpu->A;
							break;
						}

						case 0x48: // MOV C, B
						{
							m_cpu->C = m_cpu->B;
							break;
						}

						case 0x49: // MOV C, C
						{
							m_cpu->C = m_cpu->C;
							break;
						}

						case 0x4A: // MOV C, D
						{
							m_cpu->C = m_cpu->D;
							break;
						}

						case 0x4B: // MOV C, E
						{
							m_cpu->C = m_cpu->E;
							break;
						}

						case 0x4C: // MOV C, H
						{
							m_cpu->C = pHL->H;
							break;
						}

						case 0x4D: // MOV C, L
						{
							m_cpu->C = pHL->L;
							break;
						}

						case 0x4E: // MOV C, M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->C = get(addr, 0x82);
							break;
						}

						case 0x4F: // MOV C, A
						{
							m_cpu->C = m_cpu->A;
							break;
						}

						case 0x50: // MOV D, B
						{
							m_cpu->D = m_cpu->B;
							break;
						}

						case 0x51: // MOV D, C
						{
							m_cpu->D = m_cpu->C;
							break;
						}

						case 0x52: // MOV D, D
						{
							m_cpu->D = m_cpu->D;
							break;
						}

						case 0x53: // MOV D, E
						{
							m_cpu->D = m_cpu->E;
							break;
						}

						case 0x54: // MOV D, H
						{
							m_cpu->D = pHL->H;
							break;
						}

						case 0x55: // MOV D, L
						{
							m_cpu->D = pHL->L;
							break;
						}

						case 0x56: // MOV D, M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->D = get(addr, 0x82);
							break;
						}

						case 0x57: // MOV D, A
						{
							m_cpu->D = m_cpu->A;
							break;
						}

						case 0x58: // MOV E, B
						{
							m_cpu->E = m_cpu->B;
							break;
						}

						case 0x59: // MOV E, C
						{
							m_cpu->E = m_cpu->C;
							break;
						}

						case 0x5A: // MOV E, D
						{
							m_cpu->E = m_cpu->D;
							break;
						}

						case 0x5B: // MOV E, E
						{
							m_cpu->E = m_cpu->E;
							break;
						}

						case 0x5C: // MOV E, H
						{
							m_cpu->E = pHL->H;
							break;
						}

						case 0x5D: // MOV E, L
						{
							m_cpu->E = pHL->L;
							break;
						}

						case 0x5E: // MOV E, M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->E = get(addr, 0x82);
							break;
						}

						case 0x5F: // MOV E, A
						{
							m_cpu->E = m_cpu->A;
							break;
						}

						case 0x60: // MOV H, B
						{
							pHL->H = m_cpu->B;
							break;
						}

						case 0x61: // MOV H, C
						{
							pHL->H = m_cpu->C;
							break;
						}

						case 0x62: // MOV H, D
						{
							pHL->H = m_cpu->D;
							break;
						}

						case 0x63: // MOV H, E
						{
							pHL->H = m_cpu->E;
							break;
						}

						case 0x64: // MOV H, H
						{
							pHL->H = pHL->H;
							break;
						}

						case 0x65: // MOV H, L
						{
							pHL->H = pHL->L;
							break;
						}

						case 0x66: // MOV H, M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->H = get(addr, 0x82);
							break;
						}

						case 0x67: // MOV H, A
						{
							pHL->H = m_cpu->A;
							break;
						}

						case 0x68: // MOV L, B
						{
							pHL->L = m_cpu->B;
							break;
						}

						case 0x69: // MOV L, C
						{
							pHL->L = m_cpu->C;
							break;
						}

						case 0x6A: // MOV L, D
						{
							pHL->L = m_cpu->D;
							break;
						}

						case 0x6B: // MOV L, E
						{
							pHL->L = m_cpu->E;
							break;
						}

						case 0x6C: // MOV L, H
						{
							pHL->L = pHL->H;
							break;
						}

						case 0x6D: // MOV L, L
						{
							pHL->L = pHL->L;
							break;
						}

						case 0x6E: // MOV L, M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->L = get(addr, 0x82);
							break;
						}

						case 0x6F: // MOV L, A
						{
							pHL->L = m_cpu->A;
							break;
						}

						case 0x70: // MOV M, B
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							put(addr, m_cpu->B, 0x00);
							break;
						}

						case 0x71: // MOV M, C
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							put(addr, m_cpu->C, 0x00);
							break;
						}

						case 0x72: // MOV M, D
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							put(addr, m_cpu->D, 0x00);
							break;
						}

						case 0x73: // MOV M, E
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							put(addr, m_cpu->E, 0x00);
							break;
						}

						case 0x74: // MOV M, H
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							put(addr, m_cpu->H, 0x00);
							break;
						}

						case 0x75: // MOV M, L
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							put(addr, m_cpu->L, 0x00);
							break;
						}

						case 0x76: // HLT
						{
							m_cpu->HLT = true;
							break;
						}

						case 0x77: // MOV M, A
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							put(addr, m_cpu->A, 0x00);
							break;
						}

						case 0x78: // MOV A, B
						{
							m_cpu->A = m_cpu->B;
							break;
						}

						case 0x79: // MOV A, C
						{
							m_cpu->A = m_cpu->C;
							break;
						}

						case 0x7A: // MOV A, D
						{
							m_cpu->A = m_cpu->D;
							break;
						}

						case 0x7B: // MOV A, E
						{
							m_cpu->A = m_cpu->E;
							break;
						}

						case 0x7C: // MOV A, H
						{
							m_cpu->A = pHL->H;
							break;
						}

						case 0x7D: // MOV A, L
						{
							m_cpu->A = pHL->L;
							break;
						}

						case 0x7E: // MOV A, M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->A = get(addr, 0x82);
							break;
						}

						case 0x7F: // MOV A, A
						{
							m_cpu->A = m_cpu->A;
							break;
						}

						case 0x80: // ADD B
						{
							m_cpu->AF = ALU.ADD[m_cpu->A][m_cpu->B];
							break;
						}

						case 0x81: // ADD C
						{
							m_cpu->AF = ALU.ADD[m_cpu->A][m_cpu->C];
							break;
						}

						case 0x82: // ADD D
						{
							m_cpu->AF = ALU.ADD[m_cpu->A][m_cpu->D];
							break;
						}

						case 0x83: // ADD E
						{
							m_cpu->AF = ALU.ADD[m_cpu->A][m_cpu->E];
							break;
						}

						case 0x84: // ADD H
						{
							m_cpu->AF = ALU.ADD[m_cpu->A][pHL->H];
							break;
						}

						case 0x85: // ADD L
						{
							m_cpu->AF = ALU.ADD[m_cpu->A][pHL->L];
							break;
						}

						case 0x86: // ADD M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->AF = ALU.ADD[m_cpu->A][get(addr, 0x82)];
							break;
						}

						case 0x87: // ADD A
						{
							m_cpu->AF = ALU.ADD[m_cpu->A][m_cpu->A];
							break;
						}

						case 0x88: // ADC B
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.ADC[m_cpu->A][m_cpu->B];
							else
								m_cpu->AF = ALU.ADD[m_cpu->A][m_cpu->B];

							break;
						}

						case 0x89: // ADC C
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.ADC[m_cpu->A][m_cpu->C];
							else
								m_cpu->AF = ALU.ADD[m_cpu->A][m_cpu->C];

							break;
						}

						case 0x8A: // ADC D
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.ADC[m_cpu->A][m_cpu->D];
							else
								m_cpu->AF = ALU.ADD[m_cpu->A][m_cpu->D];

							break;
						}

						case 0x8B: // ADC E
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.ADC[m_cpu->A][m_cpu->E];
							else
								m_cpu->AF = ALU.ADD[m_cpu->A][m_cpu->E];

							break;
						}

						case 0x8C: // ADC H
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.ADC[m_cpu->A][pHL->H];
							else
								m_cpu->AF = ALU.ADD[m_cpu->A][pHL->H];

							break;
						}

						case 0x8D: // ADC L
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.ADC[m_cpu->A][pHL->L];
							else
								m_cpu->AF = ALU.ADD[m_cpu->A][pHL->L];

							break;
						}

						case 0x8E: // ADC M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							if(m_cpu->F & 1)
								m_cpu->AF = ALU.ADC[m_cpu->A][get(addr, 0x82)];
							else
								m_cpu->AF = ALU.ADD[m_cpu->A][get(addr, 0x82)];

							break;
						}

						case 0x8F: // ADC A
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.ADC[m_cpu->A][m_cpu->A];
							else
								m_cpu->AF = ALU.ADD[m_cpu->A][m_cpu->A];

							break;
						}

						case 0x90: // SUB B
						{
							m_cpu->AF = ALU.SUB[m_cpu->A][m_cpu->B];
							break;
						}

						case 0x91: // SUB C
						{
							m_cpu->AF = ALU.SUB[m_cpu->A][m_cpu->C];
							break;
						}

						case 0x92: // SUB D
						{
							m_cpu->AF = ALU.SUB[m_cpu->A][m_cpu->D];
							break;
						}

						case 0x93: // SUB E
						{
							m_cpu->AF = ALU.SUB[m_cpu->A][m_cpu->E];
							break;
						}

						case 0x94: // SUB H
						{
							m_cpu->AF = ALU.SUB[m_cpu->A][pHL->H];
							break;
						}

						case 0x95: // SUB L
						{
							m_cpu->AF = ALU.SUB[m_cpu->A][pHL->L];
							break;
						}

						case 0x96: // SUB M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->AF = ALU.SUB[m_cpu->A][get(addr, 0x82)];
							break;
						}

						case 0x97: // SUB A
						{
							m_cpu->AF = ALU.SUB[m_cpu->A][m_cpu->A];
							break;
						}

						case 0x98: // SBB B
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.SBB[m_cpu->A][m_cpu->B];
							else
								m_cpu->AF = ALU.SUB[m_cpu->A][m_cpu->B];

							break;
						}

						case 0x99: // SBB C
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.SBB[m_cpu->A][m_cpu->C];
							else
								m_cpu->AF = ALU.SUB[m_cpu->A][m_cpu->C];

							break;
						}

						case 0x9A: // SBB D
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.SBB[m_cpu->A][m_cpu->D];
							else
								m_cpu->AF = ALU.SUB[m_cpu->A][m_cpu->D];

							break;
						}

						case 0x9B: // SBB E
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.SBB[m_cpu->A][m_cpu->E];
							else
								m_cpu->AF = ALU.SUB[m_cpu->A][m_cpu->E];

							break;
						}

						case 0x9C: // SBB H
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.SBB[m_cpu->A][pHL->H];
							else
								m_cpu->AF = ALU.SUB[m_cpu->A][pHL->H];

							break;
						}

						case 0x9D: // SBB L
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.SBB[m_cpu->A][pHL->L];
							else
								m_cpu->AF = ALU.SUB[m_cpu->A][pHL->L];

							break;
						}

						case 0x9E: // SBB M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							if(m_cpu->F & 1)
								m_cpu->AF = ALU.SBB[m_cpu->A][get(addr, 0x82)];
							else
								m_cpu->AF = ALU.SUB[m_cpu->A][get(addr, 0x82)];

							break;
						}

						case 0x9F: // SBB A
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.SBB[m_cpu->A][m_cpu->A];
							else
								m_cpu->AF = ALU.SUB[m_cpu->A][m_cpu->A];

							break;
						}

						case 0xA0: // ANA B
						{
							m_cpu->AF = ALU.AND[m_cpu->A][m_cpu->B];
							break;
						}

						case 0xA1: // ANA C
						{
							m_cpu->AF = ALU.AND[m_cpu->A][m_cpu->C];
							break;
						}

						case 0xA2: // ANA D
						{
							m_cpu->AF = ALU.AND[m_cpu->A][m_cpu->D];
							break;
						}

						case 0xA3: // ANA E
						{
							m_cpu->AF = ALU.AND[m_cpu->A][m_cpu->E];
							break;
						}

						case 0xA4: // ANA H
						{
							m_cpu->AF = ALU.AND[m_cpu->A][pHL->H];
							break;
						}

						case 0xA5: // ANA L
						{
							m_cpu->AF = ALU.AND[m_cpu->A][pHL->L];
							break;
						}

						case 0xA6: // ANA M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->AF = ALU.AND[m_cpu->A][get(addr, 0x82)];
							break;
						}

						case 0xA7: // ANA A
						{
							m_cpu->AF = ALU.AND[m_cpu->A][m_cpu->A];
							break;
						}

						case 0xA8: // XRA B
						{
							m_cpu->F = ALU.flags[m_cpu->A ^= m_cpu->B];
							break;
						}

						case 0xA9: // XRA C
						{
							m_cpu->F = ALU.flags[m_cpu->A ^= m_cpu->C];
							break;
						}

						case 0xAA: // XRA D
						{
							m_cpu->F = ALU.flags[m_cpu->A ^= m_cpu->D];
							break;
						}

						case 0xAB: // XRA E
						{
							m_cpu->F = ALU.flags[m_cpu->A ^= m_cpu->E];
							break;
						}

						case 0xAC: // XRA H
						{
							m_cpu->F = ALU.flags[m_cpu->A ^= pHL->H];
							break;
						}

						case 0xAD: // XRA L
						{
							m_cpu->F = ALU.flags[m_cpu->A ^= pHL->L];
							break;
						}

						case 0xAE: // XRA M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->F = ALU.flags[m_cpu->A ^= get(addr, 0x82)];
							break;
						}

						case 0xAF: // XRA A
						{
							m_cpu->F = ALU.flags[m_cpu->A ^= m_cpu->A];
							break;
						}

						case 0xB0: // ORA B
						{
							m_cpu->F = ALU.flags[m_cpu->A |= m_cpu->B];
							break;
						}

						case 0xB1: // ORA C
						{
							m_cpu->F = ALU.flags[m_cpu->A |= m_cpu->C];
							break;
						}

						case 0xB2: // ORA D
						{
							m_cpu->F = ALU.flags[m_cpu->A |= m_cpu->D];
							break;
						}

						case 0xB3: // ORA E
						{
							m_cpu->F = ALU.flags[m_cpu->A |= m_cpu->E];
							break;
						}

						case 0xB4: // ORA H
						{
							m_cpu->F = ALU.flags[m_cpu->A |= pHL->H];
							break;
						}

						case 0xB5: // ORA L
						{
							m_cpu->F = ALU.flags[m_cpu->A |= pHL->L];
							break;
						}

						case 0xB6: // ORA M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->F = ALU.flags[m_cpu->A |= get(addr, 0x82)];
							break;
						}

						case 0xB7: // ORA A
						{
							m_cpu->F = ALU.flags[m_cpu->A |= m_cpu->A];
							break;
						}

						case 0xB8: // CMP B
						{
							m_cpu->F = ALU.CMP[m_cpu->A][m_cpu->B];
							break;
						}

						case 0xB9: // CMP C
						{
							m_cpu->F = ALU.CMP[m_cpu->A][m_cpu->C];
							break;
						}

						case 0xBA: // CMP D
						{
							m_cpu->F = ALU.CMP[m_cpu->A][m_cpu->D];
							break;
						}

						case 0xBB: // CMP E
						{
							m_cpu->F = ALU.CMP[m_cpu->A][m_cpu->E];
							break;
						}

						case 0xBC: // CMP H
						{
							m_cpu->F = ALU.CMP[m_cpu->A][pHL->H];
							break;
						}

						case 0xBD: // CMP L
						{
							m_cpu->F = ALU.CMP[m_cpu->A][pHL->L];
							break;
						}

						case 0xBE: // CMP M
						{
							uint16_t addr = pHL->HL;

							if constexpr(z80)
							{
								if(&pHL->HL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 45;
								}
							}

							m_cpu->F = ALU.CMP[m_cpu->A][get(addr, 0x82)];
							break;
						}

						case 0xBF: // CMP A
						{
							m_cpu->F = ALU.CMP[m_cpu->A][m_cpu->A];
							break;
						}

						case 0xC0: // RNZ
						{
							if((m_cpu->F & 0x40) == 0)
							{
								m_cpu->PCL = get(m_cpu->SP++, 0x86);
								m_cpu->PCH = get(m_cpu->SP++, 0x86);
							}

							break;
						}

						case 0xC1: // POP B
						{
							m_cpu->C = get(m_cpu->SP++, 0x86);
							m_cpu->B = get(m_cpu->SP++, 0x86);
							break;
						}

						case 0xC2: // JNZ
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if((m_cpu->F & 0x40) == 0)
								m_cpu->PC = WZ;

							break;
						}

						case 0xC3: // JMP
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);
							m_cpu->PC = WZ;
							break;
						}

						case 0xC4: // CNZ
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if((m_cpu->F & 0x40) == 0)
							{
								if constexpr(z80)
									m_core->CLOCK += 9;

								put(--m_cpu->SP, m_cpu->PCH, 0x04);
								put(--m_cpu->SP, m_cpu->PCL, 0x04);
								m_cpu->PC = WZ;
							}

							break;
						}

						case 0xC5: // PUSH B
						{
							put(--m_cpu->SP, m_cpu->B, 0x04);
							put(--m_cpu->SP, m_cpu->C, 0x04);
							break;
						}

						case 0xC6: // ADI
						{
							m_cpu->AF = ALU.ADD[m_cpu->A][get(m_cpu->PC++, 0x82)];
							break;
						}

						case 0xC7: // RST
						case 0xCF:
						case 0xD7:
						case 0xDF:
						case 0xE7:
						case 0xEF:
						case 0xF7:
						case 0xFF:
						{
							put(--m_cpu->SP, m_cpu->PCH, 0x04);
							put(--m_cpu->SP, m_cpu->PCL, 0x04);
							m_cpu->PC = CMD & 0x38;
							break;
						}

						case 0xC8: // RZ
						{
							if(m_cpu->F & 0x40)
							{
								m_cpu->PCL = get(m_cpu->SP++, 0x86);
								m_cpu->PCH = get(m_cpu->SP++, 0x86);
							}

							break;
						}

						case 0xC9: // RET
						{
							m_cpu->PCL = get(m_cpu->SP++, 0x86);
							m_cpu->PCH = get(m_cpu->SP++, 0x86);
							break;
						}

						case 0xCA: // JZ
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if(m_cpu->F & 0x40)
								m_cpu->PC = WZ;

							break;
						}

						case 0xCC: // CZ
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if(m_cpu->F & 0x40)
							{
								if constexpr(z80)
									m_core->CLOCK += 9;

								put(--m_cpu->SP, m_cpu->PCH, 0x04);
								put(--m_cpu->SP, m_cpu->PCL, 0x04);
								m_cpu->PC = WZ;
							}

							break;
						}

						case 0xCD: // CALL
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if constexpr(z80)
								m_core->CLOCK += 9;

							put(--m_cpu->SP, m_cpu->PCH, 0x04);
							put(--m_cpu->SP, m_cpu->PCL, 0x04);
							m_cpu->PC = WZ;

							break;
						}

						case 0xCE: // ACI
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.ADC[m_cpu->A][get(m_cpu->PC++, 0x82)];
							else
								m_cpu->AF = ALU.ADD[m_cpu->A][get(m_cpu->PC++, 0x82)];

							break;
						}

						case 0xD0: // RNC
						{
							if((m_cpu->F & 0x01) == 0)
							{
								m_cpu->PCL = get(m_cpu->SP++, 0x86);
								m_cpu->PCH = get(m_cpu->SP++, 0x86);
							}

							break;
						}

						case 0xD1: // POP D
						{
							m_cpu->E = get(m_cpu->SP++, 0x86);
							m_cpu->D = get(m_cpu->SP++, 0x86);
							break;
						}

						case 0xD2: // JNC
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if((m_cpu->F & 0x01) == 0x00)
								m_cpu->PC = WZ;

							break;
						}

						case 0xD3: // OUT
						{
							Z = get(m_cpu->PC++, 0x82);

							if constexpr(z80)
								W = m_cpu->A;
							else
								W = Z;

							out(WZ, m_cpu->A);
							break;
						}

						case 0xD4: // CNC
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if((m_cpu->F & 0x01) == 0x00)
							{
								if constexpr(z80)
									m_core->CLOCK += 9;

								put(--m_cpu->SP, m_cpu->PCH, 0x04);
								put(--m_cpu->SP, m_cpu->PCL, 0x04);
								m_cpu->PC = WZ;
							}

							break;
						}

						case 0xD5: // PUSH D
						{
							put(--m_cpu->SP, m_cpu->D, 0x04);
							put(--m_cpu->SP, m_cpu->E, 0x04);
							break;
						}

						case 0xD6: // SUI
						{
							m_cpu->AF = ALU.SUB[m_cpu->A][get(m_cpu->PC++, 0x82)];
							break;
						}

						case 0xD8: // RC
						{
							if(m_cpu->F & 0x01)
							{
								m_cpu->PCL = get(m_cpu->SP++, 0x86);
								m_cpu->PCH = get(m_cpu->SP++, 0x86);
							}

							break;
						}

						case 0xD9: // ?RET; EXX
						{
							if constexpr(!z80)
							{
								m_cpu->PCL = get(m_cpu->SP++, 0x86);
								m_cpu->PCH = get(m_cpu->SP++, 0x86);
							}
							else
							{
								std::swap(m_cpu->BC, m_cpu->BC1);
								std::swap(m_cpu->DE, m_cpu->DE1);
								std::swap(m_cpu->HL, m_cpu->HL1);
							}

							break;
						}

						case 0xDA: // JC
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if(m_cpu->F & 0x01)
								m_cpu->PC = WZ;

							break;
						}

						case 0xDB: // IN
						{
							Z = get(m_cpu->PC++, 0x82);

							if constexpr(z80)
								W = m_cpu->A;
							else
								W = Z;

							m_cpu->A = inp(WZ);
							break;
						}

						case 0xDC: // CC
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if(m_cpu->F & 0x01)
							{
								if constexpr(z80)
									m_core->CLOCK += 9;

								put(--m_cpu->SP, m_cpu->PCH, 0x04);
								put(--m_cpu->SP, m_cpu->PCL, 0x04);
								m_cpu->PC = WZ;
							}

							break;
						}

						case 0xDD: // ?CALL; // DD prefix
						{
							if constexpr(!z80)
							{
								CMD = 0xCD;
								continue;
							}
							else
							{
								pHL = static_cast<decltype(pHL)>((void*)&m_cpu->IX);
								CMD = fetch(m_cpu->PC++);
								continue;
							}
						}

						case 0xDE: // SBI
						{
							if(m_cpu->F & 1)
								m_cpu->AF = ALU.SBB[m_cpu->A][get(m_cpu->PC++, 0x82)];
							else
								m_cpu->AF = ALU.SUB[m_cpu->A][get(m_cpu->PC++, 0x82)];

							break;
						}

						case 0xE0: // RPO
						{
							if((m_cpu->F & 0x04) == 0)
							{
								m_cpu->PCL = get(m_cpu->SP++, 0x86);
								m_cpu->PCH = get(m_cpu->SP++, 0x86);
							}

							break;
						}

						case 0xE1: // POP H
						{
							pHL->L = get(m_cpu->SP++, 0x86);
							pHL->H = get(m_cpu->SP++, 0x86);
							break;
						}

						case 0xE2: // JPO
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if((m_cpu->F & 0x04) == 0x00)
								m_cpu->PC = WZ;

							break;
						}

						case 0xE3: // XTHL; EX (SP),HL
						{
							Z = get(m_cpu->SP++, 0x86);
							W = get(m_cpu->SP++, 0x86);

							if constexpr(z80)
								m_core->CLOCK += 9;

							put(--m_cpu->SP, pHL->H, 0x04);

							if constexpr(z80)
							{
								put(--m_cpu->SP, pHL->L, 0x04);
								m_core->CLOCK += 18;
							}
							else
							{
								uint64_t M5 = m_core->CLOCK + 9 * 5;
								put(--m_cpu->SP, pHL->L, 0x04);

								if(m_core->CLOCK < M5)
									m_core->CLOCK = M5;
							}

							pHL->HL = WZ;
							break;
						}

						case 0xE4: // CPO
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if((m_cpu->F & 0x04) == 0x00)
							{
								if constexpr(z80)
									m_core->CLOCK += 9;

								put(--m_cpu->SP, m_cpu->PCH, 0x04);
								put(--m_cpu->SP, m_cpu->PCL, 0x04);
								m_cpu->PC = WZ;
							}

							break;
						}

						case 0xE5: // PUSH H
						{
							put(--m_cpu->SP, pHL->H, 0x04);
							put(--m_cpu->SP, pHL->L, 0x04);
							break;
						}

						case 0xE6: // ANI
						{
							m_cpu->AF = ALU.AND[m_cpu->A][get(m_cpu->PC++, 0x82)];
							break;
						}

						case 0xE8: // RPE
						{
							if(m_cpu->F & 0x04)
							{
								m_cpu->PCL = get(m_cpu->SP++, 0x86);
								m_cpu->PCH = get(m_cpu->SP++, 0x86);
							}

							break;
						}

						case 0xE9: // PCHL
						{
							m_cpu->PC = pHL->HL;
							break;
						}

						case 0xEA: // JPE
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if(m_cpu->F & 0x04)
								m_cpu->PC = WZ;

							break;
						}

						case 0xEB: // XCHG; EX DE,HL
						{
							std::swap(m_cpu->HL, m_cpu->DE);
							break;
						}

						case 0xEC: // CPE
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if(m_cpu->F & 0x04)
							{
								if constexpr(z80)
									m_core->CLOCK += 9;

								put(--m_cpu->SP, m_cpu->PCH, 0x04);
								put(--m_cpu->SP, m_cpu->PCL, 0x04);
								m_cpu->PC = WZ;
							}

							break;
						}

						case 0xEE: // XRI
						{
							m_cpu->F = ALU.flags[m_cpu->A ^= get(m_cpu->PC++, 0x82)];
							break;
						}

						case 0xF0: // RP
						{
							if((m_cpu->F & 0x80) == 0)
							{
								m_cpu->PCL = get(m_cpu->SP++, 0x86);
								m_cpu->PCH = get(m_cpu->SP++, 0x86);
							}

							break;
						}

						case 0xF1: // POP PSW
						{
							m_cpu->F = get(m_cpu->SP++, 0x86);
							m_cpu->A = get(m_cpu->SP++, 0x86);
							break;
						}

						case 0xF2: // JP
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if((m_cpu->F & 0x80) == 0x00)
								m_cpu->PC = WZ;

							break;
						}

						case 0xF3: // DI
						{
							m_core->INTE(m_cpu->IF = false);
							if constexpr(z80)
								m_cpu->IFF2 = false;

							break;
						}

						case 0xF4: // CP
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if((m_cpu->F & 0x80) == 0x00)
							{
								if constexpr(z80)
									m_core->CLOCK += 9;

								put(--m_cpu->SP, m_cpu->PCH, 0x04);
								put(--m_cpu->SP, m_cpu->PCL, 0x04);
								m_cpu->PC = WZ;
							}

							break;
						}

						case 0xF5: // PUSH PSW
						{
							put(--m_cpu->SP, m_cpu->A, 0x04);

							if constexpr(z80)
								put(--m_cpu->SP, m_cpu->F, 0x04);
							else
								put(--m_cpu->SP, (m_cpu->F & 0xD7) | 0x02, 0x04);

							break;
						}

						case 0xF6: // ORI
						{
							m_cpu->F = ALU.flags[m_cpu->A |= get(m_cpu->PC++, 0x82)];
							break;
						}

						case 0xF8: // RM
						{
							if(m_cpu->F & 0x80)
							{
								m_cpu->PCL = get(m_cpu->SP++, 0x86);
								m_cpu->PCH = get(m_cpu->SP++, 0x86);
							}

							break;
						}

						case 0xF9: // SPHL; LD SP,HL
						{
							m_cpu->SP = pHL->HL;
							break;
						}

						case 0xFA: // JM
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if(m_cpu->F & 0x80)
								m_cpu->PC = WZ;

							break;
						}

						case 0xFB: // EI
						{
							m_core->INTE(m_cpu->IF = true);
							if constexpr(z80)
								m_cpu->IFF2 = true;

							if constexpr(z80)
							{
								CMD = fetch(m_cpu->PC++);
								continue;
							}

							break;
						}

						case 0xFC: // CM
						{
							Z = get(m_cpu->PC++, 0x82);
							W = get(m_cpu->PC++, 0x82);

							if(m_cpu->F & 0x80)
							{
								if constexpr(z80)
									m_core->CLOCK += 9;

								put(--m_cpu->SP, m_cpu->PCH, 0x04);
								put(--m_cpu->SP, m_cpu->PCL, 0x04);
								m_cpu->PC = WZ;
							}

							break;
						}

						case 0xFD: // ?CALL; FD prefix
						{
							if constexpr(!z80)
							{
								CMD = 0xCD;
								continue;
							}
							else
							{
								pHL = static_cast<decltype(pHL)>((void*)&m_cpu->IY);
								CMD = fetch(m_cpu->PC++);
								continue;
							}
						}

						case 0xFE: // CPI
						{
							m_cpu->F = ALU.CMP[m_cpu->A][get(m_cpu->PC++, 0x82)];
							break;
						}

// -------------------------------------------------------------

						case 0xCB: // ?JMP; CB Prefix
						{
							if constexpr(!z80)
							{
								CMD = 0xC3;
								continue;
							}
							else
							{
								uint16_t addr = pHL->HL;

								if((void*)pHL != &m_cpu->HL)
								{
									addr += (int8_t)get(m_cpu->PC++, 0x82);

									CMD = get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 18;

									W = get(addr, 0x82);
									m_core->CLOCK += 9;
								}
								else
								{
									CMD = get(m_cpu->PC++, 0x82);
									m_core->CLOCK += 9;

									switch(CMD & 0x07)
									{
										case 0x00:

											W = m_cpu->B;
											break;

										case 0x01:

											W = m_cpu->C;
											break;

										case 0x02:

											W = m_cpu->D;
											break;

										case 0x03:

											W = m_cpu->E;
											break;

										case 0x04:

											W = m_cpu->H;
											break;

										case 0x05:

											W = m_cpu->L;
											break;

										case 0x06:

											W = get(m_cpu->HL, 0x82);
											m_core->CLOCK += 9;
											break;

										case 0x07:

											W = m_cpu->A;
											break;
									}
								}

								switch(CMD & 0xC0)
								{
									case 0x00:
									{
										Z = m_cpu->F;

										switch(CMD & 0x38)
										{
											case 0x00: // RLC

												m_cpu->F = W >> 7;
												m_cpu->F |= ALU.flags[W = (W << 1) | (W >> 7)];
												break;

											case 0x08: // RRC

												m_cpu->F = W & 1;
												m_cpu->F |= ALU.flags[W = (W >> 1) | (W << 7)];
												break;

											case 0x10: // RL

												m_cpu->F = W >> 7;
												m_cpu->F |= ALU.flags[W = (W << 1) | (Z & 1)];
												break;

											case 0x18: // RR

												m_cpu->F = W & 1;
												m_cpu->F |= ALU.flags[W = (W >> 1) | (Z << 7)];
												break;

											case 0x20: // SLA

												m_cpu->F = W >> 7;
												m_cpu->F |= ALU.flags[W = W << 1];
												break;

											case 0x28: // SRA

												m_cpu->F = W & 1;
												m_cpu->F |= ALU.flags[W = (W >> 1) | (W & 0x80)];
												break;

											case 0x30: // SLA 1

												m_cpu->F = W >> 7;
												m_cpu->F |= ALU.flags[W = ((W << 1) | 0x01)];
												break;

											case 0x38: // SLR

												m_cpu->F = W & 1;
												m_cpu->F |= ALU.flags[W = W >> 1];
										}

										break;
									}

									case 0x40: // BIT n,r
									{
										if(W & (1 << ((CMD >> 3) & 7)))
											m_cpu->F = (m_cpu->F & 0x01) | 0x10 | (((CMD & 0x38) == 0x38) << 7);
										else
											m_cpu->F = (m_cpu->F & 0x01) | 0x54;

										if((CMD & 0x07) != 0x06)
											m_cpu->F |= (W & 0x28);

										break;
									}

									case 0x80: // RES n, r

										W &= ~(1 << ((CMD >> 3) & 7));
										break;

									case 0xC0: // SET n, r

										W |= (1 << ((CMD >> 3) & 7));
										break;
								}

								if((CMD & 0xC0) != 0x40)
								{
									if((void*)pHL != &m_cpu->HL || (CMD & 0x07) == 0x06)
										put(addr, W, 0x00);

									switch(CMD & 0x07)
									{
										case 0:

											m_cpu->B = W;
											break;

										case 1:

											m_cpu->C = W;
											break;

										case 2:

											m_cpu->D = W;
											break;

										case 3:

											m_cpu->E = W;
											break;

										case 4:

											m_cpu->H = W;
											break;

										case 5:

											m_cpu->L = W;
											break;

										case 7:

											m_cpu->A = W;
											break;
									}
								}
							}

							break;
						}

// -------------------------------------------------------------

						case 0xED: // ?CALL; ED prefix
						{
							if constexpr(!z80)
							{
								CMD = 0xCD;
								continue;
							}
							else
							{
								CMD = get(m_cpu->PC++, 0x82);
								m_core->CLOCK += 9;

								switch(CMD)
								{
									case 0x40: // IN B,(C)
									{
										m_cpu->F = (m_cpu->F & 0x01) | ALU.flags[m_cpu->B = inp(m_cpu->BC)];
										break;
									}

									case 0x41: // OUT (C),B
									{
										out(m_cpu->BC, m_cpu->B);
										break;
									}

									case 0x42: // SBC HL,BC
									{
										if(m_cpu->F & 1)
											WZ = ALU.SBB[m_cpu->L][m_cpu->C];
										else
											WZ = ALU.SUB[m_cpu->L][m_cpu->C];

										m_cpu->L = W;

										if(Z & 1)
											WZ = ALU.SBB[m_cpu->H][m_cpu->B] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
										else
											WZ = ALU.SUB[m_cpu->H][m_cpu->B] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

										m_cpu->H = W;
										m_cpu->F = Z;

										m_core->CLOCK += 63;
										break;
									}

									case 0x43: // LD (nnnn),BC
									{
										Z = get(m_cpu->PC++, 0x82);
										W = get(m_cpu->PC++, 0x82);
										put(WZ++, m_cpu->C, 0x00);
										put(WZ, m_cpu->B, 0x00);
										break;
									}

									case 0x44: // NEG
									case 0x4C: // NEG∗∗
									case 0x54: // NEG∗∗
									case 0x5C: // NEG∗∗
									case 0x64: // NEG∗∗
									case 0x6C: // NEG∗∗
									case 0x74: // NEG∗∗
									case 0x7C: // NEG∗∗

									{
										m_cpu->AF = ALU.SUB[0][m_cpu->A];
										break;
									}

									case 0x45: // RETN
									case 0x55: // RETN∗∗
									case 0x5D: // RETN∗∗
									case 0x65: // RETN∗∗
									case 0x6D: // RETN∗∗
									case 0x75: // RETN∗∗
									case 0x7D: // RETN∗∗

									{
										m_core->INTE(m_cpu->IF = m_cpu->IFF2);

										CMD = 0xC9;
										continue;
									}

									case 0x46: // IM 0
									case 0x4E: // IM 0∗∗
									case 0x66: // IM 0∗∗
									case 0x6E: // IM 0∗∗

									{
										m_cpu->IM = 0;
										break;
									}

									case 0x47: // LD I,A
									{
										m_cpu->I = m_cpu->A;

										m_core->CLOCK += 9;
										break;
									}

									case 0x48: // IN C,(C)
									{
										m_cpu->F = (m_cpu->F & 0x01) | ALU.flags[m_cpu->C = inp(m_cpu->BC)];
										break;
									}

									case 0x49: // OUT (C),C
									{
										out(m_cpu->BC, m_cpu->C);
										break;
									}

									case 0x4A: // ADC HL,BC
									{
										if(m_cpu->F & 1)
											WZ = ALU.ADC[m_cpu->L][m_cpu->C];
										else
											WZ = ALU.ADD[m_cpu->L][m_cpu->C];

										m_cpu->L = W;

										if(Z & 1)
											WZ = ALU.ADC[m_cpu->H][m_cpu->B] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
										else
											WZ = ALU.ADD[m_cpu->H][m_cpu->B] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

										m_cpu->H = W;
										m_cpu->F = Z;

										m_core->CLOCK += 63;
										break;
									}

									case 0x4B: // LD BC,(nnnn)
									{
										Z = get(m_cpu->PC++, 0x82);
										W = get(m_cpu->PC++, 0x82);
										m_cpu->C = get(WZ++, 0x82);
										m_cpu->B = get(WZ, 0x82);
										break;
									}

									case 0x4D: // RETI
									{
										m_core->INTE(m_cpu->IF = m_cpu->IFF2);

										CMD = 0xC9;
										continue;
									}

									case 0x4F: // LD R,A
									{
										m_cpu->R = m_cpu->A;

										m_core->CLOCK += 9;
										break;
									}

									case 0x50: // IN D,(C)
									{
										m_cpu->F = (m_cpu->F & 0x01) | ALU.flags[m_cpu->D = inp(m_cpu->BC)];
										break;
									}

									case 0x51: // OUT (C),D
									{
										out(m_cpu->BC, m_cpu->D);
										break;
									}

									case 0x52: // SBC HL,DE
									{
										if(m_cpu->F & 1)
											WZ = ALU.SBB[m_cpu->L][m_cpu->E];
										else
											WZ = ALU.SUB[m_cpu->L][m_cpu->E];

										m_cpu->L = W;

										if(Z & 1)
											WZ = ALU.SBB[m_cpu->H][m_cpu->D] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
										else
											WZ = ALU.SUB[m_cpu->H][m_cpu->D] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

										m_cpu->H = W;
										m_cpu->F = Z;

										m_core->CLOCK += 63;
										break;
									}

									case 0x53: // LD (nnnn),DE
									{
										Z = get(m_cpu->PC++, 0x82);
										W = get(m_cpu->PC++, 0x82);
										put(WZ++, m_cpu->E, 0x00);
										put(WZ, m_cpu->D, 0x00);
										break;
									}

									case 0x56: // IM 1
									case 0x76: // IM 1∗∗
									{
										m_cpu->IM = 1;
										break;
									}

									case 0x57: // LD A,I
									{
										m_cpu->F = (m_cpu->F & 0x29) | (m_cpu->I & 0x80) | ((m_cpu->I == 0) << 6) | (m_cpu->IFF2 << 2);
										m_cpu->A = m_cpu->I;

										m_core->CLOCK += 9;
										break;
									}

									case 0x58: // IN E,(C)
									{
										m_cpu->F = (m_cpu->F & 0x01) | ALU.flags[m_cpu->E = inp(m_cpu->BC)];
										break;
									}

									case 0x59: // OUT (C),E
									{
										out(m_cpu->BC, m_cpu->E);
										break;
									}

									case 0x5A: // ADC HL,DE
									{
										if(m_cpu->F & 1)
											WZ = ALU.ADC[m_cpu->L][m_cpu->E];
										else
											WZ = ALU.ADD[m_cpu->L][m_cpu->E];

										m_cpu->L = W;

										if(Z & 1)
											WZ = ALU.ADC[m_cpu->H][m_cpu->D] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
										else
											WZ = ALU.ADD[m_cpu->H][m_cpu->D] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

										m_cpu->H = W;
										m_cpu->F = Z;

										m_core->CLOCK += 63;
										break;
									}

									case 0x5B: // LD DE,(nnnn)
									{
										Z = get(m_cpu->PC++, 0x82);
										W = get(m_cpu->PC++, 0x82);
										m_cpu->E = get(WZ++, 0x82);
										m_cpu->D = get(WZ, 0x82);
										break;
									}

									case 0x5E: // IM 2
									case 0x7E: // IM 2∗∗
									{
										m_cpu->IM = 2;
										break;
									}

									case 0x5F: // LD A,R
									{
										m_cpu->F = (m_cpu->F & 0x29) | (m_cpu->R & 0x80) | ((m_cpu->R == 0) << 6) | (m_cpu->IFF2 << 2);
										m_cpu->A = m_cpu->R;

										m_core->CLOCK += 9;
										break;
									}

									case 0x60: // IN H,(C)
									{
										m_cpu->F = (m_cpu->F & 0x01) | ALU.flags[m_cpu->H = inp(m_cpu->BC)];
										break;
									}

									case 0x61: // OUT (C),H
									{
										out(m_cpu->BC, m_cpu->H);
										break;
									}

									case 0x62: // SBC HL,HL
									{
										if(m_cpu->F & 1)
											WZ = ALU.SBB[m_cpu->L][m_cpu->L];
										else
											WZ = ALU.SUB[m_cpu->L][m_cpu->L];

										m_cpu->L = W;

										if(Z & 1)
											WZ = ALU.SBB[m_cpu->H][m_cpu->H] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
										else
											WZ = ALU.SUB[m_cpu->H][m_cpu->H] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

										m_cpu->H = W;
										m_cpu->F = Z;

										m_core->CLOCK += 63;
										break;
									}

									case 0x63: // LD (nnnn),HL
									{
										Z = get(m_cpu->PC++, 0x82);
										W = get(m_cpu->PC++, 0x82);
										put(WZ++, m_cpu->L, 0x00);
										put(WZ, m_cpu->H, 0x00);
										break;
									}

									case 0x67: // RRD
									{
										Z = get(m_cpu->HL, 0x82);
										m_core->CLOCK += 36;

										put(m_cpu->HL, (Z >> 4) | (m_cpu->A << 4), 0x00);
										m_cpu->A = (m_cpu->A & 0xF0) | (Z & 0x0F);
										m_cpu->F = (m_cpu->F & 0x01) | ALU.flags[m_cpu->A];
										break;
									}

									case 0x68: // IN L,(C)
									{
										m_cpu->F = (m_cpu->F & 0x01) | ALU.flags[m_cpu->L = inp(m_cpu->BC)];
										break;
									}

									case 0x69: // OUT (C),L
									{
										out(m_cpu->BC, m_cpu->L);
										break;
									}

									case 0x6A: // ADC HL,HL
									{
										if(m_cpu->F & 1)
											WZ = ALU.ADC[m_cpu->L][m_cpu->L];
										else
											WZ = ALU.ADD[m_cpu->L][m_cpu->L];

										m_cpu->L = W;

										if(Z & 1)
											WZ = ALU.ADC[m_cpu->H][m_cpu->H] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
										else
											WZ = ALU.ADD[m_cpu->H][m_cpu->H] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

										m_cpu->H = W;
										m_cpu->F = Z;

										m_core->CLOCK += 63;
										break;
									}

									case 0x6B: // LD HL,(nnnn)
									{
										Z = get(m_cpu->PC++, 0x82);
										W = get(m_cpu->PC++, 0x82);
										m_cpu->L = get(WZ++, 0x82);
										m_cpu->H = get(WZ, 0x82);
										break;
									}

									case 0x6F: // RLD
									{
										Z = get(m_cpu->HL, 0x82);
										m_core->CLOCK += 36;

										put(m_cpu->HL, (Z << 4) | (m_cpu->A & 0x0F), 0x00);
										m_cpu->A = (m_cpu->A & 0xF0) | (Z >> 4);
										m_cpu->F = (m_cpu->F & 0x01) | ALU.flags[m_cpu->A];
										break;
									}

									case 0x70: // IN (C)
									{
										m_cpu->F = (m_cpu->F & 0x01) | ALU.flags[inp(m_cpu->BC)];
										break;
									}

									case 0x71: // OUT (C), 0
									{
										out(m_cpu->BC, 0);
										break;
									}

									case 0x72: // SBC HL,SP
									{
										if(m_cpu->F & 1)
											WZ = ALU.SBB[m_cpu->L][m_cpu->SPL];
										else
											WZ = ALU.SUB[m_cpu->L][m_cpu->SPL];

										m_cpu->L = W;

										if(Z & 1)
											WZ = ALU.SBB[m_cpu->H][m_cpu->SPH] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
										else
											WZ = ALU.SUB[m_cpu->H][m_cpu->SPH] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

										m_cpu->H = W;
										m_cpu->F = Z;

										m_core->CLOCK += 63;
										break;
									}

									case 0x73: // LD (xxxx),SP
									{
										Z = get(m_cpu->PC++, 0x82);
										W = get(m_cpu->PC++, 0x82);
										put(WZ++, m_cpu->SPL, 0x00);
										put(WZ, m_cpu->SPH, 0x00);
										break;
									}

									case 0x77: // NOP**
									{
										break;
									}

									case 0x78: // IN A,(C)
									{
										m_cpu->F = (m_cpu->F & 0x01) | ALU.flags[m_cpu->A = inp(m_cpu->BC)];
										break;
									}

									case 0x79: // OUT (C),A
									{
										out(m_cpu->BC, m_cpu->A);
										break;
									}

									case 0x7A: // ADC HL,SP
									{
										if(m_cpu->F & 1)
											WZ = ALU.ADC[m_cpu->L][m_cpu->SPL];
										else
											WZ = ALU.ADD[m_cpu->L][m_cpu->SPL];

										m_cpu->L = W;

										if(Z & 1)
											WZ = ALU.ADC[m_cpu->H][m_cpu->SPH] & (Z & 0x40 ? 0xFFFF : 0xFFBF);
										else
											WZ = ALU.ADD[m_cpu->H][m_cpu->SPH] & (Z & 0x40 ? 0xFFFF : 0xFFBF);

										m_cpu->H = W;
										m_cpu->F = Z;

										m_core->CLOCK += 63;
										break;
									}

									case 0x7B: // LD SP,(nnnn)
									{
										Z = get(m_cpu->PC++, 0x82);
										W = get(m_cpu->PC++, 0x82);
										m_cpu->SPL = get(WZ++, 0x82);
										m_cpu->SPH = get(WZ, 0x82);
										break;
									}

									case 0x7F: // NOP∗∗
									{
										break;
									}

									case 0xA0: // LDI
									case 0xB0: // LDIR
									{
										W = get(m_cpu->HL++, 0x82);
										put(m_cpu->DE++, W, 0x00);
										m_core->CLOCK += 18;
										m_cpu->BC--;

										W += m_cpu->A;

										m_cpu->F = (m_cpu->F & 0xC1) | (W & 0x08) | ((W & 0x02) << 4) | ((m_cpu->BC != 0) << 2);

										if(CMD == 0xB0 && m_cpu->BC)
										{
											m_core->CLOCK += 45;
											m_cpu->PC -= 2;
										}

										break;
									}

									case 0xA1: // CPI
									case 0xB1: // CPIR
									{
										WZ = ALU.SUB[m_cpu->A][get(m_cpu->HL++, 0x82)];
										m_core->CLOCK += 45;
										m_cpu->BC--;

										W -= (Z & 0x10) >> 4;
										m_cpu->F = (m_cpu->F & 0x01) | (Z & 0xD2) | (W & 0x08) | ((W & 0x02) << 4) | ((m_cpu->BC != 0) << 2);

										if(CMD == 0xB1 && (m_cpu->F & 0x44) == 0x04)
										{
											m_core->CLOCK += 45;
											m_cpu->PC -= 2;
										}

										break;
									}

									case 0xA2: // INI
									case 0xB2: // INIR
									{
										m_core->CLOCK += 9;
										Z = inp(m_cpu->BC);
										put(m_cpu->HL++, Z, 0x00);

										m_cpu->F = (m_cpu->F & 0x01) | ALU.DCR[--m_cpu->B] | (Z & 0x80) >> 6;

										if(CMD == 0xB2 && (m_cpu->F & 0x40) == 0x40)
										{
											m_core->CLOCK += 45;
											m_cpu->PC -= 2;
										}

										break;
									}

									case 0xA3: // OUTI
									case 0xB3: // OTIR
									{
										m_core->CLOCK += 9;
										Z = get(m_cpu->HL++, 0x82);
										out(m_cpu->BC, Z);

										m_cpu->F = (m_cpu->F & 0x01) | ALU.DCR[--m_cpu->B] | (Z & 0x80) >> 6;

										if(CMD == 0xB3 && (m_cpu->F & 0x40) == 0x40)
										{
											m_core->CLOCK += 45;
											m_cpu->PC -= 2;
										}

										break;
									}

									case 0xA8: // LDD
									case 0xB8: // LDDR
									{
										W = get(m_cpu->HL--, 0x82);
										put(m_cpu->DE--, W, 0x00);
										m_core->CLOCK += 18;
										m_cpu->BC--;

										W += m_cpu->A;
										m_cpu->F = (m_cpu->F & 0xC1) | (W & 0x08) | ((W & 0x02) << 4) | ((m_cpu->BC != 0) << 2);

										if(CMD == 0xB8 && m_cpu->BC)
										{
											m_core->CLOCK += 45;
											m_cpu->PC -= 2;
										}

										break;
									}

									case 0xA9: // CPD
									case 0xB9: // CPDR
									{
										WZ = ALU.SUB[m_cpu->A][get(m_cpu->HL--, 0x82)];
										m_core->CLOCK += 45;
										m_cpu->BC--;

										W -= (Z & 0x10) >> 4;
										m_cpu->F = (m_cpu->F & 0x01) | (Z & 0xD2) | (W & 0x08) | ((W & 0x02) << 4) | ((m_cpu->BC != 0) << 2);

										if(CMD == 0xB9 && (m_cpu->F & 0x44) == 0x04)
										{
											m_core->CLOCK += 45;
											m_cpu->PC -= 2;
										}

										break;
									}

									case 0xAA: // IND
									case 0xBA: // INDR
									{
										m_core->CLOCK += 9;
										Z = inp(m_cpu->BC);
										put(m_cpu->HL--, Z, 0x00);

										m_cpu->F = (m_cpu->F & 0x01) | ALU.DCR[--m_cpu->B] | (Z & 0x80) >> 6;

										if(CMD == 0xBA && (m_cpu->F & 0x40) == 0x40)
										{
											m_core->CLOCK += 45;
											m_cpu->PC -= 2;
										}

										break;
									}

									case 0xAB: // OUTD
									case 0xBB: // OTDR
									{
										m_core->CLOCK += 9;
										Z = get(pHL->HL--, 0x82);
										out(m_cpu->BC, Z);

										m_cpu->F = (m_cpu->F & 0x01) | ALU.DCR[--m_cpu->B] | (Z & 0x80) >> 6;

										if(CMD == 0xBB && (m_cpu->F & 0x40) == 0x40)
										{
											m_core->CLOCK += 45;
											m_cpu->PC -= 2;
										}

										break;
									}

									default:

										CMD = fetch(m_cpu->PC++);
										continue;
								}

							}

							break;
						}

					}

					break;
				}
			}
		}

		void reset() final
		{
			m_cpu->PC = 0x0000;
			m_cpu->HLT = false;

			m_core->INTE(m_cpu->IF = false);

			if constexpr(z80)
			{
				m_cpu->IFF2 = false;
				m_cpu->IM = 0;
			}
		}
	};

	template<>
	constinit const unsigned CPU<I8080>::timings[256] = {
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
	constinit const unsigned CPU<I8085>::timings[256] = {
	};

	template<>
	constinit const unsigned CPU<VM1>::timings[256] = {
	};

	template<>
	constinit const unsigned CPU<Z80>::timings[256] = {
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

I8080::I8080(Core* core) : I8080(core, new CPU(this, core)) {}

I8085::I8085(Core* core) : I8080(core, new CPU(this, core)) {}

VM1::VM1(Core* core) : I8080(core, new CPU(this, core)) {}

Z80::Z80(Core* core) : I8080(core, new CPU(this, core)) {}

