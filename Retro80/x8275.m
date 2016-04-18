/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Контроллер отображения видеоинформации КР580ВГ75 (8275)

 *****/

#import "X8275.h"

@implementation X8275
{
	uint32_t *bitmap[2];
	unsigned frame;

	union i8275_config cfg;	// Новая конфигурация
	unsigned cmd:8;			// Последняя команда
	unsigned len:8;			// Данные команды

	// -------------------------------------------------------------------------
	// Тайминги ROW и DMA
	// -------------------------------------------------------------------------

	uint64_t rowClock;
	uint64_t rowTimer;
	uint64_t dmaTimer;

	BOOL IRQ;

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

	NSData *rom; const uint8_t *bytes;
	const uint16_t *fonts;
	const uint8_t *mcpg;
	uint16_t font;

	const uint32_t *colors;
	uint8_t attributesMask;
	uint8_t shiftMask;
}

@synthesize display;

- (BOOL) IRQ:(uint64_t)clock
{
	if (IRQ)
	{
		IRQ = FALSE;
		return TRUE;
	}

	return FALSE;
}

// -----------------------------------------------------------------------------

- (void) setColors:(const uint32_t *)ptr attributesMask:(uint8_t)mask shiftMask:(uint8_t)shift
{
	@synchronized(self)
	{
		colors = ptr; memset(screen, -1, sizeof(screen));
		attributesMask = mask; shiftMask = shift;
		fonts = NULL; mcpg = NULL;

		bitmap[0] = NULL;
		bitmap[1] = NULL;
	}
}

// -----------------------------------------------------------------------------

- (void) setFonts:(const uint16 *)ptr
{
	@synchronized(self)
	{
		fonts = ptr; memset(screen, -1, sizeof(screen));

		bitmap[0] = NULL;
		bitmap[1] = NULL;
	}
}

// -----------------------------------------------------------------------------

- (void) setMcpg:(const uint8_t *)ptr;
{
	@synchronized(self)
	{
		mcpg = ptr; memset(screen, -1, sizeof(screen));

		bitmap[0] = NULL;
		bitmap[1] = NULL;
	}
}

// -----------------------------------------------------------------------------

- (void) selectFont:(unsigned int)offset
{
	font = offset; memset(screen, -1, sizeof(screen));
}

