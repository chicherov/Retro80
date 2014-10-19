/*******************************************************************************
 Контроллер отображения видеоинформации КР580ВГ75 (8275)
 ******************************************************************************/

#import "X8275.h"

@implementation X8275
{
	union i8275_config cfg;	// Новая конфигурация
	unsigned cmd:8;			// Последняя команда
	unsigned len:8;			// Данные команды

	// -------------------------------------------------------------------------
	// Тайминги ROW и DMA
	// -------------------------------------------------------------------------

	uint64_t rowClock;
	uint64_t rowTimer;
	uint64_t dmaTimer;

	// -------------------------------------------------------------------------
	// Буфер строки и FIFO
	// -------------------------------------------------------------------------

	uint8_t buffer[80], pos;
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

	} screen[2][64][80];

	BOOL hideCursor;

	unsigned row;
	uint8_t attr;
	BOOL EoR;
	BOOL EoS;

	// -------------------------------------------------------------------------
	// Световое перо
	// -------------------------------------------------------------------------

	union i8275_cursor lightPen;
	BOOL rightMouse;
	
	// -------------------------------------------------------------------------
	// Внешние настройки
	// -------------------------------------------------------------------------

	NSData *rom; const uint8_t *font;
	const uint16_t *fonts;

	uint8_t attributesMask;
	const uint32_t *colors;

}

// -----------------------------------------------------------------------------

- (void) setColors:(const uint32_t *)ptr attributesMask:(uint8_t)mask
{
	colors = ptr; fonts = NULL; attributesMask = mask;
	memset(screen, -1, sizeof(screen));
}

// -----------------------------------------------------------------------------

- (void) setFonts:(const uint16 *)ptr attributesMask:(uint8_t)mask
{
	font = (const uint8_t *)rom.bytes; fonts = ptr;
	colors = NULL; attributesMask = mask;
}

// -----------------------------------------------------------------------------

- (void) selectFont:(unsigned int)offset
{
	font = (const uint8_t *)rom.bytes + offset;
	memset(screen, -1, sizeof(screen));
}

// -----------------------------------------------------------------------------
// Графические символы
// -----------------------------------------------------------------------------

static struct special
{
	BOOL LA1;
	BOOL LA0;
	BOOL VSP;
	BOOL LTEN;
}
CCCC[][3] =
{
	{{0, 0, 1, 0}, {1, 0, 0, 0}, {0, 1, 0, 0}},	// 0000
	{{0, 0, 1, 0}, {1, 1, 0, 0}, {0, 1, 0, 0}},	// 0001
	{{0, 1, 0, 0}, {1, 0, 0, 0}, {0, 0, 1, 0}},	// 0010
	{{0, 1, 0, 0}, {1, 1, 0, 0}, {0, 0, 1, 0}},	// 0011
	{{0, 0, 1, 0}, {0, 0, 0, 1}, {0, 1, 0, 0}},	// 0100
	{{0, 1, 0, 0}, {1, 1, 0, 0}, {0, 1, 0, 0}},	// 0101
	{{0, 1, 0, 0}, {1, 0, 0, 0}, {0, 1, 0, 0}},	// 0110
	{{0, 1, 0, 0}, {0, 0, 0, 1}, {0, 0, 1, 0}},	// 0111
	{{0, 0, 1, 0}, {0, 0, 0, 1}, {0, 0, 1, 0}},	// 1000
	{{0, 1, 0, 0}, {0, 1, 0, 0}, {0, 1, 0, 0}},	// 1001
	{{0, 1, 0, 0}, {0, 0, 0, 1}, {0, 1, 0, 0}},	// 1010
	{{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}	// 1011
};

// -----------------------------------------------------------------------------
// Чтение/запись регистров ВГ75
// -----------------------------------------------------------------------------

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)st
{
	@synchronized(self)
	{
		if ((addr & 1) == 1)
		{
			uint8_t ret = status.byte;

			status.IR = 0;
			status.IC = 0;
			status.DU = 0;
			status.FO = 0;

			if (!rightMouse)
				status.LP = 0;

			return ret;
		}
		else
		{
			if ((cmd & 0xE0) == 0x60 && len < 2)
			{
				return lightPen.byte[len++];
			}
			else
			{
				status.IC = 1;
				return 0x00;
			}
		}
	}
}

// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	@synchronized(self)
	{
		if ((addr & 1) == 1)
		{
			if ((cmd & 0xE0) == 0x00 && len != 4)
				status.IC = 1;

			if ((cmd & 0xE0) == 0x60 && len != 2)
				status.IC = 1;

			if ((cmd & 0xE0) == 0x80 && len != 2)
				status.IC = 1;

			cmd = data;
			len = 0;

			switch (cmd & 0xE0)
			{
				case 0x00:					// Команда Reset
				{
					status.VE = 0;
					status.IE = 0;
					break;
				}

				case 0x20:					// Команда Start Display
				{
					mode.byte = data;
					status.VE = 1;
					status.IE = 1;
					break;
				}

				case 0x40:					// Команда Stop Display
				{
					status.VE = 0;
					break;
				}

				case 0x60:					// Команда Read Light Pen
				{
					break;
				}

				case 0x80:					// Команда Load Cursor
				{
					break;
				}

				case 0xA0:					// Команда Enable Interupt
				{
					status.IE = 1;
					break;
				}

				case 0xC0:					// Команда Disable Interupt
				{
					status.IE = 0;
					break;
				}

				case 0xE0:					// Команда Preset Counters
				{
					if (status.VE)
					{
						EoS = TRUE; dmaTimer = -2;
						hideCursor = TRUE;
					}

					break;
				}
			}
		}
		else
		{
			if ((cmd & 0xE0) == 0x00 && len < 4)
			{
				cfg.byte[len++] = data; if (len == 4)
				{
					if (*(uint32_t*)config.byte != *(uint32_t*)cfg.byte)
					{
						config = cfg; memset(screen, -1, sizeof(screen));

						[self setupTextWidth:config.H + 1
									  height:config.R + 1
										  cx:6
										  cy:config.L + 1];

						rowClock = (config.H + 1 + ((config.Z + 1) << 1)) * (config.L + 1) * 12;
//						rowTimer = clock; rowTimer += 12 - (rowTimer % 12);
//						row = config.R + config.V;
					}
				}
			}

			else if ((cmd & 0xE0) == 0x80 && len < 2)
			{
				cursor.byte[len++] = data;
			}
			
			else
			{
				status.IC = 1;
			}
		}
	}
}

// -----------------------------------------------------------------------------
// Переодические вызовы из модуля CPU
// -----------------------------------------------------------------------------

