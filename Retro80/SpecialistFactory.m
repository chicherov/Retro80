/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 "Фабрика" ретрокомпьютеров Специалист

 *****/

#import "SpecialistFactory.h"
#import "Specialist.h"
#import "SpecialistSP580.h"
#import "SpecialistMX.h"

@implementation SpecialistFactory

+ (NSArray<NSString *> *)extensions
{
	return @[@"rks", @"mon", @"cpu", @"i80"];
}

+ (Computer *)computerByTag:(NSInteger)tag
{
	switch (tag)
	{
		case 1:
			return [[Specialist alloc] init];

		case 2:
			return [[Specialist2 alloc] init];

		case 3:
			return [[SpecialistLik alloc] init];

		case 4:
			return [[SpecialistSP580 alloc] init];

		case 5:
			return [[Specialist27 alloc] init];

		case 6:
			return [[Specialist33 alloc] init];

		case 11:
			return [[SpecialistMX alloc] init];

		case 12:
			return [[SpecialistMX_MXOS alloc] init];

		case 13:
			return [[SpecialistMX2 alloc] init];

	}

	return nil;
}

+ (SpecialistMX *)SpecialistMXWithMonitor:(NSURL *)url data:(NSData *)data
{
	if (data == nil)
		return nil;

	NSScanner *scanner = [NSScanner scannerWithString:url.lastPathComponent.stringByDeletingPathExtension];

	if (![scanner scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet] intoString:NULL])
		return nil;

	if (![scanner scanCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"_"] intoString:NULL])
		return nil;

	if (scanner.scanLocation != 3)
		return nil;

	unsigned address;

	if (![scanner scanHexInt:&address] || address + data.length > 0xFFBF)
		return nil;

	SpecialistMX *specialistMX = [[SpecialistMX alloc] init];

	if (!specialistMX)
		return nil;

	memcpy(specialistMX.ram.mutableBytes + address, data.bytes, data.length);

	specialistMX.cpu.START = address;
	specialistMX.cpu.PC = address;
	specialistMX.cpu.PAGE = 0;
	return specialistMX;
}

+ (SpecialistMX *)SpecialistMXWithMonitor:(NSURL *)url
{
	return [self.class SpecialistMXWithMonitor:url data:[NSData dataWithContentsOfURL:url]];
}

+ (Computer *)computerFromData:(NSData *)data URL:(NSURL *)url
{
	NSString *pathExtension = url.pathExtension.lowercaseString;

	if ([pathExtension isEqualToString:@"rks"])
	{
		NSUInteger length = data.length;
		const uint8_t *ptr = data.bytes;

		if (length > 23 && memcmp(ptr, "\x70\x8F\x82\x8F", 4) == 0)
		{
			for (length -= 23, ptr += 23; length && *ptr == 0x00; length--, ptr++);

			if (length-- && *ptr++ == 0xE6)
				return [[SpecialistLik alloc] initWithData:[NSData dataWithBytes:ptr length:length]];
			else
				return nil;
		}

		else if (length > 3 && memcmp(ptr, "\xD9\xD9\xD9", 3) == 0)
		{
			for (length -= 3, ptr += 3; length && *ptr != 0x00; length--, ptr++);
			for (; length && *ptr == 0x00; length--, ptr++);

			if (length-- && *ptr++ == 0xE6)
				return [[Specialist2 alloc] initWithData:[NSData dataWithBytes:ptr length:length]];
			else
				return nil;
		}

		return [[Specialist2 alloc] initWithData:data];
	}

	else if ([pathExtension isEqualToString:@"mon"])
	{
		return [self SpecialistMXWithMonitor:url data:data];
	}

	else
	{
		NSArray<NSString *> *info = nil;

		if ([pathExtension isEqualToString:@"i80"])
		{
			info = [[[[NSString stringWithContentsOfURL:[url.URLByDeletingPathExtension URLByAppendingPathExtension:@"cpu"]
											   encoding:NSASCIIStringEncoding error:NULL] componentsSeparatedByString:@"\r"]
				componentsJoinedByString:@""] componentsSeparatedByString:@"\n"];
		}
		else if ([pathExtension isEqualToString:@"cpu"])
		{
			info = [[[[[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding] componentsSeparatedByString:@"\r"]
				componentsJoinedByString:@""] componentsSeparatedByString:@"\n"];

			data = [NSData dataWithContentsOfURL:[url.URLByDeletingPathExtension URLByAppendingPathExtension:@"i80"]];
		}

		if (info.count < 2 || data == nil)
			return nil;

		unsigned begin;

		if (![[NSScanner scannerWithString:info[0]] scanHexInt:&begin] || begin + data.length > 0xFFBF)
			return nil;

		unsigned start;

		if (![[NSScanner scannerWithString:info[1]] scanHexInt:&start] || start > 0xFFBF)
			return nil;

		SpecialistMX *specialistMX = nil;

		if (info.count > 2 && info[2].length && ![info[2].lowercaseString isEqualToString:@"spmx.rom"])
			specialistMX = [self SpecialistMXWithMonitor:[url.URLByDeletingLastPathComponent URLByAppendingPathComponent:info[2]]];
		else
			specialistMX = [[SpecialistMX alloc] init];

		if (!specialistMX)
			return nil;

		[specialistMX.cpu execute:specialistMX.quartz];

		memcpy(specialistMX.ram.mutableBytes + begin, data.bytes, data.length);

		specialistMX.cpu.PC = start;
		specialistMX.cpu.PAGE = 0;
		return specialistMX;
	}

	return nil;
}

@end
