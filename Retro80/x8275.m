/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Контроллер отображения видеоинформации КР580ВГ75 (8275)

 *****/

#import "x8275.h"

@implementation X8275
{
	// -------------------------------------------------------------------------
	// Регистры i8275
	// -------------------------------------------------------------------------

	union i8275_status		// Регистр статуса
	{
		uint8_t byte; struct
		{
			unsigned FO:1;	// FO (FIFO Overrun)
			unsigned DU:1;	// DU (DMA Underrun)
			unsigned VE:1;	// VE (Video Enable)
			unsigned IC:1;	// IC (Improper Command)
			unsigned LP:1;	// LP (Light pen)
			unsigned IR:1;	// IR (Interrupt Request)
			unsigned IE:1;	// IE (Interrupt Enable)
			unsigned   :1;
		};

	} status;

	union i8275_config		// Конфигурация дисплея
	{
		uint8_t byte[4]; struct
		{
			unsigned H:7;	// Horizontal Characters/Row (1-80)
			unsigned S:1;	// Spaced Row (0-normal, 1-spaced)
			unsigned R:6;	// Vertical Rows/Frame (1-64)
			unsigned V:2;	// Vertical Retrace Row Count (1-4)
			unsigned L:4;	// Number of Lines per Character Row (1-16)
			unsigned U:4;	// Underline Placement (1-16)
			unsigned Z:4;	// Horizontal Retrace Count (2-32)
			unsigned C:2;	// Cursor Format
			unsigned F:1;	// Field Attribute Mode (0-Transparent)
			unsigned M:1;	// Line Counter Mode (offset)
		};

		uint32_t value;

	} config;

	union i8275_cursor		// Положение курсора и светового пера
	{
		uint8_t byte[2]; struct
		{
			unsigned COL:7;
			unsigned    :1;
			unsigned ROW:6;
			unsigned    :2;
		};

		uint16_t value;

	} cursor, light_pen;

	union i8275_mode		// Конфигурация DMA
	{
		uint8_t byte; struct
		{
			unsigned B:2;	// Число циклов ПДП в течение одного сеанса
			unsigned S:3;	// Число тактов между запросами ПДП
			unsigned  :3;
		};

	} mode;

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
	// Буфера строки и FIFO
	// -------------------------------------------------------------------------

	uint8_t buffer[80], bpos;
	uint8_t fifo[16], fpos;

	// -------------------------------------------------------------------------
	// Буфера экранов
	// -------------------------------------------------------------------------

	union i8275_char
	{
		uint32_t value;

		struct
		{
			unsigned  H:1;	// highlight
			unsigned  B:1;	// blink (vsp)
			unsigned G0:1;	// general purpose 0
			unsigned G1:1;	// general purpose 1
			unsigned  R:1;	// reverse
			unsigned  U:1;	// underline (lten)
			unsigned   :2;
		};

		struct
		{
			uint8_t attr;
			uint8_t byte;
			uint16_t vsp;
		};

	} screen[2][64][80];

	// -------------------------------------------------------------------------
	//
	// -------------------------------------------------------------------------

	uint32_t *bitmap[2];

	unsigned frame;

	uint8_t attr;

	unsigned row;

	BOOL EoS;

	// -------------------------------------------------------------------------
	// Внешние настройки
	// -------------------------------------------------------------------------

	NSData *rom;

	uint8_t attrMask, attrShift;
	const uint32_t *colors;
	uint16_t font;

	const uint16_t *fonts;
	const uint8_t *mcpg;
}

// -----------------------------------------------------------------------------
// Character attribute codes
// -----------------------------------------------------------------------------

static struct pseudographics
{
	BOOL LA1, LA0, VSP, LTEN;
}

pseudographics[][3] =
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
// Цвета для МЦПГ
// -----------------------------------------------------------------------------

static uint32_t backround[] =
{
	0xFF000000, 0xFFFF0000, 0xFF000000, 0xFFFF0000,
	0xFF0000FF, 0xFFFF00FF, 0xFF0000FF, 0xFFFF00FF,
	0xFF00FF00, 0xFFFFFF00, 0xFF00FF00, 0xFFFFFF00,
	0x00000000, 0xFFFFFFFF, 0x00000000, 0xFFFFFFFF
};

