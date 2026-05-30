/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2026 Andrey Chicherov <andrey@chicherov.ru>

 Эмуляция микропроцессоров КР580ВМ80А и Zilog Z80

*****/

#ifndef RETRO80_I8080_H
#define RETRO80_I8080_H
#include <cstdint>
#include <limits>

struct I8080
{
	struct Core
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

		virtual ~Core() = default;
	};

	// -------------------------------------------------------------------------

	struct Impl
	{
		virtual void execute(uint64_t limit) = 0;
		virtual void reset() = 0;
		virtual ~Impl() = default;
	};

	// -------------------------------------------------------------------------

	Core *m_core;
	Impl *m_impl;

	union { uint16_t PC{}; struct { uint8_t PCL; uint8_t PCH; }; };
	union { uint16_t SP{}; struct { uint8_t SPL; uint8_t SPH; }; };

	union { uint16_t AF{}; struct { uint8_t F; uint8_t A; }; };
	union { uint16_t BC{}; struct { uint8_t C; uint8_t B; }; };
	union { uint16_t DE{}; struct { uint8_t E; uint8_t D; }; };
	union { uint16_t HL{}; struct { uint8_t L; uint8_t H; }; };

	bool HLT{}, IF{};

	// -------------------------------------------------------------------------

	explicit I8080(Core* core);

	virtual ~I8080()
	{
		delete m_impl;
	}

	void execute(uint64_t limit = 0) const
	{
		m_impl->execute(limit);
	}

	void reset() const
	{
		m_impl->reset();
	}

protected:

	I8080(Core* core, Impl* impl) : m_core(core), m_impl(impl) {}
};

// -----------------------------------------------------------------------------

struct I8085 : public I8080
{
	explicit I8085(Core* core);
};

// -----------------------------------------------------------------------------

struct VM1: public I8080
{
	explicit VM1(Core* core);
};

// -----------------------------------------------------------------------------

struct Z80: public I8080
{
	explicit Z80(Core* core);

	union { uint16_t AF1{}; struct { uint8_t F1; uint8_t A1; }; };
	union { uint16_t BC1{}; struct { uint8_t C1; uint8_t B1; }; };
	union { uint16_t DE1{}; struct { uint8_t E1; uint8_t D1; }; };
	union { uint16_t HL1{}; struct { uint8_t L1; uint8_t H1; }; };

	union { uint16_t IX{}; struct { uint8_t IXL; uint8_t IXH; }; };
	union { uint16_t IY{}; struct { uint8_t IYL; uint8_t IYH; }; };

	uint8_t R{};
	uint8_t I{};

	uint8_t IM{};
	bool IFF2{};
};

#endif //RETRO80_I8080_H
