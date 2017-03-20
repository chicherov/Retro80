/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 "Фабрика" ретрокомпьютеров Радио-86РК и его клонов

 *****/

#import "Radio86RKFactory.h"

#import "Radio86RK.h"
#import "Microsha.h"
#import "Apogeo.h"
#import "Partner.h"

@implementation Radio86RKFactory

+ (NSArray<NSString *> *)extensions
{
	return @[@"rkr", @"rk", @"gam", @"pki", @"rkm", @"rkp", @"rka"];
}

+ (Computer *)computerByTag:(NSInteger)tag
{
	switch (tag)
	{
		case 1:
			return [[Radio86RK alloc] init];

		case 2:
			return [[Microsha alloc] init];

		case 3:
			return [[Partner alloc] init];

		case 4:
			return [[Apogeo alloc] init];
	}

	return nil;
}

+ (Computer *)computerFromData:(NSData *)data URL:(NSURL *)url
{
	NSString *pathExtension = url.pathExtension.lowercaseString;

	if ([pathExtension isEqualToString:@"gam"] || [pathExtension isEqualToString:@"pki"])
	{
		if (data.length && *(uint8_t *) data.bytes == 0xE6)
			data = [data subdataWithRange:NSMakeRange(1, data.length - 1)];
	}

	else if ([pathExtension isEqualToString:@"rkm"])
		return [[Microsha alloc] initWithData:data];

	else if ([pathExtension isEqualToString:@"rkp"])
		return [[Partner alloc] initWithData:data];

	else if ([pathExtension isEqualToString:@"rka"])
		return [[Apogeo alloc] initWithData:data];

	return [[Radio86RK alloc] initWithData:data];
}

@end
