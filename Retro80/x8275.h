/*******************************************************************************
 Контроллер отображения видеоинформации КР580ВГ75 (8275)
 ******************************************************************************/

#import "Screen.h"
#import "x8080.h"
#import "x8257.h"

// -------------------------------------------------------------------------

@interface X8275 : Screen <ReadWrite, HOLD, NSCoding>
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

	} config;

	union i8275_cursor		// Положение курсора
	{
		uint8_t byte[2]; struct
		{
			unsigned COL:7;
			unsigned    :1;
			unsigned ROW:6;
			unsigned    :2;
		};

	} cursor;

	union i8275_mode		// Конфигурация DMA
	{
		uint8_t byte; struct
		{
			unsigned B:2;	// Число циклов ПДП в течение одного сеанса
			unsigned S:3;	// Число тактов между запросами ПДП
			unsigned  :3;
		};
		
	} mode;
}

- (void) setColors:(const uint32_t *)colors
	 attributeMask:(uint8_t)attributesMask;

- (void) setFontOffset:(unsigned)offset;

@property X8257* dma;

@end
