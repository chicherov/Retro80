/*****
 
 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2026 Andrey Chicherov <andrey@chicherov.ru>
 
 Интерфейс RAM диска и прерывания ПЭВМ «ЮТ-88»
 
 *****/

#import "Retro80.h"
#import "mem.h"

@interface UT88System : NSObject<RD, WR, RESET>
@property(nonatomic, assign) X8080 *cpu;
- (MEM *)RAMDISK:(RAM *)ram;
@end