static uint32_t foreground[] =
{
	0xFFFFFFFF, 0xFFFFFF00,
	0xFFFF00FF, 0xFFFF0000,
	0xFF00FFFF, 0xFF00FF00,
	0xFF0000FF, 0
};

// -----------------------------------------------------------------------------
// Конфигурация эмуляции ВГ75
// -----------------------------------------------------------------------------

@synthesize display;

- (void) setColors:(const uint32_t *)ptr attributesMask:(uint8_t)mask shiftMask:(uint8_t)shift
{
	@synchronized(self)
	{
		colors = ptr; bitmap[0] = bitmap[1] = NULL;
		memset(screen, -1, sizeof(screen));

		attrMask = (mask & 0x3F) | 0x22;
		attrShift = (shift & attrMask) | 0x02;
	}
}

- (void) setFonts:(const uint16_t *)ptr
{
	@synchronized(self)
	{
		fonts = ptr; bitmap[0] = bitmap[1] = NULL;
		memset(screen, -1, sizeof(screen));
	}
}

- (void) setMcpg:(const uint8_t *)ptr
{
	@synchronized(self)
	{
		mcpg = ptr; memset(screen, -1, sizeof(screen));
		bitmap[0] = bitmap[1] = NULL;
	}
}

- (void) selectFont:(unsigned int)offset
{
    @synchronized(self)
    {
        font = offset;
        memset(screen, -1, sizeof(screen));
    }
}

// -----------------------------------------------------------------------------
// Переключение шрифтов для Апогей БК-01
// -----------------------------------------------------------------------------

- (void) INTE:(BOOL)IF clock:(uint64_t)clock
{
	[self selectFont:IF ? 0x2400 : 0x2000];
}

// -----------------------------------------------------------------------------
// Чтение/запись регистров ВГ75
// -----------------------------------------------------------------------------

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	@synchronized(self)
	{
		if ((addr & 1) == 1)
		{
			*data = status.byte;

			status.IR = NO;

			status.IC = 0;
			status.DU = 0;
			status.FO = 0;
		}
		else
		{
			if ((cmd & 0xE0) == 0x60 && len < 2)
			{
				*data = light_pen.byte[len++];
			}
			else
			{
				status.IC = 1;
				*data = 0x00;
			}
		}
	}
}

// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
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
					status.IR = NO;

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
						row = 0; rowTimer = clock + rowClock + 24 - clock % 12;
						rowTimer += rowClock * (config.R + config.V + 2) * 2;
						dmaTimer = -1; bpos = 0;

						bitmap[0] = [self.display setupTextWidth:config.H + 1
														  height:config.R + 1
															  cx:6
															  cy:config.L + 1
													  textScreen:self];

						memset(screen, -1, sizeof(screen));
						bitmap[1] = NULL;

						[self.display draw:YES];
					}

					break;
				}
			}
		}

		else if ((cmd & 0xE0) == 0x00 && len < 4)
		{
			cfg.byte[len++] = data; if (len == 4 && config.value != cfg.value)
			{
				config = cfg; memset(screen, -1, sizeof(screen)); bitmap[0] = bitmap[1] = NULL;
				rowClock = (config.H + 1 + ((config.Z + 1) << 1)) * (config.L + 1) * 12;
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

// -----------------------------------------------------------------------------
// Переодические вызовы из модуля CPU
// -----------------------------------------------------------------------------

- (unsigned) HLDA:(uint64_t)clock clk:(unsigned int)clk
{
	if (rowClock) @synchronized(self)
	{
		if (rowTimer <= clock)
		{
			if (++row >= config.R + config.V + 2)
			{
				[self.display draw:frame++ & 1 || colors == NULL];
				row = 0; attr = 0x00; EoS = NO;
			}

			if (row <= config.R)
			{
				BOOL page = colors && frame & 1;

				if (bpos != config.H + 1)
				{
					status.DU = 1;
					dmaTimer = -2;
					EoS = YES;
				}

				if (row == config.R && status.IE)
				{
					self.cpu.IRQ = 0;
					status.IR = YES;
				}

                union i8275_char ch2;
                ch2.value = 0;
                
				BOOL EoR = NO;

				for (uint8_t col = 0, f = 0; col < config.H + 2; col++)
				{
					union i8275_char ch = ch2;
					ch2.value = 0;

					if (col <= config.H && status.VE && !EoS && !EoR)
					{

						if (((ch2.byte = buffer[col]) & 0x80) == 0x00)		// 0xxxxxxx
						{
							ch.attr |= attr & ~attrShift;
							ch2.attr = attr & attrShift;

							if (ch2.B && (frame & 0x10) == 0x00)
								ch2.vsp = -1;

							else if (config.U & 0x08)
								ch2.vsp = (1 << config.L) | 1;

						}

						else if ((ch2.byte & 0xC0) == 0x80)					// 10xxxxxx
						{
							attr = ch2.byte & attrMask;

							if (config.F == 0)
							{
								ch2.byte = fifo[f++ & 0x0F];

								ch.attr |= attr & ~attrShift;
								ch2.attr = attr & attrShift;

								if (ch2.B && (frame & 0x10) == 0x00)
									ch2.vsp = -1;

								if (config.U & 0x08)
									ch2.vsp = (1 << config.L) | 1;
							}
							else
							{
								ch.attr |= attr & 0x0D & ~attrShift;
								ch2.attr = attr & 0x0D & attrShift;

								ch2.vsp = -1;
							}
						}

						else if ((ch2.byte & 0xF0) == 0xF0)					// 1111xxxx
						{
							if (ch2.byte & 0x02)
								EoS = YES;
							else
								EoR = YES;

							ch2.vsp = -1;
						}

						else												// 11xxxxxx
						{
							ch.attr |= ((attr & ~0x03) | (ch2.byte & attrMask & 0x03)) & ~attrShift;
							ch2.attr = ((attr & ~0x03) | (ch2.byte & attrMask & 0x03)) & attrShift;

							struct pseudographics *p = pseudographics[(ch2.byte >> 2) & 0x0F];

							if (p[1].LTEN)
							{
								if (attrShift & 0x20)
									ch2.U = 1;
								else
									ch.U = 1;
							}

							if (ch2.B && (frame & 0x10) == 0x00)
								ch2.vsp = -1;

							if (p[2].VSP)
								ch2.vsp |= -1 << (config.U + 1);

							if (p[0].VSP)
								ch2.vsp |= (1 << config.U) - 1;
						}
					}
					else
					{
						ch2.vsp = -1;
					}

					if (status.VE && row == cursor.ROW && col == cursor.COL)
					{
						switch (config.C)
						{
							case 0:

								if (attrMask & 0x10 && frame & 0x08)
								{
									if (attrShift & 0x10)
										ch2.R ^= 1;
									else
										ch.R ^= 1;
								}

								break;

							case 1:

								if (frame & 0x08)
								{
									if (attrShift & 0x20)
										ch2.U = 1;
									else
										ch.U = 1;
								}

								break;

							case 2:

								if (attrMask & 0x10)
								{
									if (attrShift & 0x10)
										ch2.R ^= 1;
									else
										ch.R ^= 1;
								}

								break;

							case 3:

								if (attrShift & 0x20)
									ch2.U = 1;
								else
									ch.U = 1;

								break;
						}
					}

					if (col && screen[page][row][col-1].value != ch.value)
					{
						screen[page][row][col-1].value = ch.value;

						if (bitmap[page] == NULL)
						{
							if (page == 0)
							{
								bitmap[0] = [self.display setupTextWidth:config.H + 1
																  height:config.R + 1
																	  cx:6
																	  cy:config.L + 1
															  textScreen:self];

								bitmap[1] = NULL;
							}
							else
							{
								bitmap[1] = [self.display setupOverlayWidth:(config.H + 1) * 6
																	 height:(config.R + 1) * (config.L + 1)];
							}
						}

						uint32_t b0 = /*colors ? colors[0x0F & attrMask] :*/ /*fonts == NULL && ch.H ? 0xFF555555 :*/ 0xFF000000;
						uint32_t b1 = colors ? colors[ch.attr & 0x0F] : fonts == NULL && ch.H ? 0xFFFFFFFF : 0xFFAAAAAA;

						if (page)
						{
							b0 &= 0x7FFFFFFF;
							b1 &= 0x7FFFFFFF;
						}

						const uint8_t *fnt = rom.bytes + (fonts ? fonts[ch.attr & 0x0F]: font) + ((ch.byte & 0x7F) << 3);
						uint32_t *ptr = bitmap[page] + (row * (config.L + 1) * (config.H + 1) + col - 1) * 6;

						uint16_t mask = 1; for (unsigned L = 0; L <= config.L; L++, mask <<= 1)
						{
							uint8_t byte = ch.U && L == config.U ? 0xFF : ch.vsp & mask ? 0x00 : fnt[(config.M ? (L ? L - 1 : config.L) : L) & 7];

							if (ch.R)
								byte ^= 0xFF;

							for (int i = 0; i < 6; i++, byte <<= 1)
								*ptr ++ = byte & 0x20 ? b1 : b0;

							ptr += config.H * 6;
						}

						if (mcpg)
						{
							if (bitmap[1] == NULL)
								bitmap[1] = [self.display setupOverlayWidth:(config.H + 1) * 4
																	 height:(config.R + 1) * (config.L + 1)];

							uint32_t *ptr = bitmap[1] + (row * (config.L + 1) * (config.H + 1) + col - 1) * 4;
							const uint8_t *fnt = mcpg + (ch.R ? 0x400 : 0x000) + ((ch.byte & 0x7F) << 3);

							uint32_t bg = backround[ch.attr & 0x0D];

							uint16_t mask = 1; for (unsigned L = 0; L <= config.L; L++, mask <<= 1)
							{
								if (ch.vsp & mask || bg == 0)
								{
									*ptr++ = bg;
									*ptr++ = bg;
									*ptr++ = bg;
									*ptr++ = bg;
								}

								else
								{
									uint8_t fnt1 = fnt[0x000 + ((config.M ? (L ? L - 1 : config.L) : L) & 7)] & 0x3F;
									uint8_t fnt2 = fnt[0x800 + ((config.M ? (L ? L - 1 : config.L) : L) & 7)] & 0x3F;

									if (ch.U && L == config.U)
									{
										fnt1 ^= 0x3F;
										fnt2 ^= 0x3F;
									}

									uint32_t c1 = foreground[fnt1 >> 3];
									*ptr++ = c1 ? c1 : bg;

									uint32_t c2 = foreground[fnt1 & 0x07];
									*ptr++ = c2 ? c2 : bg;

									uint32_t c3 = foreground[fnt2 >> 3];
									*ptr++ = c3 ? c3 : bg;

									uint32_t c4 = foreground[fnt2 & 0x07];
									*ptr++ = c4 ? c4 : bg;
								}
								
								ptr += config.H * 4;
							}
						}
					}
				}
			}

			if (dmaTimer != -2 || row == config.R + config.V + 1)
			{
				if (status.VE && (row < config.R || row == config.R + config.V + 1))
				{
					dmaTimer = rowTimer; bpos = 0; fpos = 0;
					memset(buffer, 0, sizeof(buffer));
				}
				else
				{
					dmaTimer = -1;
				}
			}

			rowTimer += rowClock;
		}
	}

	return 0;
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

- (uint64_t *) DRQ
{
	return &dmaTimer;
}

- (void) RD:(uint8_t *)data clock:(uint64_t)clock
{

}

- (void)WR:(uint8_t)data clock:(uint64_t)clock
{
	dmaTimer = bpos == config.H ? -1 : (bpos + fpos + 1) % (1 << mode.B) ? 0 : clock + (mode.S ? mode.S << 3 : 1) * 12 - clock % 12;

	if((buffer[bpos] & 0xF1) == 0xF1)
	{
		dmaTimer = buffer[bpos] & 0x02 ? -2 : -1;
		bpos = config.H + 1;
	}
	else if((buffer[bpos] & 0xC0) == 0x80 && config.F == 0)
	{
		fifo[fpos++ & 0x0F] = data & 0x7F;
		if(fpos == 17) status.FO = 1;
		bpos++;
	}
	else if(((buffer[bpos] = data) & 0xC0) != 0x80 || config.F != 0)
	{
		if((buffer[bpos] & 0xF1) == 0xF1)
		{
			if(dmaTimer)
			{
				dmaTimer = buffer[bpos] & 0x02 ? -2 : -1;
				bpos = config.H + 1;
			}
		}
		else
		{
			bpos++;
		}
	}
}

// -----------------------------------------------------------------------------
// Copy to pasteboard
// -----------------------------------------------------------------------------

- (unichar)unicharAtX:(unsigned)x Y:(unsigned)y
{
	NSString *unicode = nil; if (fonts)
	{
		font = fonts[screen[0][y][x].attr & 0x0F];
		if (mcpg && font != 0x0C00) return ' ';
	}

	switch (font)
	{
		case 0x0000:	// Партнер (английский алфавит)
		{
			unicode = @"                                "
			" !\"#$%&'()*+,-./0123456789:;<=>?"
			"@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
			"`abcdefghijklmnopqrstuvwxyz{|}~ "
			;

			break;
		}

		case 0x0400:	// Партнер (русский с графикой)
		{
			unicode = @"                                                "
			@"АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
			@"абвгдежзийклмнопрстуфхцчшщъыьэюя"
			@"Ёё";

			break;
		}

		case 0x0C00:	// РК (Микроша, Партнер) основной
		{
			unicode =
			@" ▘▝▀▗▚▐▜ ⌘ ⬆  ➡⬇▖▌▞▛▄▙▟█   ┃━⬅☼ "
			" !\"#$%&'()*+,-./0123456789:;<=>?"
			"@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
			"ЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧ▇";

			break;
		}

		case 0x2000:	// Апогей основной
		{
			unicode =
			@" ▘▝▀▗▚▐▜ ⌘ ⬆  ➡⬇▖▌▞▛▄▙▟█   ┃━⬅☼ "
			" !\"#$%&'()*+,-./0123456789:;<=>?"
			"@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
			"ЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧ░";

			break;
		}

		case 0x2800:	// Микроша дополнительный
		{
			unicode =
			@"                                "
			" !\"#$%&'()*+,-./0123456789:;<=>?"
			"юабцдефгхийклмнопярстужвьызшэщч▇"
			"ЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧ▇";

			break;
		}
	}

	return unicode && screen[0][y][x].byte < unicode.length ? [unicode characterAtIndex:screen[0][y][x].byte] : ' ';
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
		if ((rom = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SYMGEN" ofType:@"BIN"]]) == nil)
			return self = nil;

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:status.byte forKey:@"status"];
	[encoder encodeInt32:config.value forKey:@"config"];
	[encoder encodeInt:cursor.value forKey:@"cursor"];
	[encoder encodeInt:mode.byte forKey:@"mode"];

	[encoder encodeInt:font forKey:@"font"];

	[encoder encodeInt64:rowTimer forKey:@"rowTimer"];
	[encoder encodeInt64:rowClock forKey:@"rowClock"];
	[encoder encodeInt64:dmaTimer forKey:@"dmaTimer"];

	[encoder encodeInt32:cfg.value forKey:@"cfg"];
	[encoder encodeInt:cmd forKey:@"cmd"];
	[encoder encodeInt:len forKey:@"len"];

	[encoder encodeInt:row forKey:@"row"];
	[encoder encodeInt:bpos forKey:@"bpos"];
	[encoder encodeInt:fpos forKey:@"fpos"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super init])
	{
		if ((rom = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SYMGEN" ofType:@"BIN"]]) == nil)
			return self = nil;

		status.byte = [decoder decodeIntForKey:@"status"];
		config.value = [decoder decodeInt32ForKey:@"config"];
		cursor.value = [decoder decodeIntForKey:@"cursor"];
		mode.byte = [decoder decodeIntForKey:@"mode"];

		font = [decoder decodeIntForKey:@"font"];

		rowTimer = [decoder decodeInt64ForKey:@"rowTimer"];
		rowClock = [decoder decodeInt64ForKey:@"rowClock"];
		dmaTimer = [decoder decodeInt64ForKey:@"dmaTimer"];

		cfg.value = [decoder decodeInt32ForKey:@"cfg"];
		cmd = [decoder decodeIntForKey:@"cmd"];
		len = [decoder decodeIntForKey:@"len"];

		row = [decoder decodeIntForKey:@"row"];
		bpos = [decoder decodeIntForKey:@"bpos"];
		fpos = [decoder decodeIntForKey:@"fpos"];
	}

	return self;
}

// -----------------------------------------------------------------------------
// DEBUG: dealloc
// -----------------------------------------------------------------------------

#ifndef NDEBUG
- (void) dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
