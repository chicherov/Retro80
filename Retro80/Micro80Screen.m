/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 Контроллер дисплея ПЭВМ «Микро-80»

 *****/

#import "Micro80Screen.h"

@implementation Micro80Screen
{
	NSMutableData *buffer;
	NSData *rom;

	uint8_t screen[32 * 64];
	uint32_t* bitmap;
}

@synthesize display;
@synthesize ram;

// -----------------------------------------------------------------------------
// RD/WR
// -----------------------------------------------------------------------------

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	if (addr & 0x800)
		mutableBytes[addr & 0x7FF] = (mutableBytes[addr & 0x7FF] & 0x80) | (data & 0x7F);
	else
		mutableBytes[addr & 0x7FF] = (mutableBytes[addr & 0x7FF] & 0x7F) | (data & 0x80);
    
    [ram WR:addr data:data CLK:clock];
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	*data = mutableBytes[addr & 0x7FF] & 0x7F;
}

// -----------------------------------------------------------------------------
// draw
// -----------------------------------------------------------------------------

- (void) draw
{
	if (bitmap == NULL)
		bitmap = [self.display setupTextWidth:64 height:32 cx:6 cy:8];

	if (bitmap)
	{
		for (NSUInteger i = 0; i < 2048; i++)
		{
			uint8_t ch = (mutableBytes[i] & 0x7F) | (mutableBytes[(i + 1) & 0x7FF] & 0x80);

			if (screen[i] != ch)
			{
				screen[i] = ch;

				uint32_t *ptr = bitmap + (((i & ~63) << 3) | (i & 63)) * 6;
				const uint8_t *fnt = rom.bytes + ((ch & 0x7F) << 3);

				for (int line = 0; line < 8; line++)
				{
					uint8_t byte = *fnt++; if (ch & 0x80) byte ^= 0xFF;

					for (int i = 0; i < 6; i++, byte <<= 1)
						*ptr++ = byte & 0x20 ? 0xFF000000 : 0xFFAAAAAA;

					ptr += 63 * 6;
				}
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
	NSString *unicode = @
	" ▘▝▀▗▚▐▜ ⌘ ⬆  ➡⬇▖▌▞▛▄▙▟█   ┃━⬅☼ "
	" !\"#$%&'()*+,-./0123456789:;<=>?"
	"@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
	"ЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧ▇";


	return [unicode characterAtIndex:screen[y * 64 + x] & 0x7F];
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		if ((rom = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Micro80" ofType:@"fnt"]]) == nil)
			return self = nil;

		if ((buffer = [NSMutableData dataWithLength:2048]) == nil)
			return self = nil;

		mutableBytes = buffer.mutableBytes;
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:buffer forKey:@"buffer"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super init])
	{
		if ((rom = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Micro80" ofType:@"fnt"]]) == nil)
			return self = nil;

		if ((buffer = [decoder decodeObjectForKey:@"buffer"]) == nil)
			return self = nil;

		mutableBytes = buffer.mutableBytes;
	}
	
	return self;
}

@end
