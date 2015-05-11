/*******************************************************************************
 * Интерфейс клавиатуры ПЭВМ «Специалист»
 ******************************************************************************/

#import "SpecialistScreen.h"
#import "RKKeyboard.h"

@interface SpecialistKeyboard : RKKeyboard

@property SpecialistScreen *crt;
@property BOOL four;

@end
