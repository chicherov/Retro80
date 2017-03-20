/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 "Фабрика" ретрокомпьютеров

 *****/

@class Computer;

@protocol ComputerFactory<NSObject>
+ (NSArray<NSString *> *)extensions;
+ (Computer *)computerFromData:(NSData *)data URL:(NSURL *)url;
+ (Computer *)computerByTag:(NSInteger)tag;
@end

@interface ComputerFactory : NSObject<ComputerFactory>
@end
