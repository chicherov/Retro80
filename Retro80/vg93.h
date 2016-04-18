/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 КР1818ВГ93

 *****/

#import "x8080.h"
#import "x8257.h"

@interface VG93 : NSObject<RD, WR, RESET, DMA, HLDA, NSCoding>
{
	union VG93_command		// Регистр команды
	{
		uint8_t byte;

		struct	// Для команд: Восстановление, Поиск, Шаг, Шаг вперед, Шаг назад
		{
			unsigned r:2;	// скорость перемещения МГ (6, 12, 20, 30)
			unsigned V:1;	// 1 - проверяется номер дорожки, на которой находится МГ
			unsigned h:1;	// 1 - головка устанавливается на диск
			unsigned u:1;	// 1 - изменение регистра дорожки
		};

		struct	// Для команд: Чтение сектора, Запись сектора
		{
			unsigned a:1;	// код адресной метки данных (ДАМ): 1-F8/данные могут стираться, 0-FB/область данных сохраняется (Запись сектора)
			unsigned C:1;	// 1 - необходимость проверки номера стороны диска, (Чтение/Запись сектора)
			unsigned E:1;	// 1 - задержка 15мс перед выдачей HLD после появления HRDY
			unsigned s:1;	// номер стороны диска (Чтения/Записи сектора)
			unsigned m:1;	// 0 - обращение к одному сектору, 1 - больше одного (Чтение/Запись сектора)
		};

		struct // Для команды Принудительное прерывание
		{
			unsigned J0:1;
			unsigned J1:1;
			unsigned J2:1;
			unsigned J3:1;

		};

		struct
		{
			unsigned     :4;
			unsigned code:4;	// Сам код команды
		};

	} command;

	union VG93_status
	{
		uint8_t byte; struct
		{
			unsigned S0:1;	// Занято
			unsigned S1:1;	// ИИ (Вспомогательная), Запрос данных
			unsigned S2:1;	// Дор.0 (Вспомогательная), Потеря данных
			unsigned S3:1;	// Ошибка в КК (кроме Чтение/Запись дорожки)
			unsigned S4:1;	// Ошибка поиска (Вспомогательная), Массив не найден (Чтение адреса/сектора, Запись сектора)
			unsigned S5:1;	// Загрузка МГ (Вспомогательная), Тип записи (Чтение сектора), Ошибка записи (Запись сектора/дорожки)
			unsigned S6:1;	// Защита записи (кроме команд чтения)
			unsigned S7:1;	// 1 - не готов; 0 - готов
		};

	} status;

	uint8_t cylinder;
	uint8_t sector;
	uint8_t shift;
}

- (id) initWithQuartz:(unsigned)quartz;

- (void) setDisk:(NSInteger)disk URL:(NSURL *)url;
- (NSURL *) getDisk:(NSInteger)disk;
- (BOOL) busy;

@property unsigned selected;
@property BOOL head;
@property BOOL HOLD;

@end
