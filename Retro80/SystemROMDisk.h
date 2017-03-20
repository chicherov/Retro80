/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Системный ROM-диск

 *****/

#import "ROMDisk.h"

@interface SystemROMDisk : ROMDisk
{
	NSString *resource;
}

- (instancetype)initWithContentsOfResource:(NSString *)string;

@end
