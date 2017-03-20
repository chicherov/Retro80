/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Адаптер SD-CARD для Радио-86РК

 *****/

#import "ROMDisk.h"

#define ERR_START			0x40
#define ERR_WAIT			0x41
#define ERR_OK_DISK			0x42
#define ERR_OK_CMD			0x43
#define ERR_OK_READ			0x44
#define ERR_OK_ENTRY		0x45
#define ERR_OK_WRITE		0x46
#define ERR_OK_RKS			0x47
#define ERR_READ_BLOCK		0x4F

#define ERR_OK				0	// Нет ошибки
#define ERR_NO_FILESYSTEM	1	// Файловая система не обнаружена
#define ERR_DISK_ERR		2	// Ошибка чтения/записи
#define	ERR_NOT_OPENED		3	// Файл/папка не открыта
#define	ERR_NO_PATH			4	// Файл/папка не найдена
#define ERR_DIR_FULL		5	// Папка содержит максимальное кол-во файлов
#define ERR_NO_FREE_SPACE	6	// Нет свободного места
#define ERR_DIR_NOT_EMPTY	7	// Нельзя удалить папку, она не пуста
#define ERR_FILE_EXISTS		8	// Файл/папка с таким именем уже существует
#define ERR_NO_DATA			9	// fs_file_wtotal=0 при вызове функции fs_write_begin
#define ERR_MAX_FILES		10	// fs_findfirst вернула не все файлы
#define ERR_RECV_STRING		11	// Слишком длинный путь
#define ERR_INVALID_COMMAND	12
#define ERR_ALREADY_OPENED	13	// Файл уже открыт (fs_swap)

// ---------------------------------------------------------------------------------------------------------------------

@interface RKSDCard : ROMDisk
{
	uint8_t request[1024 + 7];
	NSMutableData *buffer;
	NSUInteger pos;

	uint8_t out;
	int sdcard;
}

- (NSString *)sdbiosrk;
- (NSString *)bootrk;

- (uint8_t)sendFileHandle:(NSFileHandle *)fileHandle length:(uint16_t)length;
- (uint8_t)sendRKFileHandle:(NSFileHandle *)fileHandle;

- (uint8_t)cmd_boot;
- (uint8_t)cmd_ver;
- (uint8_t)cmd_exec;
- (uint8_t)cmd_find;
- (uint8_t)cmd_open;
- (uint8_t)cmd_lseek;
- (uint8_t)cmd_read;
- (uint8_t)cmd_write;
- (uint8_t)cmd_move;

- (uint8_t)execute:(uint8_t)data;

@end