- (unsigned) HLDA:(uint64_t)clock WR:(BOOL)wr
{
	if (rowClock)
	{
		@synchronized(self)
		{
			if (rowTimer <= clock)
			{
				if (++row >= config.R + config.V + 2)
				{
					row = 0; attr = 0x80; EoS = FALSE;

					if (frame++ & 1)
						self.needsDisplay = TRUE;
				}

				if (row <= config.R)
				{
					if (pos != config.H + 1)
					{
						status.DU = 1;
						dmaTimer = -2;
						EoS = TRUE;
					}

					if (row == config.R && status.IE)
						status.IR = TRUE;

					EoR = FALSE; for (uint8_t col = 0, f = 0; col <= config.H; col++)
					{
						union i8275_char ch;

						if (status.VE && !EoS && !EoR)
							ch.byte = buffer[col];
						else
							ch.byte = 0x00;

						if ((ch.byte & 0x80) == 0x00)					// 0xxxxxxx
						{
							ch.attr = attr;
						}

						else if ((ch.byte & 0xC0) == 0x80)				// 10xxxxxx
						{
							attr = ch.byte; if (config.F)
							{
								ch.attr = colors ? 0 : attr;
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
						}

						if (status.VE && row == cursor.ROW && col + (fonts != NULL) == cursor.COL)
						{
							if (hideCursor)
								hideCursor = FALSE;

							else switch (config.C)
							{
								case 0:
									ch.R = (frame & 0x10) ? 1 : 0;
									break;

								case 1:
									ch.U = (frame & 0x10) ? 1 : 0;
									break;

								case 2:
									ch.R = 1;
									break;

								case 3:
									ch.U = 1;
									break;
							}
						}

						if (ch.B && (frame & 0x10) == 0x00)
							ch.byte = 0;

						ch.attr &= attributesMask;

						if (screen[frame & 1][row][col].word != ch.word)
						{
							screen[frame & 1][row][col].word = ch.word;

							uint32_t b0 = colors ? colors[0x0F & attributesMask] : fonts == NULL && ch.H ? 0xFF555555 : 0xFF000000;
							uint32_t b1 = colors ? colors[ch.attr & 0x0F] : fonts == NULL && ch.H ? 0xFFFFFFFF : 0xFFAAAAAA;

							if (frame & 1)
							{
								b0 &= 0x7FFFFFFF;
								b1 &= 0x7FFFFFFF;
							}

							uint32_t *ptr = bitmap + ((row + (frame & 1 ? config.R + 1 : 0)) * (config.L + 1) * (config.H + 1) + col) * 6;

							const unsigned char *fnt = font + ((ch.byte & 0x7F) << 3);
							if (fonts) fnt += fonts[ch.attr & 0x0F];

							for (unsigned L = 0; L <= config.L; L++)
							{
								uint8_t byte = fnt[(config.M ? (L ? L - 1 : config.L) : L) & 7];

								if ((ch.byte & 0x80) == 0x00)
								{
									if (config.U & 0x08 && (L == 0 || L == config.L))
										byte = 0x00;
								}
								else
								{
									struct special *special = &CCCC[(ch.byte >> 2) & 0x0F][L > config.U ? 2 : L == config.U];

//									byte = special->LA1 ? (special->LA0 ? 0x3C : 0x07) : (special->LA0 ? 0x04 : 0x00);

									if (special->VSP)
										byte = 0x00;

									if (special->LTEN)
										byte = 0xFF;
								}

								if (L == config.U && ch.U) byte = 0xFF;
								if (ch.R) byte = ~byte;

								for (int i = 0; i < 6; i++, byte <<= 1)
									*ptr ++ = byte & 0x20 ? b1 : b0;

								ptr += config.H * 6;
							}
						}
					}
				}

				if (dmaTimer != -2 || row == config.R + config.V + 1)
				{
					if (status.VE && (row < config.R || row == config.R + config.V + 1))
					{
						pos = 0; fpos = 0; dmaTimer = rowTimer + (mode.S ? (mode.S << 3) - 1 : 0) * 12;
					}
					else
					{
						dmaTimer = -1;
					}
				}

				rowTimer += rowClock;
			}

			if (_dma && dmaTimer <= clock)
			{
				unsigned count = 1 << mode.B; if (count + pos > config.H + 1)
				{
					count = config.H + 1 - pos;
				}

				unsigned clk = 0; while (count--)
				{
					uint8_t byte; if (i8257DMA2(_dma, &byte))
					{
						clk += clk ? 36 : (wr ? 54 : 45); buffer[pos++] = byte;

						if ((byte & 0xC0) == 0x80 && config.F == 0)
						{
							if (i8257DMA2(_dma, &byte))
							{
								clk += 36; fifo[fpos++ & 0x0F] = byte & 0x7F;

								if (fpos == 17)
									status.FO = 1;
							}
							else
							{
								dmaTimer = -2;
								return clk;
							}
						}

						else if ((byte & 0xF3) == 0xF1)
						{
							pos = config.H + 1;
							dmaTimer = -1;

							if (count && i8257DMA2(_dma, &byte))
								clk += 36;
							
							return clk;
						}
						
						else if ((byte & 0xF3) == 0xF3)
						{
							pos = config.H + 1;
							dmaTimer = -2;

							if (count && i8257DMA2(_dma, &byte))
								clk += 36;
							
							return clk;
						}
					}
					else
					{
						dmaTimer = -2;
						return clk;
					}
				}

				if (pos <= config.H)
				{
					dmaTimer = clock + clk + (mode.S ? (mode.S << 3) - 1 : 0) * 12;
					dmaTimer += 12 - (dmaTimer % 12);
				}
				else
				{
					dmaTimer = -1;
				}

				return clk;
			}
		}

	}

	return 0;
}

// -----------------------------------------------------------------------------
// Световое перо
// -----------------------------------------------------------------------------

- (void) rightMouseDragged:(NSEvent *)theEvent
{
	[self rightMouseDown:theEvent];
}

- (void) rightMouseDown:(NSEvent *)theEvent
{
	NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];

	@synchronized(self)
	{
		if (status.VE)
		{
			lightPen.ROW = trunc(text.height - point.y / self.frame.size.height * text.height);
			lightPen.COL = trunc(point.x / self.frame.size.width * text.width) + 8;
			rightMouse = TRUE;
			status.LP = 1;
		}
	}
}

- (void) rightMouseUp:(NSEvent *)theEvent
{
	@synchronized(self)
	{
		status.LP = 0;
	}
}

// -----------------------------------------------------------------------------
// Copy to pasteboard
// -----------------------------------------------------------------------------

- (uint8_t) byteAtX:(NSUInteger)x y:(NSUInteger)y
{
	return screen[0][y][x].byte;
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

	[encoder encodeInt64:rowTimer forKey:@"rowTimer"];
	[encoder encodeInt64:rowClock forKey:@"rowClock"];
	[encoder encodeInt64:dmaTimer forKey:@"dmaTimer"];

	[encoder encodeInt32:*(uint32_t *)cfg.byte forKey:@"cfg"];
	[encoder encodeInt:cmd forKey:@"cmd"];
	[encoder encodeInt:len forKey:@"len"];

	[encoder encodeInt:row forKey:@"row"];
	[encoder encodeInt:pos forKey:@"pos"];
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

		rowTimer = [decoder decodeInt64ForKey:@"rowTimer"];
		rowClock = [decoder decodeInt64ForKey:@"rowClock"];
		dmaTimer = [decoder decodeInt64ForKey:@"dmaTimer"];

		*(uint32_t *)cfg.byte = [decoder decodeInt32ForKey:@"cfg"];
		cmd = [decoder decodeIntForKey:@"cmd"];
		len = [decoder decodeIntForKey:@"len"];

		row = [decoder decodeIntForKey:@"row"];
		pos = [decoder decodeIntForKey:@"pos"];

		if (rowClock)
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
