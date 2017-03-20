/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Интерфейс графического экрана ПЭВМ «Специалист»

 *****/

#import "Retro80.h"

@interface SpecialistScreen : NSObject<CRT, WR, NSCoding>

@property(nonatomic) uint8_t *screen;

@property(nonatomic) uint8_t color;
@property(nonatomic) BOOL isColor;

@end
