/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 *****/

#import <Cocoa/Cocoa.h>
#import <QuickLook/QuickLook.h>

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options)
{
	@autoreleasepool
	{
		NSString *ext = [[(__bridge NSURL *)url pathExtension] lowercaseString];

		NSData *data = [NSData dataWithContentsOfURL:(__bridge NSURL *)url];
		const uint8_t *ptr = data.bytes;
		NSUInteger length = data.length;

		if (QLPreviewRequestIsCancelled(preview))
			return noErr;
		
		NSString *unicode = @" ▘▝▀▗▚▐▜ ⌘ ⬆ \n➡⬇▖▌▞▛▄▙▟█   ┃━⬅☼  !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_ЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧ▇";

		NSMutableDictionary *properties = [NSMutableDictionary dictionary];
		NSMutableString *name = [NSMutableString string];

		NSMutableString *out = [NSMutableString string];
		NSMutableString *chr = [NSMutableString string];

		if (([ext isEqualToString:@"gam"] || [ext isEqualToString:@"pki"]) && length && *ptr == 0xE6)
		{
			length--; ptr++;
		}

		if (length >= 4)
		{
			uint addr, last; if (![ext isEqualToString:@"rks"])
			{
				addr = (ptr[0] << 8) | ptr[1];
				last = (ptr[2] << 8) | ptr[3];
				length -= 4; ptr += 4;
			}

			else
			{
				addr = (ptr[1] << 8) | ptr[0];
				last = (ptr[3] << 8) | ptr[2];
				length -= 4; ptr += 4;

				if (addr == 0x8F70 && last == 0x8F82 && length >= 19 && ptr[0x10] == 0xBC)
				{
					NSInteger i = 0; while (i < 16 && ptr[i] && ptr[i] <= 0x7F)
						[name appendFormat:@"%C", [unicode characterAtIndex:ptr[i++]]];

					i = 19; while (i < length && ptr[i] == 0x00) i++;

					if (i + 5 <= length && ptr[i] == 0xE6)
					{
						addr = (ptr[i + 2] << 8) | ptr[i + 1];
						last = (ptr[i + 4] << 8) | ptr[i + 3];
						length -= i + 5; ptr += i + 5;
					}
				}

				else if (addr == 0xD9D9 && (last & 0xFF) == 0xD9)
				{
					if (last >> 8 && (last >> 8) <= 0x7F)
						[name appendFormat:@"%C", [unicode characterAtIndex:last >> 8]];

					NSInteger i = 0; while (i < length && ptr[i] && ptr[i] <= 0x7F)
						[name appendFormat:@"%C", [unicode characterAtIndex:ptr[i++]]];

					while (i < length && ptr[i] == 0x00) i++;

					if (i + 5 <= length && ptr[i] == 0xE6)
					{
						addr = (ptr[i + 2] << 8) | ptr[i + 1];
						last = (ptr[i + 4] << 8) | ptr[i + 3];
						length -= i + 5; ptr += i + 5;
					}
				}
			}

			uint16_t csum1 = 0;
			uint16_t csum2 = 0;
			BOOL even = FALSE;

			if (addr == 0xE6E6 && last == 0xE6E6)					// ED Микрон
			{
				while (length && *ptr && *ptr <= 0x7F)
				{
					[name appendFormat:@"%C", [unicode characterAtIndex:*ptr]];
					ptr++; length--;
				}

				while (length && *ptr == 0x00)
				{
					ptr++; length--;
				}

				if (length >= 3 && *ptr == 0xE6)
				{
					csum1 = (ptr[2] << 8) | ptr[1];
					ptr += 3; length -= 3;

					while (length && *ptr <= 0x7F)
					{
						[out appendFormat:@"%C", [unicode characterAtIndex:*ptr]];
						csum1++; csum2 += *ptr++; length--;
					}

					if (length < 3 || *ptr != 0xFF)
					{
						[name appendString:@" (Ошибка формата файла)"];
					}
					else
					{
						uint16_t csum = (ptr[2] << 8) | ptr[1];
						ptr += 3; length -= 3;

						if (csum != csum2)
							[name appendString:@" (Ошибка контрольной суммы)"];
						else if (++csum1)
							[name appendString:@" (Ошибка длины файла)"];
					}
				}
			}

			else if (addr == 0xD3D3 && ((last & 0xFF00) == 0xD300 || (addr & 0xFF) == 0xD3))	// Basic
			{
				NSMutableArray *basic = [NSMutableArray arrayWithObjects:@"CLS", @"FOR", @"NEXT", @"DATA", @"INPUT", @"DIM", @"READ", @"CUR", @"GOTO", @"RUN", @"IF", @"RESTORE", @"GOSUB", @"RETURN", @"REM", @"STOP", @"OUT", @"ON", @"PLOT", @"LINE", @"POKE", @"PRINT", @"DEF", @"CONT", @"LIST", @"CLEAR", @"MLOAD", @"MSAVE", @"NEW", @"TAB(", @"TO", @"SPC(", @"FN", @"THEN", @"NOT", @"STEP", @"+", @"-", @"*", @"/", @"^", @"AND", @"OR", @">", @"=", @"<", @"SGN", @"INT", @"ABS", @"USR", @"FRE", @"INP", @"POS", @"SQR", @"RND", @"LOG", @"EXP", @"COS", @"SIN", @"TAN", @"ATN", @"PEEK", @"LEN", @"STR$", @"VAL", @"ASC", @"CHR$", @"LEFT$", @"RIGHT$", @"MID$", nil];

				if (last == 0xD3D3)	// Basic Микрон
				{
					[basic addObjectsFromArray:@[@"SCREEN$(", @"INKEY$", @"AT", @"&", @"BEEP", @"PAUSE", @"VERIFY", @"HOME", @"EDIT", @"DELETE", @"MERGE", @"AUTO", @"HIMEM", @"@", @"ASN", @"ADDR", @"PI", @"RENUM", @"ACS", @"LG", @"LPRINT", @"LLIST"]];

					[basic replaceObjectAtIndex:0x1A withObject:@"CLOAD"];
					[basic replaceObjectAtIndex:0x1B withObject:@"CSAVE"];

					if (length && *ptr == '"')
					{
						ptr++; length--;
					}

					while (length && *ptr && *ptr <= 0x7F)
					{
						[name appendFormat:@"%C", [unicode characterAtIndex:*ptr]];
						ptr++; length--;
					}

					while (length && (*ptr == 0x00 || *ptr == 0x55))
					{
						ptr++; length--;
					}

					if (length > 5 && ptr[0] == 0xE6 && ptr[1] == 0xD3 && ptr[2] == 0xD3 && ptr[3] == 0xD3)
					{
						ptr += 5; length -= 5;
					}
				}

				else if (length > 0x36 && ptr[0] == 0xFF && ptr[1] == 0xFF)	// Basic-Best
				{
					ptr += 0x36; length -= 0x36;
				}

				while (length >= 4 && (ptr[0] || ptr[1]))
				{
					[out appendFormat:@"%5d ", (ptr[3] << 8) | ptr[2]];
					csum1 += ptr[0] + ptr[1] + ptr[2] + ptr[3];
					ptr += 4; length -= 4;

					while (length && *ptr)
					{
						if (*ptr <= 0x7F)
							[out appendFormat:@"%C", [unicode characterAtIndex:*ptr]];
						else if (*ptr - 0x80 < basic.count)
							[out appendString:[basic objectAtIndex:*ptr - 0x80]];
						else
							[out appendFormat:@"{%02X}", *ptr];

						csum1 += *ptr++;
						length--;
					}

					if (length)
					{
						[out appendString:@"\n"];
						ptr++; length--;
					}
				}

				if (length >= 4)
				{
					uint16_t csum; csum = (ptr[3] << 8) | ptr[2];

					if (csum == 0x0000 || last == 0xD3D3)
					{
						ptr += 4; length -= 4;

						if (csum && csum != csum1)
							[name appendString:@" (Ошибка контрольной суммы)"];
					}
					else
					{
						ptr += 2; length -= 2;
					}
				}
			}

			else
			{
				if (length == 1024)
				{
					uint16_t csum = 0x0000;

					NSInteger i = 0; while (i < 1024 && ptr[i] <= 0x7F)
						csum += ptr[i++];

					if (((csum >> 8) | ((csum & 0xFF) << 8)) == last)
					{
						[name appendFormat:@"ЭКРАН %d", (addr >> 8) | ((addr & 0xFF) << 8)];

						while (length)
						{
							[out appendFormat:@"%C", [unicode characterAtIndex:*ptr]];
							ptr++; if ((--length % 64) == 0)
								[out appendString:@"\n"];
						}
					}
				}

				if (out.length == 0)
				{
					[out appendFormat:@"Начальный адрес: %04X\n", addr];
					[out appendFormat:@"Конечный  адрес: %04X\n", last];

					if (addr & 0xF)
					{
						[out appendFormat:@"\n%04X: %*c", addr & 0xFFF0, (addr & 0xF) * 3, ' '];
						[chr appendFormat:@"%*c", addr & 0xF, ' '];
					}

					while (length)
					{
						if ((addr & 0xF) == 0)
							[out appendFormat:@"\n%04X: ", addr];

						[out appendFormat:@" %02X", *ptr];

						if (*ptr >= 0x020 && *ptr < 0x7F)
							[chr appendFormat:@"%C", [unicode characterAtIndex:*ptr]];
						else
							[chr appendString:@"."];

						if (!(even = !even))
							csum1 ^= *ptr << 8;
						else
							csum1 ^= *ptr;

						if (addr == last)
							csum2 = (csum2 & 0xFF00) | ((csum2 + *ptr) & 0xFF);
						else
							csum2 += (*ptr << 8) + *ptr;

						ptr++; length--;

						if ((addr & 0x0F) == 0x0F)
						{
							[out appendFormat:@"  %@", chr];
							chr.string = @"";
						}

						if (addr++ == last)
							break;
					}

					if (chr.length)
						[out appendFormat:@"  %*c%@", (0x10 - (addr & 0x0F)) * 3, ' ', chr];

					if (![ext isEqualToString:@"rk8"])
					{
						if ([ext isEqualToString:@"rkm"])
						{
							if (length >= 2)
							{
								uint16_t csum = (ptr[0] << 8) | ptr[1]; ptr += 2; length -= 2;

								if (csum != csum1)
									[out appendFormat:@"\n\nОшибка контрольной суммы: %04X/%04X", csum, csum1];
								else
									[out appendFormat:@"\n\nКонрольная сумма: %04X", csum];
							}
						}
						else if ([ext isEqualToString:@"rks"])
						{
							if (length >= 2)
							{
								uint16_t csum = (ptr[1] << 8) | ptr[0]; ptr += 2; length -= 2;

								if (csum != csum2)
									[out appendFormat:@"\n\nОшибка контрольной суммы: %04X/%04X", csum, csum2];
								else
									[out appendFormat:@"\n\nКонрольная сумма: %04X", csum];
							}
						}
						else if (length >= 3)
						{
							NSUInteger i = 0; while (i < length && ptr[i] == 0x00) i++;
							
							if (length >= i + 3 && ptr[i] == 0xE6)
							{
								uint16_t csum = (ptr[i + 1] << 8) | ptr[i + 2];
								ptr += i + 3; length -= i + 3;
								
								if (csum != csum2)
									[out appendFormat:@"\n\nОшибка контрольной суммы: %04X/%04X", csum, csum2];
								else
									[out appendFormat:@"\n\nКонрольная сумма: %04X", csum];
							}
						}
					}
				}
			}

		}

		if (length)
		{
			[out appendString:@"\n"];
			[chr setString:@""];

			while (length)
			{
				if (chr.length == 0)
					[out appendString:@"\n      "];

				[out appendFormat:@" %02X", *ptr];

				if (*ptr >= 0x020 && *ptr < 0x7F)
					[chr appendFormat:@"%C", [unicode characterAtIndex:*ptr]];
				else
					[chr appendString:@"."];

				ptr++; length--;

				if (chr.length == 16)
				{
					[out appendFormat:@"  %@", chr];
					chr.string = @"";
				}
			}

			if (chr.length)
				[out appendFormat:@"  %*c%@", (0x10 - (int)chr.length) * 3, ' ', chr];
		}

		if (name.length)
			[properties setObject:name forKey:(__bridge NSString *)kQLPreviewPropertyDisplayNameKey];

		NSAttributedString *output = [[NSAttributedString alloc] initWithString:out attributes:@{NSFontAttributeName : [NSFont userFixedPitchFontOfSize: 18.0]}];

		NSData *rtfData = [output RTFFromRange:NSMakeRange(0, output.length) documentAttributes:@{NSDocumentTypeDocumentAttribute: NSRTFTextDocumentType}];

		QLPreviewRequestSetDataRepresentation(preview,
											  (__bridge CFDataRef)rtfData,
											  kUTTypeRTF,
											  (__bridge CFMutableDictionaryRef)properties);

		return noErr;
	}
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview)
{
}
