/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Базовый вариант РК86 без ПЗУ и распределения памяти

 *****/

#import "Retro80.h"

#import "x8275.h"
#import "x8257.h"
#import "x8253.h"
#import "mem.h"

#import "RKKeyboard.h"
#import "RKRecorder.h"

@interface RK86Base : Retro80

@property(nonatomic, strong) X8275 *crt;
@property(nonatomic, strong) X8257 *dma;
@property(nonatomic, strong) X8253 *snd;

@property(nonatomic, strong) RKKeyboard *kbd;
@property(nonatomic, strong) X8255 *ext;

@property(nonatomic) unsigned colorScheme;

@property(nonatomic, strong) F806 *inpHook;
@property(nonatomic, strong) F80C *outHook;

- (instancetype)initWithData:(NSData *)data;
- (instancetype)init;

@end
