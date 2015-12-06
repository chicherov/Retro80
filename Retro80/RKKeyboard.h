#import "x8080.h"
#import "x8255.h"

// -----------------------------------------------------------------------------
// Клавиатура РК86 на 8255
// -----------------------------------------------------------------------------

@interface RKKeyboard : X8255 <Keyboard>
{
	// Раскладка клавиатуры (64/72 кода)

	NSArray* kbdmap;

	NSString* chr1Map;
	NSString* chr2Map;
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

// Для интерфейса магнитофона

@property (weak) NSObject <SoundController> *snd;

- (void) scan:(uint64_t)clock;
- (void) keyboardInit;

@end
