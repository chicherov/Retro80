/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Контроллер дисковода для Радио-86РК/Микроша

 *****/

#import "RKFloppy.h"

@implementation RKFloppy
{
	NSMutableData *rkdos;

	NSFileHandle *file;

	uint64_t started;
	unsigned track;
	unsigned head;

	BOOL readonly;
	BOOL ready;

	unsigned long long offset;
	uint8_t buffer[3125];
	unsigned pos;
	BOOL update;

	uint8_t D;
}

@synthesize enabled;

@synthesize selected;
@synthesize diskA;
@synthesize diskB;

- (void)flush
{
	if (update)
	{
		[file seekToFileOffset:offset];
		[file writeData:[NSData dataWithBytes:buffer length:sizeof(buffer)]];
		update = NO;
	}
}

- (void)read
{
	[self flush];
	memset(buffer, 0x00, sizeof(buffer));
	[file seekToFileOffset:offset = (track*2 + head)*sizeof(buffer)];
	[[file readDataOfLength:sizeof(buffer)] getBytes:buffer length:sizeof(buffer)];
}

- (void)selectDisk:(unsigned)disk
{
	if (selected != disk)
	{
		if (file)
		{
			[self flush];
			selected = 0;
			file = nil;
		}

		if (disk)
		{
			NSString *path = nil;

			switch (disk)
			{
				case 1:
					path = diskA.path;
					break;

				case 2:
					path = diskB.path;
					break;
			}

			if (path)
			{
				if (!(readonly = ![NSFileManager.defaultManager isWritableFileAtPath:path]))
					file = [NSFileHandle fileHandleForUpdatingAtPath:path];
				else
					file = [NSFileHandle fileHandleForReadingAtPath:path];

				if (file)
				{
					started = self.computer.clock + 16000000;

					selected = disk;
					[self read];
				}
			}
		}
	}
}

// запись байта на диск
- (void)setA:(uint8_t)data
{
	if (ready && (C & 0x01) == 0x00)
	{
		buffer[pos] = data;
		update = YES;
		ready = NO;
	}
}

// чтения байта с диска
- (uint8_t)D
{
	if (ready && (C & 0x01) == 0x01)
	{
		D = buffer[pos];
		ready = NO;
	}

	return D;
}

// статус контроллера
- (uint8_t)B
{
	uint8_t status = 0xFF;

	if (selected)
	{
		if (track == 0)
			status &= ~0x20;                // РВ5 - трек 00

		if (readonly)
			status &= ~0x08;                // РВЗ - защита записи

		if (self.computer.clock > started)
		{
			status &= ~0x10;                // РВ4 - готовность НГМД

			unsigned p = (self.computer.clock - started)/1024%sizeof(buffer);

			if (pos != p)
			{
				ready = YES;
				pos = p;
			}

			if (pos == sizeof(buffer) - 1)
				status &= ~0x40;            // РВ6 - индекс

			if (!ready)
				status &= ~0x80;            // РВ7 - триггер готовности
		}
	}
	else
	{
		status &= ~0x80;
	}

	return status;
}

// управление контроллером
- (void)setC:(uint8_t)data
{
	if ((data & 0x28) == 0x08)		// PC5 - выбор первого накопителя
	{
		[self selectDisk:1];
	}
	else if ((data & 0x28) == 0x20)	// РСЗ - выбор второго накопителя
	{
		[self selectDisk:2];
	}
	else
	{
		[self selectDisk:0];
	}

	if (selected && (C & 0x10) == 0x10 && (data & 0x10) == 0x00)	// РС4 - шаг
	{
		if (((data & 0x02) == 0x00) && track < 79)					// РС1 - направление шага
		{
			if (self.computer.clock > started)
				started = self.computer.clock + 1600000;

			head = (C & 0x04) != 0;
			track++;
			[self read];
		}

		if (((data & 0x02) == 0x02) && track > 0)					// РС1 - направление шага
		{
			if (self.computer.clock > started)
				started = self.computer.clock + 1600000;

			head = (C & 0x04) != 0;
			track--;
			[self read];
		}
	}

	if (selected && ((data & 0x04) != 0) != head)					// РС2 - выбор поверхности
	{
		if (self.computer.clock > started)
			started = self.computer.clock + 800000;

		head = (C & 0x04) != 0;
		[self read];
	}
}

- (void)RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if (enabled)
	{
		if ((addr & 0x1000) == 0)
			[rkdos getBytes:data range:NSMakeRange(addr & 0xFFF, 1)];
		else if ((addr & 0x04) == 0)
			[super RD:addr data:data CLK:clock];
		else
			*data = self.D;
	}
}

