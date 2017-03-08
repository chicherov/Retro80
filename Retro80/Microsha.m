/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Микроша»

 *****/

#import "Microsha.h"

@implementation Microsha

+ (NSString *) title
{
	return @"Микроша";
}

+ (NSArray *) extensions
{
	return @[@"rkm"];
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(colorModule:))
	{
		menuItem.state = self.isColor;
		return YES;
	}

	if (menuItem.action == @selector(extraMemory:))
	{
		if (menuItem.tag == 0)
		{
			menuItem.state = self.ram.length == 0xC000;
			return YES;
		}
	}

    if (menuItem.action == @selector(floppy:))
    {
        if (menuItem.tag == 0)
        {
            menuItem.state = self.cpu.PAGE == 1;
            return YES;
        }
        else
        {
            NSURL *url = self.cpu.PAGE == 1 ? [self.fdd getDisk:menuItem.tag] : nil; if ((menuItem.state = url != nil))
                menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingFormat:@": %@", url.lastPathComponent];
            else
                menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingString:@":"];
            
            return self.cpu.PAGE == 1 && menuItem.tag != [self.fdd selected];
        }
    }
    
	return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Модуль цветности
// -----------------------------------------------------------------------------

static uint32_t colors[] =
{
	0xFFFFFFFF, 0xFFFF00FF, 0xFFFFFFFF, 0xFFFF00FF,
	0xFFFFFF00, 0xFFFF0000, 0xFFFFFF00, 0xFFFF0000,
	0xFF00FFFF, 0xFF0000FF, 0xFF00FFFF, 0xFF0000FF,
	0xFF00FF00, 0xFF000000, 0xFF00FF00, 0xFF000000
};

- (IBAction) colorModule:(NSMenuItem *)menuItem
{
	[self.document registerUndoWithMenuItem:menuItem];

	if ((self.isColor = !self.isColor))
	{
		if (self.rom.length > 0x42 && self.rom.mutableBytes[0x42] == 0x93)
			self.rom.mutableBytes[0x42] = 0xD3;

		[self.crt setColors:colors attributesMask:0x3F shiftMask:0x22];
	}
	else
	{
		if (self.rom.length > 0x42 && self.rom.mutableBytes[0x42] == 0xD3)
			self.rom.mutableBytes[0x42] = 0x93;

		[self.crt setColors:NULL attributesMask:0x22 shiftMask:0x22];
	}
}

// -----------------------------------------------------------------------------
// Модуль ОЗУ
// -----------------------------------------------------------------------------

- (IBAction) extraMemory:(NSMenuItem *)menuItem
{
	@synchronized(self.cpu)
	{
		[self.document registerUndoWithMenuItem:menuItem];

        self.ram.length ^= 0x4000;
	}
}

// -----------------------------------------------------------------------------
// Модуль НГМД
// -----------------------------------------------------------------------------

