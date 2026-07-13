/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2026 Andrey Chicherov <andrey@chicherov.ru>

 Отладчик для центрального процессора из класса X8080

 *****/

#include "dasm.h"
#import "Dbg80.h"

@implementation Dbg80
{
	uint8_t breakpoints[0x10000];

	NSString *unicode;
	unichar dbgCmd;

	uint16_t lastL;
	uint16_t lastD;

	uint16_t lastA;
	uint16_t lastM;
}

@synthesize debug;
@synthesize cpu;

- (instancetype)initWithDebug:(Debug *)object
{
	if (self = [super init])
		debug = object;

	return self;
}

+ (instancetype)dbg80WithDebug:(Debug *)debug
{
	return [[self alloc] initWithDebug:debug];
}

- (void)run
{
	[cpu setBreakpoints:breakpoints];

	uint16_t addr = 0x0000;
	do
		breakpoints[addr++] &= ~0x20;
	while (addr);

	if (unicode == nil)
		unicode = koi7();

	if (cpu.BREAK & 0x3000000000)
	{
		[self regs];

		lastD = (cpu.BREAK >> 16) & 0xFFFF;
		lastL = cpu.BREAK & 0xFFFF;
	}

	else if (cpu.BREAK & 0xFFFFFFFF00000000)
	{
		[debug print:@"%c %04X/%04X\n",
				cpu.BREAK & 0x0100000000 ? 'R' :
				cpu.BREAK & 0x0200000000 ? 'W' :
				cpu.BREAK & 0x0400000000 ? 'I' :
				cpu.BREAK & 0x0800000000 ? 'O' :
				cpu.BREAK & 0x1000000000 ? 'X' :
				'?',
				lastD = (cpu.BREAK >> 16) & 0xFFFF,
				lastL = cpu.BREAK & 0xFFFF
		];
	}

	[debug print:@"# "];
	[debug flush];
	dbgCmd = 0;

	[debug run];
}

// -----------------------------------------------------------------------------
// Дизассемблер
// -----------------------------------------------------------------------------

- (void)Dasm:(BOOL)z80
{
    auto [data, source] = dasm(lastL, [self](uint16_t addr) { const uint8_t* ptr = [cpu BYTE:addr]; return ptr ? std::optional<uint8_t>(*ptr) : std::nullopt; }, z80);

    NSString *dumpChr = @"";
    NSString *dumpHex = @"";

    for(auto byte: data)
    {
        dumpHex = byte ? [dumpHex stringByAppendingFormat:@" %02X", *byte] : [dumpHex stringByAppendingString:@" ??"];
        dumpChr = [dumpChr stringByAppendingString:[unicode substringWithRange:NSMakeRange(byte && *byte < unicode.length ? *byte : 0, 1)]];
    }

    dumpHex = [dumpHex stringByPaddingToLength:z80 ? 15 : 9 withString:@" " startingAtIndex:0];
    dumpChr = [dumpChr stringByPaddingToLength:z80 ? 6 : 4 withString:@" " startingAtIndex:0];

    NSString* text = [NSString stringWithCString:source.c_str()];
    NSArray<NSString*>* array = [text componentsSeparatedByString:@" "];

    if(array.count > 1)
        text = [[array.firstObject stringByPaddingToLength:z80 ? 5 : 8 withString:@" " startingAtIndex:0] stringByAppendingString:[[array subarrayWithRange:NSMakeRange(1, array.count - 1)] componentsJoinedByString:@" "]];
    else
        text = array.firstObject;

    [debug print:@"  %04X: %@  %@   %@\n", lastL, dumpHex, dumpChr, text];
    lastL += data.size();
}

// -----------------------------------------------------------------------------
// Служенные методы для отладчика
// -----------------------------------------------------------------------------

static NSString *koi7()
{
	return @".▘▝▀▗▚▐▜........▖▌▞▛▄▙▟█........ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_ЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧ.";
}

static NSString *koi8()
{
	return @".▘▝▀▗▚▐▜........▖▌▞▛▄▙▟█........ !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~.................................................................юабцдефгхийклмнопярстужвьызшэщчъЮАБЦДЕФГХИЙКЛМНОПЯРСТУЖВЬЫЗШЭЩЧЪ";
}