- (void)WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	if (enabled && (addr & 0x1004) == 0x1000)
		[super WR:addr data:data CLK:clock];
}

- (uint8_t *)BYTE:(uint16_t)addr
{
	if (enabled && (addr & 0x1000) == 0)
		return (uint8_t *)rkdos.mutableBytes + (addr & 0xFFF);
	else
		return NULL;
}

- (instancetype)init
{
	if (self = [super init])
	{
		rkdos = [NSMutableData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"dos29" ofType:@"bin"]];

		if (rkdos.length != 0x1000)
			return self = nil;

		enabled = YES;
	}

	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
	[coder encodeBool:enabled forKey:@"enabled"];
	[coder encodeObject:diskA forKey:@"diskA"];
	[coder encodeObject:diskB forKey:@"diskB"];
	[coder encodeObject:rkdos forKey:@"rkdos"];

	[self flush];

	[coder encodeInt:track forKey:@"track"];
	[coder encodeInt:head forKey:@"head"];

	[coder encodeInt:selected forKey:@"selected"];
	[coder encodeInt64:started forKey:@"started"];

	[coder encodeBool:ready forKey:@"ready"];
	[coder encodeInt:pos forKey:@"pos"];
	[coder encodeInt:D forKey:@"D"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
	if (self = [super initWithCoder:coder])
	{
		enabled = [coder decodeBoolForKey:@"enabled"];

		diskA = [coder decodeObjectForKey:@"diskA"];
		diskB = [coder decodeObjectForKey:@"diskB"];

		rkdos = [coder decodeObjectForKey:@"rkdos"];

		if (rkdos.length != 0x1000)
			return self = nil;

		track = [coder decodeIntForKey:@"track"];
		head = [coder decodeIntForKey:@"head"];

		[self selectDisk:[coder decodeIntForKey:@"selected"]];
		started = [coder decodeInt64ForKey:@"started"];

		ready = [coder decodeBoolForKey:@"ready"];
		pos = [coder decodeIntForKey:@"pos"];
		D = [coder decodeIntForKey:@"D"];
	}

	return self;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(floppy:))
	{
		menuItem.hidden = menuItem.tag < 0 || menuItem.tag > 2;

		NSURL *url = nil;

		switch (menuItem.tag)
		{
			case 0:
			{
				menuItem.state = self.isEnabled;
				return self.selected == 0;
			}

			default:
			{
				menuItem.state = NO;
				return NO;
			}

			case 1:
			{
				url = self.diskA;
				break;
			}

			case 2:
			{
				url = self.diskB;
				break;
			}
		}

		if ((menuItem.state = url != nil))
			menuItem.title = [[menuItem.title componentsSeparatedByString:@":"].firstObject
				stringByAppendingFormat:@": %@", url.lastPathComponent];
		else
			menuItem.title = [[menuItem.title componentsSeparatedByString:@":"].firstObject
				stringByAppendingString:@":"];

		return self.isEnabled && menuItem.tag != selected;
	}

	return NO;
}

- (IBAction)floppy:(NSMenuItem *)menuItem;
{
	if (menuItem.tag == 0)
	{
		@synchronized(self.computer)
		{
			[self.computer registerUndoWithMenuItem:menuItem];
			self.enabled = self.isEnabled ? selected != 0 : YES;
		}
	}

	else if ((menuItem.tag == 1 || menuItem.tag == 2) && self.isEnabled)
	{
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		panel.allowedFileTypes = @[@"rkdisk"];
		panel.canChooseDirectories = NO;
		panel.title = menuItem.title;

		if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
		{
			@synchronized(self.computer)
			{
				[self.computer registerUndoWithMenuItem:menuItem];

				switch (menuItem.tag)
				{
					case 1:
						self.diskA = panel.URLs.firstObject;
						break;

					case 2:
						self.diskB = panel.URLs.firstObject;
						break;
				}
			}
		}
		else
		{
			@synchronized(self.computer)
			{
				switch (menuItem.tag)
				{
					case 1:

						if (self.diskA != nil)
						{
							[self.computer registerUndoWithMenuItem:menuItem];
							self.diskA = nil;
						}

						break;

					case 2:

						if (self.diskB != nil)
						{
							[self.computer registerUndoWithMenuItem:menuItem];
							self.diskB = nil;
						}

						break;
				}
			}
		}
	}
}

@end
