/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 "Фабрика" ретрокомпьютеров Микро-80 и ЮТ-88

 *****/

#import "Micro80Factory.h"

#import "Micro80.h"
#import "UT88.h"

@implementation Micro80Factory

+ (NSArray<NSString *> *)extensions
{
	return @[@"rk8", @"rku"];
}

+ (Computer *)computerByTag:(NSInteger)tag
{
	switch (tag)
	{
		case 1:
			return [[Micro80 alloc] init];

		case 2:
			return [[Micro80II alloc] init];

		case 3:
			return [[UT88 alloc] init];
	}

	return nil;
}

+ (Computer *)computerFromData:(NSData *)data URL:(NSURL *)url
{
	NSString *pathExtension = url.pathExtension.lowercaseString;

	if ([pathExtension isEqualToString:@"rku"])
		return [[UT88 alloc] initWithData:data];

	return [[Micro80 alloc] initWithData:data];
}

@end