// -----------------------------------------------------------------------------
// word
// -----------------------------------------------------------------------------

- (uint16_t) word:(NSString *)string last:(uint16_t)last
{
	uint16_t result = last; if (string)
	{
		NSScanner *scanner = [NSScanner scannerWithString:string];

		while (scanner.isAtEnd == NO)
		{
			NSString *o = nil; if ([scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"+-"] intoString:&o] ? o.length > 1 || scanner.isAtEnd : scanner.scanLocation != 0)
				@throw @"Недопустимое значение";

			NSString *p = nil; if ([scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"#$'"] intoString:&p] && (p.length > 1 || scanner.isAtEnd))
				@throw @"Недопустимое значение";

			unsigned value; if (p)
			{
				if ([p isEqualToString:@"#"])
				{
					if (![scanner scanInt:(int *)&value] || (value > 0xFFFF && (value | 0x7FFF) != -1))
						@throw @"Недопустимое значение";
				}

				else if ([p isEqualToString:@"$"])
				{
					NSString *r = nil; if (![scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"+-"] intoString:&r])
						@throw @"Недопустимое значение";

					if ([r = r.lowercaseString isEqualToString:@"a"])
						value = cpu.A;
					else if ([r isEqualToString:@"b"])
						value = cpu.B;
					else if ([r isEqualToString:@"c"])
						value = cpu.C;
					else if ([r isEqualToString:@"d"])
						value = cpu.D;
					else if ([r isEqualToString:@"e"])
						value = cpu.E;
					else if ([r isEqualToString:@"h"])
						value = cpu.D;
					else if ([r isEqualToString:@"l"])
						value = cpu.E;
					else if ([r isEqualToString:@"af"])
						value = cpu.AF;
					else if ([r isEqualToString:@"bc"])
						value = cpu.BC;
					else if ([r isEqualToString:@"de"])
						value = cpu.DE;
					else if ([r isEqualToString:@"hl"])
						value = cpu.HL;
					else if ([r isEqualToString:@"pc"])
						value = cpu.PC;
					else if ([r isEqualToString:@"sp"])
						value = cpu.SP;
					else if ([r isEqualToString:@"ix"])
						value = cpu.IX;
					else if ([r isEqualToString:@"iy"])
						value = cpu.IY;
					else
						@throw @"Недопустимое значение";
				}

				else
				{
					NSString *s = nil; if (![scanner scanUpToString:@"'" intoString:&s] || s.length > 2 || ![scanner scanString:@"'" intoString:NULL])
						@throw @"Недопустимое значение";

					NSRange range; if ((range = [unicode rangeOfString:[s substringToIndex:1]]).location == NSNotFound)
						@throw @"Недопустимое значение";

					value = range.location & 0xFF;

					if (s.length == 2)
					{
						if ((range = [unicode rangeOfString:[s substringFromIndex:1]]).location == NSNotFound)
							@throw @"Недопустимое значение";

						value |= (range.location & 0xFF) << 8;
					}
				}
			}

			else if ([scanner scanString:@"^" intoString:NULL])
			{
				int offset = 0; while ([scanner scanString:@"^" intoString:NULL]) offset += 2;
				const uint8_t *ptr = [cpu BYTE:cpu.SP + offset]; value = ptr ? *ptr : 0;
				value |= ((ptr = [cpu BYTE:cpu.SP + offset + 1]) ? *ptr : 0) << 8;
			}

			else
			{
				if (![scanner scanHexInt:&value] || value > 0xFFFF)
					@throw @"Недопустимое значение";
			}

			if (o)
			{
				if ([o isEqualToString:@"+"])
					result += value;
				else
					result -= value;
			}
			else
			{
				result = value;
			}
		}
		
	}

	return result;
}

// -----------------------------------------------------------------------------
// byte
// -----------------------------------------------------------------------------

- (uint16_t) byte:(NSString *)string
{
	uint16_t value = [self word:string last:0x00];

	if (value > 0xFF && value < 0xFF80)
		@throw @"Недопустимое значение";

	return value;
}

