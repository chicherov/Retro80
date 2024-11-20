/*****

Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2024 Andrey Chicherov <andrey@chicherov.ru>

 *****/

#ifndef RETRO80_CORE_H
#define RETRO80_CORE_H
#include "coder.h"

struct ICore
{
	Searialize(CLOCK, HOLD, NMI, IRQ, IRQLoop);

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

#endif //RETRO80_CORE_H
