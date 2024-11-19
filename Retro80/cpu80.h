/*****

Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2024 Andrey Chicherov <andrey@chicherov.ru>

 *****/

#ifndef RETRO80_CPU80_H
#define RETRO80_CPU80_H
#include <cstdint>
#include <limits>

//

struct ICore
{
	uint64_t CLOCK = 0;

	virtual void MEMW(uint16_t addr, uint8_t data, uint8_t status) = 0;
	virtual uint8_t MEMR(uint16_t addr, uint8_t status) = 0;

	virtual void IOW(uint16_t addr, uint8_t data, uint8_t status)
	{
		MEMW(addr, data, status);
	}

	virtual uint8_t IOR(uint16_t addr, uint8_t status)
	{
		return MEMR(addr, status);
	}

	virtual uint8_t INTA(uint16_t addr, uint8_t status)
	{
		return 0xFF;
	}

	virtual void HLTA(uint16_t addr, uint8_t status)
	{
	}

	uint64_t HOLD = std::numeric_limits<uint64_t>::max();

	virtual bool HLDA(bool)
	{
		return false;
	}

	uint64_t NMI = std::numeric_limits<uint64_t>::max();
	uint64_t IRQ = std::numeric_limits<uint64_t>::max();
	uint32_t IRQLoop = 0;

	virtual void INTE(bool)
	{
	}

	virtual ~ICore() = default;
};

//

struct CPU
{
	enum class Type { I8080, I8085, VM1, Z80 } m_cpuType;

	ICore *m_core;

	// I8080

	union { uint16_t PC{}; struct { uint8_t PCL; uint8_t PCH; }; };
	union { uint16_t SP{}; struct { uint8_t SPL; uint8_t SPH; }; };

	union { uint16_t AF{}; struct { uint8_t F; uint8_t A; }; };
	union { uint16_t BC{}; struct { uint8_t C; uint8_t B; }; };
	union { uint16_t DE{}; struct { uint8_t E; uint8_t D; }; };
	union { uint16_t HL{}; struct { uint8_t L; uint8_t H; }; };

	// Z80

	union { uint16_t AF1{}; struct { uint8_t F1; uint8_t A1; }; };
	union { uint16_t BC1{}; struct { uint8_t C1; uint8_t B1; }; };
	union { uint16_t DE1{}; struct { uint8_t E1; uint8_t D1; }; };
	union { uint16_t HL1{}; struct { uint8_t L1; uint8_t H1; }; };

	union { uint16_t IX{}; struct { uint8_t IXL; uint8_t IXH; }; };
	union { uint16_t IY{}; struct { uint8_t IYL; uint8_t IYH; }; };

	uint8_t R{};
	uint8_t I{};

	bool HLT{}, IF{}, IFF2{};
	uint8_t IM{};

	//

	void reset(uint16_t start = 0x0000);
	bool execute(uint64_t limit);

	CPU(Type cpuType, ICore *core) : m_cpuType(cpuType), m_core(core)
	{
	}

	explicit CPU(ICore *core) : CPU(Type::I8080, core)
	{
	}

	uint8_t *m_breakpoints = nullptr;
	uint64_t m_break{};

private:

	template<Type cpuType>
	static unsigned timings[256];

	template<Type cpuType>
	bool internal(uint64_t);
};

#endif //RETRO80_CPU80_H
