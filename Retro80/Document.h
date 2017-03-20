/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 *****/

@class Computer;

@interface Document : NSDocument

- (instancetype)initWithComputerType:(Computer *)computer
							typeName:(NSString *)typeName
							   error:(NSError **)outError;

@property(nonatomic, strong, readonly) Computer *computer;

- (void)registerUndo:(NSString *)string;
- (void)performUndo:(NSData *)data;

@end
