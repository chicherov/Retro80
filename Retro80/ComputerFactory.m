/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 "Фабрика" ретрокомпьютеров

 *****/

#import "ComputerFactory.h"

#import "Radio86RKFactory.h"
#import "Micro80Factory.h"
#import "SpecialistFactory.h"
#import "Orion128Factory.h"

@implementation ComputerFactory

+ (NSArray<Class<ComputerFactory>> *)factories
{
	static NSArray<Class<ComputerFactory>> *factories = nil;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		factories = @[Radio86RKFactory.class, Micro80Factory.class, SpecialistFactory.class, Orion128Factory.class];
	});

	return factories;
}

+ (NSArray<NSString *> *)extensions
{
	NSMutableArray<NSString *> *extensions = [NSMutableArray array];

	for (Class<ComputerFactory> factory in self.factories)
		[extensions addObjectsFromArray:factory.extensions];

	return extensions;
}

+ (Computer *)computerFromData:(NSData *)data URL:(NSURL *)url
{
	NSString *pathExtension = url.pathExtension.lowercaseString;

	for (Class<ComputerFactory> factory in self.factories)
		if ([factory.extensions containsObject:pathExtension])
			return [factory computerFromData:data URL:url];

	return nil;
}

+ (Computer *)computerByTag:(NSInteger)tag
{
	NSUInteger index = (NSUInteger) ((tag / 100) - 1);

	if (index < self.factories.count)
		return [self.factories[index] computerByTag:tag%100];

	return nil;
}

@end
