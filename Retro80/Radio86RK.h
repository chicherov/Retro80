/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Радио-86РК»

 *****/

#import "RK86Base.h"
#import "RKFloppy.h"
#import "RKSDCard.h"

@interface Radio86RK : RK86Base
@property(nonatomic, strong) RKFloppy *fdd;
@end

// Таймер ВИ53 (только запись) повешен параллельно ВВ55
@interface Radio86RKExt : RKSDCard
@end
