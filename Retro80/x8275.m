/*******************************************************************************
 Контроллер отображения видеоинформации КР580ВГ75 (8275)
 ******************************************************************************/

#import "X8275.h"

@implementation X8275
{
	uint8_t* cmd;	// Указатель на байты заполняемой структуры
	unsigned len;	// Количество оставшихся байт

	// -------------------------------------------------------------------------
	// Тайминги ROW и DMA
	// -------------------------------------------------------------------------

	uint64_t rowClock;
	uint64_t rowTimer;
	uint64_t dmaTimer;

	// -------------------------------------------------------------------------
	// Буфер строки и FIFO
	// -------------------------------------------------------------------------

	uint8_t buffer[80], bpos;
	uint8_t fifo[16], fpos;

	// -------------------------------------------------------------------------
	// Буфер экрана
	// -------------------------------------------------------------------------

	union i8275_char
	{
		struct
		{
			unsigned  H:1;	// highlight
			unsigned  B:1;	// blink
			unsigned G0:1;	// general purpose 0
			unsigned G1:1;	// general purpose 1
			unsigned  R:1;	// reverse
			unsigned  U:1;	// underline
			unsigned   :2;
		};

		struct
		{
			uint8_t attr;
			uint8_t byte;
		};

		uint16_t word;

	} screen[64][80];

	uint8_t blink;
	unsigned row;

	uint8_t attr;
	BOOL EoR;
	BOOL EoS;

	// -------------------------------------------------------------------------
	//
	// -------------------------------------------------------------------------

	NSData *rom; const uint8_t *font;
	const uint32_t *_colors;
	uint8_t _attributesMask;
}

static uint8_t special[][3] =
{
	{ 0x00, 0x07, 0x04 },	// 0000
	{ 0x00, 0x3C, 0x04 },	// 0001
	{ 0x04, 0x07, 0x00 },	// 0010
	{ 0x04, 0x3C, 0x00 },	// 0011
	{ 0x00, 0x3F, 0x04 },	// 0100
	{ 0x04, 0x3C, 0x04 },	// 0101
	{ 0x04, 0x07, 0x04 },	// 0110
	{ 0x04, 0x3F, 0x00 },	// 0111
	{ 0x00, 0x3F, 0x00 },	// 1000
	{ 0x04, 0x04, 0x04 },	// 1001
	{ 0x04, 0x3F, 0x04 },	// 1010

	{ 0x00, 0x00, 0x00 }	// 1011
};

// -----------------------------------------------------------------------------

- (void) setColors:(const uint32_t *)colors attributeMask:(uint8_t)attributesMask
{
	_colors = colors; _attributesMask = attributesMask;
	memset(screen, -1, sizeof(screen));
}

// -----------------------------------------------------------------------------

- (void) setFontOffset:(unsigned int)offset
{
	font = (const uint8_t *)rom.bytes + offset;
	memset(screen, -1, sizeof(screen));
}

// -----------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)st
{
	if ((addr & 1) == 1)
	{
		uint8_t ret = status.byte;

		status.IR = 0;
		status.LP = 0;
		status.IC = 0;
		status.DU = 0;
		status.FO = 0;

		return ret;
	}

	return 0x00;
}

// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	if ((addr & 1) == 1)
	{
		if (data == 0x00)				// Команда Reset
		{
			@synchronized(self)
			{
				isSelected = FALSE;
				isText = FALSE;

				status.VE = 0;
				status.IE = 0;
			}

			cmd = config.byte;
			status.IC = 1;
			len = 4;
		}

		else if ((data & 0xE0) == 0x20)	// Команды Start Display
		{
			@synchronized(self)
			{
				if (status.VE == 0)
				{
					memset(screen, -1, sizeof(screen));

					[self setupTextWidth:config.H + 1
								  height:config.R + 1
									  cx:6
									  cy:config.L + 1];

					rowClock = (config.H + ((config.Z + 1) << 1)) * (config.L + 1) * 12;
					rowTimer = clock  + rowClock;

					row = config.R + config.V + 1;
					bpos = 0; dmaTimer = 0;
					
				}

				mode.byte = data;
				status.VE = 1;
				status.IE = 1;
			}
		}

		else if (data == 0x40)			// Команда Stop Display
		{
			@synchronized(self)
			{
				isSelected = FALSE;
				isText = FALSE;
				status.VE = 0;
			}
		}

		else if (data == 0x60)			// Команда Read Light Pen
		{
		}

		else if (data == 0x80)			// Команда Load Cursor
		{
			cmd = cursor.byte;
			status.IC = 1;
			len = 2;
		}

		else if (data == 0xA0)			// Команда Enable Interupt
		{
			status.IE = 1;
		}

		else if (data == 0xC0)			// Команда Disable Interupt
		{
			status.IE = 0;
		}

		else if (data == 0xE0)			// Команда Preset Counters
		{
			if (status.VE)
			{
				rowClock = (config.H + ((config.Z + 1) << 1)) * (config.L + 1) * 12;
				rowTimer = clock + rowClock;

				row = config.R + config.V + 1;
				bpos = 0; dmaTimer = 0;
			}
		}
	}

	else
	{
		if (len)
		{
			status.IC = --len != 0;
			*cmd++ = data;
		}
		else
		{
			status.IC = 1;
		}
	}
}