- (IBAction) floppy:(NSMenuItem *)menuItem;
{
    if (menuItem.tag == 0) @synchronized(self.cpu)
    {
        [self.document registerUndoWithMenuItem:menuItem];

        if (self.cpu.PAGE == 1)
        {
            self.cpu.START = 0x0F800;
            self.cpu.PAGE = 0;
        }

        else
        {
            self.cpu.START = 0x1F800;
            self.cpu.PAGE = 1;
        }
    }

    else if (self.cpu.PAGE == 1)
    {
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.allowedFileTypes = @[@"rkdisk"];
        panel.canChooseDirectories = FALSE;
        panel.title = menuItem.title;

        if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
        {
            [self.document registerUndoWithMenuItem:menuItem];
            [self.fdd setDisk:menuItem.tag URL:panel.URLs.firstObject];
        }
        else if ([self.fdd getDisk:menuItem.tag] != nil)
        {
            [self.document registerUndoWithMenuItem:menuItem];
            [self.fdd setDisk:menuItem.tag URL:nil];
        }
    }
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
    if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Microsha" mask:0x07FF]) == nil)
        return FALSE;

    if (self.crt == nil)
    {
        if ((self.crt = [[X8275 alloc] init]) == nil)
            return FALSE;

        [self.crt selectFont:0x0C00];
    }

    if ((self.kbd = [[MicroshaKeyboard alloc] init]) == nil)
        return FALSE;

    if ((self.ext = [[MicroshaExt alloc] init]) == nil)
        return FALSE;

    if (![super createObjects])
        return FALSE;

    if (self.fdd == nil && (self.fdd = [[Floppy alloc] init]) == nil)
        return FALSE;

    if (self.dos == nil)
    {
        if ((self.dos = [[ROM alloc] initWithContentsOfResource:@"dos29" mask:0x0FFF]) == nil)
            return FALSE;

        if (self.dos.length > 0xDBF && self.dos.mutableBytes[0xDBF] == 0xC1)
            self.dos.mutableBytes[0xDBF] = 0xD1;
    }

    return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
    if (self.isColor)
        [self.crt setColors:colors attributesMask:0x3F shiftMask:0x22];
    else
        [self.crt setColors:NULL attributesMask:0x22 shiftMask:0x22];

    self.ext.crt = self.crt;

    if (self.inpHook == nil)
    {
        self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
        self.inpHook.mem = self.rom;
        self.inpHook.snd = self.snd;

        self.inpHook.extension = @"rkm";
        self.inpHook.type = 2;
    }

    if (self.outHook == nil)
    {
        self.outHook = [[MicroshaF80C alloc] initWithX8080:self.cpu];
        self.outHook.mem = self.rom;
        self.outHook.snd = self.snd;

        self.outHook.extension = @"rkm";
        self.outHook.type = 2;
    }

    for (uint8_t page = 0; page <= 1; page++)
    {
        [self.cpu mapObject:self.ram atPage:page from:0x0000 to:0xBFFF];
        [self.cpu mapObject:self.kbd atPage:page from:0xC000 to:0xC7FF];
        [self.cpu mapObject:self.ext atPage:page from:0xC800 to:0xCFFF];
        [self.cpu mapObject:self.crt atPage:page from:0xD000 to:0xD7FF];
        [self.cpu mapObject:self.snd atPage:page from:0xD800 to:0xDFFF];
        
        [self.cpu mapObject:self.rom atPage:page from:0xF800 to:0xFFFF WR:self.dma];
        [self.cpu mapObject:self.inpHook from:0xFC0D to:0xFC0D WR:self.dma];
        [self.cpu mapObject:self.outHook from:0xFCAB to:0xFCAB WR:self.dma];
        [self.cpu mapObject:self.outHook from:0xF89A to:0xF89A WR:self.dma];

        if (page)
        {
            [self.cpu mapObject:self.dos atPage:1 from:0xE000 to:0xEFFF WR:nil];
            [self.cpu mapObject:self.fdd atPage:1 from:0xF000 to:0xF7FF];
        }
    }

    return [super mapObjects];
}

// -----------------------------------------------------------------------------
// encodeWithCoder/decodeWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
    [super encodeWithCoder:encoder];

    [encoder encodeObject:self.fdd forKey:@"fdd"];
    [encoder encodeObject:self.dos forKey:@"dos"];
}

// -----------------------------------------------------------------------------

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
    if (![super decodeWithCoder:decoder])
        return FALSE;

    if ((self.fdd = [decoder decodeObjectForKey:@"fdd"]) == nil)
        return FALSE;

    if ((self.dos = [decoder decodeObjectForKey:@"dos"]) == nil)
        return FALSE;
    
    return TRUE;
}

@end

// -----------------------------------------------------------------------------
// Вывод байта на магнитофон (Микроша)
// -----------------------------------------------------------------------------

@implementation MicroshaF80C
{
	BOOL disable;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if (self.cpu.M1 && (addr == 0xF89A || disable))
	{
		disable = addr == 0xF89A; [self.mem RD:addr data:data CLK:clock];
	}

	else
	{
		[super RD:addr data:data CLK:clock];
	}
}

@end
