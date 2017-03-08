/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Контроллер дисплея ПЭВМ «Микро-80»

 *****/

#import "Micro80Screen.h"

@implementation Micro80Screen
{
    uint8_t screen[32 * 64];
    uint32_t* bitmap;
}

@synthesize display;
@synthesize font;

// -----------------------------------------------------------------------------
// Подключение фоновой памяти
// -----------------------------------------------------------------------------

- (void) setMem:(MEM *)mem
{
    pMutableBytes = mem->pMutableBytes;
    pLength = mem->pLength;
    offset = mem->offset;
    mask = mem->mask;
}

// -----------------------------------------------------------------------------
// RD/WR/BYTE
// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
    if (addr & 0x800)
        mutableBytes[addr & 0x7FF] = (mutableBytes[addr & 0x7FF] & 0x80) | (data & 0x7F);
    else
        mutableBytes[addr & 0x7FF] = (mutableBytes[addr & 0x7FF] & 0x7F) | (data & 0x80);

    if (*pMutableBytes != mutableBytes && offset + (addr & mask) < *pLength)
        (*pMutableBytes) [offset + (addr & mask)] = data;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	*data = mutableBytes[addr & 0x7FF] & 0x7F;
}

- (uint8_t *) BYTE:(uint16_t)addr
{
    return mutableBytes + (addr & 0x7FF);
}

// -----------------------------------------------------------------------------
// draw
// -----------------------------------------------------------------------------

- (void) draw
{
	if (bitmap || (bitmap = [self.display setupTextWidth:64 height:32 cx:6 cy:8]))
	{
		for (NSUInteger i = 0; i < 2048; i++)
		{
			uint8_t ch = (mutableBytes[i] & 0x7F) | (mutableBytes[(i + 1) & 0x7FF] & 0x80);

			if (screen[i] != ch)
			{
                uint32_t *ptr = bitmap + (((i & ~63) << 3) | (i & 63)) * 6;
                const uint8_t *fnt = font.bytes + ((ch & 0x7F) << 3);

				for (int line = 0; line < 8; line++)
				{
					uint8_t byte = *fnt++; if (ch & 0x80)
                    {
                        *ptr++ = byte & 0x20 ? 0xFFAAAAAA : 0xFF000000;
                        *ptr++ = byte & 0x10 ? 0xFFAAAAAA : 0xFF000000;
                        *ptr++ = byte & 0x08 ? 0xFFAAAAAA : 0xFF000000;
                        *ptr++ = byte & 0x04 ? 0xFFAAAAAA : 0xFF000000;
                        *ptr++ = byte & 0x02 ? 0xFFAAAAAA : 0xFF000000;
                        *ptr++ = byte & 0x01 ? 0xFFAAAAAA : 0xFF000000;
                    }
                    else
                    {
                        *ptr++ = byte & 0x20 ? 0xFF000000 : 0xFFAAAAAA;
                        *ptr++ = byte & 0x10 ? 0xFF000000 : 0xFFAAAAAA;
                        *ptr++ = byte & 0x08 ? 0xFF000000 : 0xFFAAAAAA;
                        *ptr++ = byte & 0x04 ? 0xFF000000 : 0xFFAAAAAA;
                        *ptr++ = byte & 0x02 ? 0xFF000000 : 0xFFAAAAAA;
                        *ptr++ = byte & 0x01 ? 0xFF000000 : 0xFFAAAAAA;
                    }
                    
					ptr += 63 * 6;
				}
                
                screen[i] = ch;
			}
		}

		self.display.needsDisplay = TRUE;
	}
}

// -----------------------------------------------------------------------------
// Copy to pasteboard
// -----------------------------------------------------------------------------

- (unichar) charAtX:(unsigned int)x Y:(unsigned int)y
{
	NSString *unicode = @" ▘▝▀▗▚▐▜ ⌘ ⬆  ➡⬇▖▌▞▛▄▙▟█   ┃━⬅☼  !\"#$%&'()*+,-./0123456789:;<=>?"
	"@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_ЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧ▇";

    return [unicode characterAtIndex:screen[y * 64 + x] & 0x7F];
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super initWithLength:2048 mask:0x07FF])
	{
		if ((font = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Micro80" ofType:@"fnt"]]) == nil)
			return self = nil;
        
        memset(mutableBytes, 0x80, length);
	}

	return self;
}

// -----------------------------------------------------------------------------
// initWithCoder
// -----------------------------------------------------------------------------

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		if ((font = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Micro80" ofType:@"fnt"]]) == nil)
			return self = nil;
	}
	
	return self;
}

@end
