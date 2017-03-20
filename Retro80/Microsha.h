/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Микроша»

 *****/

#import "RK86Base.h"
#import "RKFloppy.h"

@interface Microsha : RK86Base
@property(nonatomic, strong) RKFloppy *fdd;
@end

// Клавиатура ПЭВМ «Микроша»
@interface MicroshaKeyboard : RKKeyboard
@end

// Второй интерфейс ВВ55 ПЭВМ «Микроша»
@interface MicroshaExt : X8255
@end

// Вывод байта на магнитофон (Микроша)
@interface MicroshaF80C : F80C
@end