// -----------------------------------------------------------------------------
// Текущие регистры процессора
// -----------------------------------------------------------------------------

- (void) regs
{
	if (cpu.Z80)
		[debug print:@"  A=%02X   BC=%04X DE=%04X HL=%04X SP=%04X  IX=%04X IY=%04X  F=%02X (%c%c%c%c%c%c)  IM%d/%cI\n",
		 cpu.A,
		 cpu.BC,
		 cpu.DE,
		 cpu.HL,
		 cpu.SP,
		 cpu.IX,
		 cpu.IY,
		 cpu.F,
		 cpu.F & 0x80 ? 'S' : '-',
		 cpu.F & 0x40 ? 'Z' : '-',
		 cpu.F & 0x10 ? 'A' : '-',
		 cpu.F & 0x04 ? 'P' : '-',
		 cpu.F & 0x02 ? 'N' : '-',
		 cpu.F & 0x01 ? 'C' : '-',
		 cpu.IM,
		 cpu.IF ? 'E' : 'D'
		 ];
	else
		[debug print:@"  A=%02X   BC=%04X DE=%04X HL=%04X SP=%04X   F=%02X (%c%c%c%c%c)   %cI\n",
		 cpu.A,
		 cpu.BC,
		 cpu.DE,
		 cpu.HL,
		 cpu.SP,
		 cpu.F,
		 cpu.F & 0x80 ? 'S' : '-',
		 cpu.F & 0x40 ? 'Z' : '-',
		 cpu.F & 0x10 ? 'A' : '-',
		 cpu.F & 0x04 ? 'P' : '-',
		 cpu.F & 0x01 ? 'C' : '-',
		 cpu.IF ? 'E' : 'D'
		 ];

	lastL = cpu.PC;
	lastD = cpu.HL;
    [self Dasm:cpu.Z80];
}

// -----------------------------------------------------------------------------
// Отладчик
// -----------------------------------------------------------------------------

