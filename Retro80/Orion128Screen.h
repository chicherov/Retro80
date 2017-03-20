/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Интерфейс графического экрана ПЭВМ «Орион-128»

 *****/

#import "Retro80.h"

@interface Orion128Screen : NSObject<CRT, IRQ, RESET, NSCoding>

@property(nonatomic) uint8_t **pMemory;

@property(nonatomic) uint8_t color;
@property(nonatomic) uint8_t page;

@property(nonatomic) BOOL IE;

@end
