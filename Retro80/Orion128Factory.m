/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 "Фабрика" ретрокомпьютеров «Орион-128»

 *****/

#import "Orion128Factory.h"
#import "Orion128.h"

@implementation Orion128Factory

+ (NSArray<NSString *> *)extensions
{
	return @[@"rko"];
}

+ (Computer *)computerByTag:(NSInteger)tag
{
	switch (tag)
	{
		case 2:
			return [[Orion128 alloc] init];

		case 1:
			return [[Orion128M1 alloc] init];

		case 3:
			return [[Orion128M3 alloc] init];

		case 4:
			return [[Orion128Z80V31 alloc] init];

		case 5:
			return [[Orion128Z80V32 alloc] init];

		case 6:
			return [[Orion128Z80II alloc] init];

		case 7:
			return [[Orion128Z80IIM33 alloc] init];
	}

	return nil;
}

+ (Computer *)computerFromData:(NSData *)data URL:(NSURL *)url
{
	return [[Orion128 alloc] initWithData:data];
}

@end
