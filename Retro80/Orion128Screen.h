/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2026 Andrey Chicherov <andrey@chicherov.ru>

 Интерфейс графического экрана ПЭВМ «Орион-128»

 *****/

#import "Retro80.h"

@interface Orion128Screen : NSObject<CRT, RESET, NSCoding>

@property(nonatomic) uint8_t **pMemory;

@property(nonatomic) uint8_t color;
@property(nonatomic) uint8_t page;

@end