// -----------------------------------------------------------------------------

- (unsigned) HOLD:(uint64_t)clock
{
	unsigned clk = 0; if (status.VE)
	{
		if (rowTimer <= clock)
		{
			if (++row == config.R + config.V + 2)
			{
				row = 0; attr = 0x80; EoS = FALSE;
				blink = (blink + 1) & 0x1F;
				self.needsDisplay = TRUE;
			}

			if (row <= config.R)
			{
				if (row == config.R)
					status.IR = status.IE;

				EoR = FALSE; for (uint8_t col = 0, f = 0; col <= config.H; col++)
				{
					union i8275_char ch;

					ch.byte = 0x00; if (!EoS && !EoR)
					{
						if (col < bpos)
							ch.byte = buffer[col];
						else
							status.DU = 1;
					}

					if ((ch.byte & 0x80) == 0x00)					// 0xxxxxxx
					{
						ch.attr = attr;
					}

					else if ((ch.byte & 0xC0) == 0x80)				// 10xxxxxx
					{
						attr = ch.byte; if (config.F)
						{
							ch.attr = _colors ? 0 : attr;
							ch.byte = 0x00;
						}
						else
						{
							ch.byte = fifo[f++ & 0x0F];
							ch.attr = attr;
						}
					}

					else if ((ch.byte & 0xF0) == 0xF0)				// 1111xxxx
					{
						if (ch.byte & 0x02)
							EoS = TRUE;
						else
							EoR = TRUE;

						ch.attr = attr;
						ch.byte = 0x00;
					}

					else											// 11xxxxxx
					{
						ch.attr = (attr & 0x3C) | (ch.byte & 0x83);
						ch.byte = ((ch.byte >> 2) & 0x0F) | 0x80;
					}

					if (row == cursor.ROW && col == cursor.COL)
					{
						switch (config.C)
						{
							case 0:
								ch.R = (blink & 0x10) ? 1 : 0;
								break;

							case 1:
								ch.U = (blink & 0x10) ? 1 : 0;
								break;

							case 2:
								ch.R = 1;
								break;

							case 3:
								ch.U = 1;
								break;
						}
					}

					if (ch.B && (blink & 0x10) == 0x00)
						ch.byte = 0;

					ch.attr &= _attributesMask;

					if (isSelected)
						if (row >= selected.origin.y && row < selected.origin.y + selected.size.height)
							if (col >= selected.origin.x && col < selected.origin.x + selected.size.width)
								ch.R ^= 1;

					if (screen[row][col].word != ch.word)
					{
						screen[row][col].word = ch.word;

						uint32_t b0 = _colors ? _colors[0x0F & _attributesMask] : ch.attr & 0x01 ? 0xFF555555 : 0xFF000000;
						uint32_t b1 = _colors ? _colors[ch.attr & 0x0F] : ch.attr & 0x01 ? 0xFFFFFFFF : 0xFFAAAAAA;

						if (ch.byte < 0x80)
						{
							const unsigned char *fnt = font + (ch.byte << 3);

							for (unsigned line = 0; line <= config.L; line++)
							{
								uint8_t byte = 0x00; if (config.M)
								{
									if (line == 0)
									{
										if (config.L < 8) byte = fnt[config.L];

									}
									else if (line < 9)
									{
										byte = *fnt++;
									}
								}
								else
								{
									if (line < 8) byte = *fnt++;
								}

								if (line > 7 && line == config.U && ch.U)
									byte = 0xFF;

								if (ch.R)
									byte ^= 0xFF;

								for (int i = 0; i < 6; i++, byte <<= 1)
								{
									unsigned address = ((row * (config.L + 1) + line) * (config.H + 1) + col) * 6 + i;
									bitmap[address] = byte & 0x20 ? b1 : b0;
								}
							}
						}
						else
						{
							for (unsigned line = 0; line <= config.L; line++)
							{
								uint8_t byte = line < config.U ? special[ch.byte - 0x80][0] : line == config.U ? special[ch.byte - 0x80][1] : special[ch.byte - 0x80][2];

								if (ch.R)
									byte ^= 0xFF;

								for (int i = 0; i < 6; i++, byte <<= 1)
									bitmap[((row * (config.L + 1) + line) * (config.H + 1) + col) * 6 + i] = byte & 0x20 ? b1 : b0;
							}
						}
					}
				}

			}

			if (row == config.R + config.V + 1)
			{
			}

			if (dmaTimer != (uint64_t)-2 || row == config.R + config.V + 1)
			{
				if (row < config.R || row == config.R + config.V + 1)
				{
					bpos = 0; fpos = 0; dmaTimer = 0;
				}
				else
				{
					dmaTimer = (uint64_t)-1;
				}
			}

			rowTimer += rowClock;
		}

		if (_dma && dmaTimer <= clock)
		{
			unsigned count = mode.S ? 1 << mode.B : (unsigned) -1;

			if (count + bpos > config.H + 1)
			{
				count = config.H + 1 - bpos;
			}

			while (count--)
			{
				uint8_t byte; if (i8257DMA2(_dma, &byte))
				{
					clk += 36; buffer[bpos++] = byte;

					if ((byte & 0xC0) == 0x80 && config.F == 0)
					{
						if (i8257DMA2(_dma, &byte))
						{
							clk += 36; fifo[fpos++] = byte & 0x7F;

							if (fpos == 16)
							{
								status.FO = 1;
								fpos = 0;
							}
						}
						else
						{
							return clk;
						}
					}

					else if ((byte & 0xF3) == 0xF1)
					{
						dmaTimer = (uint64_t)-1;

						if (count && i8257DMA2(_dma, &byte))
							clk += 36;

						return clk;
					}

					else if ((byte & 0xF3) == 0xF3)
					{
						dmaTimer = (uint64_t)-2;

						if (count && i8257DMA2(_dma, &byte))
							clk += 36;

						return clk;
					}
				}
				else
				{
					return clk;
				}
			}

			static unsigned burstSpace[8] =
			{
				0, 7, 15, 23, 31, 39, 47, 55
			};
			
			dmaTimer = bpos <= config.H ? clock + clk + (burstSpace[mode.S]) * 12 : (uint64_t)-1;
		}
	}

	return clk;
}

