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

@interface Specialist : Retro80

@property(nonatomic, strong) SpecialistScreen *crt;
@property(nonatomic, strong) X8253* snd;

@property(nonatomic, strong) SpecialistKeyboard *kbd;
@property(nonatomic, strong) X8255* ext;

@property(nonatomic, strong) F806 *inpHook;
@property(nonatomic, strong) F80C *outHook;

- (instancetype)initWithData:(NSData *)data;
- (instancetype)init;

@end

@interface SpecialistLik : Specialist
@end

@interface Specialist2 : Specialist
@end

@interface Specialist27 : Specialist2
@end

@interface Specialist33 : Specialist27
@end
