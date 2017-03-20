/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Контроллер дисковода для Радио-86РК/Микроша

 *****/

#import "x8255.h"

@interface RKFloppy : X8255 <BYTE, Enabled>

@property(nonatomic, readonly) unsigned selected;
@property(nonatomic, strong) NSURL *diskA;
@property(nonatomic, strong) NSURL *diskB;

@end
