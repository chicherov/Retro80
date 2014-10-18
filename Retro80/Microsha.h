/*******************************************************************************
 ПЭВМ «Микроша»
 ******************************************************************************/

#import "RK86Base.h"
#import "Floppy.h"

@class Microsha;

// -----------------------------------------------------------------------------
// Первый интерфейс 8255, вариант клавиатуры РК86 для Микроши
// -----------------------------------------------------------------------------

@interface MicroshaKeyboard : RKKeyboard

@property X8253* snd;

@end

// -----------------------------------------------------------------------------
// Второй интерфейс 8255, управление знакогенератором
// -----------------------------------------------------------------------------

@interface MicroshaExt : X8255

@property X8275 *crt;

@end

// -----------------------------------------------------------------------------
// FCAB - Вывод байта на магнитофон (Микроша)
// -----------------------------------------------------------------------------

@interface FCAB : F80C

@end

// -----------------------------------------------------------------------------
// ПЭВМ «Микроша»
// -----------------------------------------------------------------------------

@interface Microsha : RK86Base

@property MicroshaKeyboard *kbd;
@property MicroshaExt *ext;

@property Floppy *floppy;
@property Memory *dos29;

@property BOOL isExtRAM;
@property BOOL isFloppy;

@end
