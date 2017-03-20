/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Микро-80»

 *****/

#import "Retro80.h"
#import "mem.h"

#import "Micro80Keyboard.h"
#import "Micro80Recorder.h"
#import "Micro80Screen.h"

#import "RKRecorder.h"
#import "RKSDCard.h"

// Оригинальный Микро-80
@interface Micro80 : Retro80

@property(strong, nonatomic) Micro80Screen *crt;
@property(strong, nonatomic) Micro80Recorder *snd;
@property(strong, nonatomic) Micro80Keyboard *kbd;

@property(strong, nonatomic) F806 *inpHook;
@property(strong, nonatomic) F80C *outHook;

- (instancetype)initWithData:(NSData *)data;
- (instancetype)init;

@end

// Микро-80 с доработками
@interface Micro80II : Micro80
@property RKSDCard *ext;
@end
