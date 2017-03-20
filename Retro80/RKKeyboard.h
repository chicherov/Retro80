/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Клавиатура РК86 на 8255

 *****/

#import "x8255.h"

@interface RKKeyboard : X8255
{
	// Раскладка клавиатуры (64/72 кода)

	NSArray<NSNumber *> *kbdmap;

	NSString *chr1Map;
	NSString *chr2Map;
	BOOL upperCase;

	// Нажатые кнопки

	unsigned short keyboard[72];
	NSUInteger modifierFlags;
	BOOL ignoreShift;

	// Маски служебных клавиш

	uint8_t RUSLAT;
	uint8_t SHIFT;
	uint8_t CTRL;

	// Маски магнитофона

	uint8_t TAPEI;
	uint8_t TAPEO;
}

- (void)pasteString:(NSString *)string;

- (void) keyboardInit;

@property(nonatomic) BOOL qwerty;

@end
