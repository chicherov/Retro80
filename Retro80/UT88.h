/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «ЮТ-88»

 *****/

#import "Micro80.h"
#import "x8253.h"

#import "UT88Keyboard.h"
#import "UT88Screen.h"
#import "UT88System.h"

@interface UT88 : Retro80

@property(strong, nonatomic) UT88Screen *crt;
@property(strong, nonatomic) X8253 *snd;

@property(strong, nonatomic) UT88Keyboard *kbd;
@property(strong, nonatomic) RKSDCard *ext;

@property(strong, nonatomic) ROM *monitor0;
@property(strong, nonatomic) ROM *monitorF;

@property(strong, nonatomic) UT88System *sys;

@property(strong, nonatomic) F806 *inpHook;
@property(strong, nonatomic) F80C *outHook;

- (instancetype)initWithData:(NSData *)data;
- (instancetype)init;

@end