- (BOOL) Debugger:(NSString *)command
{
	@try
	{
		if ([command isEqualToString:@"."])
		{
			dbgCmd = 0;
		}

		else if (dbgCmd == 'M')
		{
			if (command.length)
			{
				uint8_t *ptr; if ((ptr = [cpu BYTE:lastM]))
					*ptr = [self byte:command];
			}

			const uint8_t *ptr; if ((ptr = [cpu BYTE:++lastM]))
				[debug print:@"  %04X:  %02X ", lastM, *ptr];
			else
				[debug print:@"  %04X:  ?? ", lastM];

			return NO;
		}

        else if(dbgCmd == 'A')
        {
            if(command.length)
            {
                if(auto data = assembly(command.uppercaseString.UTF8String); !data.empty())
                {
                    for(auto byte: data)
                        if(auto ptr = [cpu BYTE:lastA++])
                            *ptr = byte;

                    [debug print:@"  %04X:  ", lastA];
                    return NO;
                }
            }
        }

		else if (dbgCmd == '1')
		{
			if (command.length)
				cpu.PC = [self word:command last:0];

			[debug print:@"  HL-%04X  ", cpu.HL];
			dbgCmd++; return NO;
		}

		else if (dbgCmd == '2')
		{
			if (command.length)
				cpu.HL = [self word:command last:0];

			[debug print:@"  BC-%04X  ", cpu.BC];
			dbgCmd++; return NO;
		}

		else if (dbgCmd == '3')
		{
			if (command.length)
				cpu.BC = [self word:command last:0];

			[debug print:@"  DE-%04X  ", cpu.DE];
			dbgCmd++; return NO;
		}

		else if (dbgCmd == '4')
		{
			if (command.length)
				cpu.DE = [self word:command last:0];

			[debug print:@"  SP-%04X  ", cpu.SP];
			dbgCmd++; return NO;
		}

		else if (dbgCmd == '5')
		{
			if (command.length)
				cpu.SP = [self word:command last:0];

			[debug print:@"  AF-%04X  ", cpu.AF];
			dbgCmd++; return NO;
		}

		else if (dbgCmd == '6')
		{
			if (command.length)
				cpu.AF = [self word:command last:0];
		}

		else if (command.length != 0)
		{
			NSArray<NSString *> *array = command.length == 1 ? nil : [[command substringFromIndex:1] componentsSeparatedByString:@","];

			unichar cmd = [command.uppercaseString characterAtIndex:0];

			if (cmd == 'Q')
			{
				if (array.count)
					@throw @"Неверное число аргументов";

				cpu.breakpoints = 0;
				[debug clear];
				return YES;
			}

			else if (cmd == '7')
			{
				if (array.count)
					@throw @"Неверное число аргументов";

				[debug print:@"КОИ-7\n"];
				unicode = koi7();
			}

			else if (cmd == '8')
			{
				if (array.count)
					@throw @"Неверное число аргументов";

				[debug print:@"КОИ-8\n"];
				unicode = koi8();
			}

			else if (cmd == 'G')
			{
				cpu.PC = [self word:array.firstObject last:cpu.PC];

				for (NSUInteger i = 1; i < array.count && array[i].length; i++)
					breakpoints[[self word:array[i] last:cpu.PC]] |= 0x20;

				return YES;
			}

			else if (cmd == 'B')
			{
				if (array.count > 3)
					@throw @"Неверное число аргументов";

				if (array.count == 0)
				{
					uint16_t addr = 0x0000; do if (breakpoints[addr])
					{
						uint16_t start = addr; while (addr != 0xFFFF && breakpoints[addr] == breakpoints[addr + 1]) addr++;

						[debug print:addr == start ? @"%c%c%c%c%c %04X\n" : @"%c%c%c%c%c %04X-%04X\n",
						 breakpoints[start] & 0x10 ? 'X' : ' ',
						 breakpoints[start] & 0x08 ? 'O' : ' ',
						 breakpoints[start] & 0x04 ? 'I' : ' ',
						 breakpoints[start] & 0x02 ? 'W' : ' ',
						 breakpoints[start] & 0x01 ? 'R' : ' ',
						 start,
						 addr];

					} while (addr++ != 0xFFFF);
				}

				else if (array.count == 1)
				{
					breakpoints[[self word:array.firstObject last:cpu.PC]] ^= 0x10;
				}

				else
				{
					uint16_t start = [self word:array.firstObject last:0];
					uint16_t end = [self word:array[1] last:start];

					if (array.count == 2)
					{
						do breakpoints[start] ^= 0x02;
						while (start++ != end);
					}
					else
					{
						uint8_t set = 0x00; for (NSUInteger i = 0; i < array.lastObject.length; i++)
						{
							switch ([array.lastObject.uppercaseString characterAtIndex:i])
							{
								case 'R':
									set |= 0x01;
									break;

								case 'W':
									set |= 0x02;
									break;

								case 'I':
									set |= 0x04;
									break;

								case 'O':
									set |= 0x08;
									break;

								case 'X':
									set |= 0x10;
									break;
							}
						}

						do breakpoints[start] = set;
						while (start++ != end);
					}
				}
			}

			else if (cmd == 'R')
			{
				if (array.count)
					@throw @"Неверное число аргументов";

				[self regs];
			}

			else if ((cmd == 'T' && array.count == 0) || cmd == 'P')
			{
				if (array.count)
					@throw @"Неверное число аргументов";

				const uint8_t *ptr; if (cmd == 'P' && (ptr = [cpu BYTE:cpu.PC]))
				{
					if ((cpu.Z80 ? *ptr : *ptr & 0xCF) == 0xCD || (*ptr & 0xC7) == 0xC4 || (*ptr & 0xC7) == 0xC2)	// CALL/Ccc/Jcc
					{
						breakpoints[cpu.PC + 3] |= 0x20;
						return YES;
					}

					else if ((*ptr & 0xC7) == 0xC7)	// RST
					{
						breakpoints[cpu.PC + 1] |= 0x20;
						return YES;
					}

					else if (cpu.Z80)
					{
						if (*ptr == 0x10 || *ptr == 0x20 || *ptr == 0x28 || *ptr == 0x30 || *ptr == 38)
						{
							breakpoints[cpu.PC + 2] |= 0x20;
							return YES;
						}

						else if (*ptr == 0xED)
						{
							if ((ptr = [cpu BYTE:cpu.PC + 1]) && *ptr >= 0xB0 && *ptr <= 0xBB)
							{
								breakpoints[cpu.PC + 2] |= 0x20;
								return YES;
							}
						}
					}
				}

				[cpu execute:cpu.CLK + 1];
				[self regs];
			}

			else if (cmd == 'L' || cmd == 'U' || cmd == 'Z')
			{
				if (array.count > 2)
					@throw @"Неверное число аргументов";

				if (array.count)
					lastL = [self word:array.firstObject last:0];

				uint16_t end = lastL; if (array.count > 1)
					end = [self word:array[1] last:lastL];

				if (lastL < end) while (lastL < end)
                        [self Dasm:cmd == 'L' ? cpu.Z80 : cmd == 'Z'];
				else for (int i = 0; i < 16; i++)
                        [self Dasm:cmd == 'L' ? cpu.Z80 : cmd == 'Z'];
			}
			
			else if (cmd == 'D')
			{
				if (array.count > 2)
					@throw @"Неверное число аргументов";

				if (array.count)
					lastD = [self word:array.firstObject last:0];

				uint16_t end = (lastD + 0x100) & 0xFFF0; if (array.count > 1)
					end = [self word:array[1] last:lastD] + 1;

				do
				{
					NSMutableString *chr = [NSMutableString stringWithFormat:@"%*s", lastD & 0xF, ""];
					[debug print:@"  %04X:%*s", lastD & 0xFFF0, (lastD & 0xF) * 3 + 2, ""];

					do
					{
						const uint8_t *ptr; if ((ptr = [cpu BYTE:lastD++]) && *ptr < unicode.length)
							[chr appendFormat:@"%C", [unicode characterAtIndex:*ptr]];
						else
							[chr appendString:@"."];

						if (ptr)
							[debug print:@"%02X ", *ptr];
						else
							[debug print:@"?? "];

					} while (lastD != end && lastD & 0xF);

					[debug print:@" %*s%@\n", (0x10 - lastD & 0x0F) * 3, "", chr];

				} while (lastD != end);
			}

			else if (cmd == 'F' || cmd == 'S')
			{
				if (array.count < 2 || array.count > 3)
					@throw @"Неверное число аргументов";

				uint16_t start = [self word:array.firstObject last:0];
				uint16_t end = [self word:array[1] last:start];

				uint8_t byte = 0x00; if (array.count > 2)
					byte = [self byte:array[2]];

				do
				{
					uint8_t *ptr; if ((ptr = [cpu BYTE:start]))
					{
						if (cmd == 'F')
							*ptr = byte;

						else if (*ptr == byte)
							[debug print:@"  %04X:  %02X\n", start, *ptr];
					}

				} while (start++ != end);
			}

			else if (cmd == 'T' || cmd == 'C')
			{
				if (array.count < 2 || array.count > 3)
					@throw @"Неверное число аргументов";

				uint16_t start = [self word:array.firstObject last:0];
				uint16_t end = [self word:array[1] last:start];

				uint16_t dest = 0; if (array.count > 2)
					dest = [self word:array[2] last:0];

				do
				{
					uint8_t *ptr, *dst; if ((ptr = [cpu BYTE:start]) && (dst = [cpu BYTE:dest]))
					{
						if (cmd == 'T')
							*dst = *ptr;

						else if (*dst != *ptr)
							[debug print:@"  %04X/%04X:  %02X/%02X\n", start, dest, *ptr, *dst];
					}

					dest++;

				} while (start++ != end);
			}

			else if (cmd == 'I')
			{
				if (array.count > 4)
					@throw @"Неверное число аргументов";

				uint16_t start = [self word:array.firstObject last:0];

				uint16_t end = 0xFFFF; if (array.count >= 2 && array[1].length)
					end = [self word:array[1] last:start];

				if (end < start)
					@throw @"Ошибка в конечном адресе";

				uint16_t pos = 0; if (array.count >= 3)
				{
					pos = [self word:array[2] last:0]; if (array.count >= 4)
						end = start + [self word:array[3] last:pos] - pos;
				}

				NSOpenPanel *panel = [NSOpenPanel openPanel];

				if ([panel runModal] == NSModalResponseOK && panel.URLs.count == 1)
				{
					NSData *data = [NSData dataWithContentsOfURL:panel.URLs.firstObject];

					if (data.length > pos)
					{
                        const uint8_t* bytes = (const uint8_t*) [data bytes] + pos;
						NSUInteger length = data.length - pos;

						[debug print:@"  %04X\n", lastD = start];

						do
						{
							uint8_t *ptr; if ((ptr = [cpu BYTE:start]))
								*ptr = *bytes;

							bytes++;

						} while (start++ != end && --length);

						[debug print:@"  %04X\n", (start - 1) & 0xFFFF];
					}
				}
			}

			else if (cmd == 'O')
			{
				if (array.count != 2)
					@throw @"Неверное число аргументов";

				uint16_t start = [self word:array.firstObject last:0];
				uint16_t end = [self word:array[1] last:start];

				if (end < start)
					@throw @"Ошибка в конечном адресе";

				NSMutableData *data = [NSMutableData dataWithLength:end - start + 1];
                uint8_t* mutableBytes = (uint8_t*) data.mutableBytes;

				[debug print:@"  %04X\n", start];

				const uint8_t *ptr; do
					*mutableBytes++ = (ptr = [cpu BYTE:start]) ? *ptr : 0xFF;
				while (start++ != end);

				[debug print:@"  %04X\n", (start - 1) & 0xFFFF];

				NSSavePanel *panel = [NSSavePanel savePanel];
				panel.allowedFileTypes = @[@"bin"];
				panel.allowsOtherFileTypes = YES;

				if ([panel runModal] == NSModalResponseOK)
					[data writeToURL:panel.URL atomically:YES];
			}

			else if (cmd == 'M')
			{
				if (array.count > 1)
					@throw @"Неверное число аргументов";

				lastM = [self word:array.firstObject last:0];

				uint8_t *ptr; if ((ptr = [cpu BYTE:lastM]))
					[debug print:@"  %04X:  %02X ", lastM, *ptr];
				else
					[debug print:@"  %04X:  ?? ", lastM];

				dbgCmd = 'M';
				return NO;
			}

			else if (cmd == 'A')
			{
				if (array.count > 1)
					@throw @"Неверное число аргументов";

				if (array.count)
					lastA = [self word:array.firstObject last:0];

				[debug print:@"  %04X:  ", lastA];

				dbgCmd = 'A';
				return NO;
			}
			
			else if (cmd == 'X')
			{
				if (array.count)
					@throw @"Неверное число аргументов";

				[debug print:@"  PC-%04X  ", cpu.PC];

				dbgCmd = '1';
				return NO;
			}

			else if (cmd == 'H')
			{
				if (array.count == 1)
				{
					uint16_t value = [self word:array.firstObject last:0];

					if (value < unicode.length)
						[debug print:@"  %04X #%u '%@'\n", value, value, [unicode substringWithRange:NSMakeRange(value, 1)]];
					else
						[debug print:@"  %04X #%u\n", value, value];
				}

				else if (array.count == 2)
				{
					uint16_t v1 = [self word:array.firstObject last:0];
					uint16_t v2 = [self word:array[1] last:v1];

					[debug print:@"  %04X %04X\n", (v1 + v2) & 0xFFFF, (v1 - v2) & 0xFFFF];
				}

				else
				{
					@throw @"Неверное число аргументов";
				}
			}

			else
			{
				@throw @"Неизвестная директива";
			}
		}
	}
	
	@catch (NSException *exception)
	{
		[debug print:@"%@\n# ", exception];
		dbgCmd = 0; return NO;
	}
	
	@catch (NSString *string)
	{
		[debug print:@"%@\n# ", string];
		dbgCmd = 0; return NO;
	}
	
	[debug print:@"# "];
	dbgCmd = 0; return NO;
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