// -----------------------------------------------------------------------------

- (void)drawRect:(NSRect)rect
{
	@synchronized(self)
	{
		if (status.VE)
		{
			[super drawRect:rect];
		}

		else
		{
			glClear(GL_COLOR_BUFFER_BIT);
			glFlush();
		}
	}
}

// -----------------------------------------------------------------------------
// Copy to pasteboard
// -----------------------------------------------------------------------------

- (uint8_t) byteAtX:(NSUInteger)x y:(NSUInteger)y
{
	return screen[y][x].byte;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		if ((rom = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SYMGEN" ofType:@"BIN"]]) == nil)
			return self = nil;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	[encoder encodeInt:status.byte forKey:@"status"];
	[encoder encodeInt32:*(uint32_t *)config.byte forKey:@"config"];
	[encoder encodeInt:*(uint16_t *)cursor.byte forKey:@"cursor"];
	[encoder encodeInt:mode.byte forKey:@"mode"];

	[encoder encodeInt64:rowClock forKey:@"rowClock"];
	[encoder encodeInt64:rowTimer forKey:@"rowTimer"];
	[encoder encodeInt64:dmaTimer forKey:@"dmaTimer"];

	[encoder encodeInt:row forKey:@"row"];
	[encoder encodeInt:bpos forKey:@"pos"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		if ((rom = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SYMGEN" ofType:@"BIN"]]) == nil)
			return self = nil;

		status.byte = [decoder decodeIntForKey:@"status"];
		*(uint32_t *)config.byte = [decoder decodeInt32ForKey:@"config"];
		*(uint16_t *)cursor.byte = [decoder decodeIntForKey:@"cursor"];
		mode.byte = [decoder decodeIntForKey:@"mode"];

		rowClock = [decoder decodeInt64ForKey:@"rowClock"];
		rowTimer = [decoder decodeInt64ForKey:@"rowTimer"];
		dmaTimer = [decoder decodeInt64ForKey:@"dmaTimer"];

		row = [decoder decodeIntForKey:@"row"];
		bpos = [decoder decodeIntForKey:@"pos"];

		if (status.VE)
		{
			[self setupTextWidth:config.H + 1
						  height:config.R + 1
							  cx:6
							  cy:config.L + 1];
		}
	}

	return self;
}

@end
