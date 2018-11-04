/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Специалист»

 *****/

#import "Retro80.h"
#import "x8255.h"
#import "x8253.h"
#import "mem.h"

#import "SpecialistScreen.h"
#import "SpecialistKeyboard.h"

#import "RKRecorder.h"

// ПЭВМ «Специалист» с монитором 1

@interface Specialist : Retro80

@property(nonatomic, strong) SpecialistScreen *crt;
@property(nonatomic, strong) X8253 *snd;

@property(nonatomic, strong) SpecialistKeyboard *kbd;
@property(nonatomic, strong) X8255 *ext;

@property(nonatomic, strong) F806 *inpHook;
@property(nonatomic, strong) F80C *outHook;

- (instancetype)initWithData:(NSData *)data;
- (instancetype)init;

@end

// ПЭВМ «Специалист» с монитором ПЭВМ «ЛИК»

@interface SpecialistLik : Specialist
@end

// ПЭВМ «Специалист» с монитором 2

@interface Specialist2 : Specialist
@end

// ПЭВМ «Специалист» с монитором 2.7

@interface Specialist27 : Specialist2
@end

// ПЭВМ «Специалист» с монитором 3.3

@interface Specialist33 : Specialist27
@end