- (void) INTE:(BOOL)IF clock:(uint64_t)clock
{
	[self selectFont:IF ? 0x2400 : 0x2000];
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
	{{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}},	// 1011

	{{0, 0, 1, 0}, {0, 0, 1, 0}, {0, 0, 1, 0}}	// 1100
};

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

			IRQ = status.IR = FALSE;

			status.IC = 0;
			status.DU = 0;
			status.FO = 0;

			if (!rightMouse)
				status.LP = 0;
		}
		else
		{
			if ((cmd & 0xE0) == 0x60 && len < 2)
			{
				*data = lightPen.byte[len++];
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
					IRQ = status.IR = FALSE;

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
						config = cfg; memset(screen, -1, sizeof(screen)); bitmap[0] = bitmap[1] = NULL;
						rowClock = (config.H + 1 + ((config.Z + 1) << 1)) * (config.L + 1) * 12;
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

- (unsigned) HLDA:(uint64_t)clock
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

					if (frame++ & 1 || colors == NULL)
						self.display.needsDisplay = TRUE;
				}

				if (row <= config.R)
				{
					BOOL page = colors && frame & 1;
					
					if (pos != config.H + 1)
					{
						status.DU = 1;
						dmaTimer = -2;
						EoS = TRUE;
					}

					if (row == config.R && status.IE)
						IRQ = status.IR = TRUE;
					else
						IRQ = FALSE;

						EoR = FALSE; for (uint8_t col = 0, f = 0; col <= config.H; col++)
					{
						union i8275_char ch; if (status.VE && !EoS && !EoR)
						{
							if (((ch.byte = buffer[col]) & 0x80) == 0x00)	// 0xxxxxxx
							{
								ch.attr = attr;
							}

							else if ((ch.byte & 0xC0) == 0x80)			// 10xxxxxx
							{
								ch.attr = attr = ch.byte; if (config.F == 0)
								{
									ch.byte = fifo[f++ & 0x0F];
								}
								else
								{
									ch.attr &= shiftMask;
									ch.byte = 0xF0;
								}
							}

							else if ((ch.byte & 0xF0) == 0xF0)			// 1111xxxx
							{
								if (ch.byte & 0x02)
									EoS = TRUE;
								else
									EoR = TRUE;

								ch.byte = 0xF0;
								ch.attr = 0x00;
							}

							else										// 11xxxxxx
							{
								ch.attr = ch.byte & 0x83;
							}
							
						}
						else
						{
							ch.byte = 0xF0;
							ch.attr = 0x00;
						}

						if (status.VE && row == cursor.ROW && col + ((shiftMask & (config.C & 1 ? 0x20 : 0x10)) != 0) == cursor.COL)
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

						if (screen[page][row][col].word != ch.word)
						{
							if (bitmap[page] == NULL)
							{
								if (page == 0)
								{
									bitmap[0] = [self.display setupTextWidth:config.H + 1
																	  height:config.R + 1
																		  cx:6
																		  cy:config.L + 1];

									bitmap[1] = NULL;
								}
								else
								{
									bitmap[1] = [self.display setupOverlayWidth:(config.H + 1) * 6
																   height:(config.R + 1) * (config.L + 1)];
								}
							}

							screen[page][row][col].word = ch.word;

							uint32_t b0 = colors ? colors[0x0F & attributesMask] : fonts == NULL && ch.H ? 0xFF555555 : 0xFF000000;
							uint32_t b1 = colors ? colors[ch.attr & 0x0F] : fonts == NULL && ch.H ? 0xFFFFFFFF : 0xFFAAAAAA;

							if (page)
							{
								b0 &= 0x7FFFFFFF;
								b1 &= 0x7FFFFFFF;
							}

							const unsigned char *fnt = bytes + (fonts ? fonts[ch.attr & 0x0F]: font) + ((ch.byte & 0x7F) << 3);
							uint32_t *ptr = bitmap[page] + (row * (config.L + 1) * (config.H + 1) + col) * 6;

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

									// byte = special->LA1 ? (special->LA0 ? 0x3C : 0x07) : (special->LA0 ? 0x04 : 0x00);

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

							if (mcpg)
							{
								if (bitmap[1] == NULL)
								{
									bitmap[1] = [self.display setupOverlayWidth:(config.H + 1) * 4
																		 height:(config.R + 1) * (config.L + 1)];
								}

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
									0xFF0000FF, 0xFF000000
								};

								const unsigned char *fnt = mcpg + (ch.R ? 0x400 : 0x000) + ((ch.byte & 0x7F) << 3);
								uint32_t *ptr = bitmap[1] + (row * (config.L + 1) * (config.H + 1) + col) * 4;

								foreground[7] = backround[ch.attr & 0x0F];

								for (unsigned L = 0; L <= config.L; L++)
								{
									uint8_t fnt1 = fnt[0x000 + ((config.M ? (L ? L - 1 : config.L) : L) & 7)];
									uint8_t fnt2 = fnt[0x800 + ((config.M ? (L ? L - 1 : config.L) : L) & 7)];

									if ((ch.byte & 0x80) == 0x00)
									{
										if (config.U & 0x08 && (L == 0 || L == config.L))
											fnt1 = fnt2 = 0xFF;
									}
									else
									{
										struct special *special = &CCCC[(ch.byte >> 2) & 0x0F][L > config.U ? 2 : L == config.U];

										if (special->VSP)
											fnt1 = fnt2 = 0xFF;

										if (special->LTEN)
											fnt1 = fnt2 = 0x00;
									}

									if (L == config.U && ch.U)
									{
										fnt1 ^= 0x3F;
										fnt2 ^= 0x3F;
									}

									*ptr++ = foreground[7] ? foreground [(fnt1 & 0x38) >> 3] : 0;
									*ptr++ = foreground[7] ? foreground [fnt1 & 0x07] : 0;
									*ptr++ = foreground[7] ? foreground [(fnt2 & 0x38) >> 3] : 0;
									*ptr++ = foreground[7] ? foreground [fnt2 & 0x07] : 0;
									
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
						dmaTimer = rowTimer + (mode.S ? (mode.S << 3) - 1 : 0) * 12;
						memset(buffer, 0, sizeof(buffer)); pos = 0; fpos = 0;
					}
					else
					{
						dmaTimer = -1;
					}
				}

				rowTimer += rowClock;
			}
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

- (void) WR:(uint8_t)data clock:(uint64_t)clock
{
	BOOL burst = pos != config.H && (pos + 1) % (1 << mode.B);

	if ((buffer[pos] & 0xC0) == 0x80 &&  config.F == 0)
	{
		fifo[fpos++ & 0x0F] = data & 0x7F;
		if (fpos == 17) status.FO = 1;
	}
	else if ((buffer[pos] & 0xF3) == 0xF1)
	{
		pos = config.H + 1;
		dmaTimer = -1;
		return;
	}

	else if ((buffer[pos] & 0xF3) == 0xF3)
	{
		pos = config.H + 1;
		dmaTimer = -2;
		return;
	}
	else
	{
		buffer[pos] = data; if ((data & 0xC0) == 0x80 && config.F == 0)
		{
			return;
		}

		if ((data & 0xF3) == 0xF1)
		{
			if (!burst)
			{
				pos = config.H + 1;
				dmaTimer = -1;
			}

			return;
		}

		if ((data & 0xF3) == 0xF3)
		{
			if (!burst)
			{
				pos = config.H + 1;
				dmaTimer = -2;
			}

			return;
		}
	}

	pos++; if (!burst)
	{
		if (pos <= config.H)
		{
			dmaTimer = clock + (mode.S ? (mode.S << 3) - 1 : 0) * 12;
			dmaTimer += 12 - (dmaTimer % 12);
		}
		else
		{
			dmaTimer = -1;
		}
	}
}

// -----------------------------------------------------------------------------
// Световое перо
// -----------------------------------------------------------------------------

//- (void) rightMouseDragged:(NSEvent *)theEvent
//{
//	[self rightMouseDown:theEvent];
//}
//
//- (void) rightMouseDown:(NSEvent *)theEvent
//{
//	NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];
//
//	@synchronized(self)
//	{
//		if (status.VE)
//		{
//			lightPen.ROW = trunc(text.height - point.y / self.frame.size.height * text.height);
//			lightPen.COL = trunc(point.x / self.frame.size.width * text.width) + 8;
//			rightMouse = TRUE;
//			status.LP = 1;
//		}
//	}
//}
//
//- (void) rightMouseUp:(NSEvent *)theEvent
//{
//	@synchronized(self)
//	{
//		status.LP = 0;
//	}
//}

// -----------------------------------------------------------------------------
// Copy to pasteboard
// -----------------------------------------------------------------------------

- (unichar) charAtX:(unsigned int)x Y:(unsigned int)y
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
	{
		if ((rom = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SYMGEN" ofType:@"BIN"]]) == nil)
			return self = nil;

		bytes = rom.bytes;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:status.byte forKey:@"status"];
	[encoder encodeBool:IRQ forKey:@"IRQ"];
	[encoder encodeInt32:*(uint32_t *)config.byte forKey:@"config"];
	[encoder encodeInt:*(uint16_t *)cursor.byte forKey:@"cursor"];
	[encoder encodeInt:mode.byte forKey:@"mode"];

	[encoder encodeInt:font forKey:@"font"];

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
	if (self = [super init])
	{
		if ((rom = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SYMGEN" ofType:@"BIN"]]) == nil)
			return self = nil;

		bytes = rom.bytes;

		status.byte = [decoder decodeIntForKey:@"status"];
		IRQ = [decoder decodeBoolForKey:@"IRQ"];
		*(uint32_t *)config.byte = [decoder decodeInt32ForKey:@"config"];
		*(uint16_t *)cursor.byte = [decoder decodeIntForKey:@"cursor"];
		mode.byte = [decoder decodeIntForKey:@"mode"];

		font = [decoder decodeIntForKey:@"font"];

		rowTimer = [decoder decodeInt64ForKey:@"rowTimer"];
		rowClock = [decoder decodeInt64ForKey:@"rowClock"];
		dmaTimer = [decoder decodeInt64ForKey:@"dmaTimer"];

		*(uint32_t *)cfg.byte = [decoder decodeInt32ForKey:@"cfg"];
		cmd = [decoder decodeIntForKey:@"cmd"];
		len = [decoder decodeIntForKey:@"len"];

		row = [decoder decodeIntForKey:@"row"];
		pos = [decoder decodeIntForKey:@"pos"];
	}

	return self;
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
