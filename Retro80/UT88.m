/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «ЮТ-88»

 *****/

#import "UT88.h"

// -----------------------------------------------------------------------------

@implementation UT88

+ (NSString *) title
{
	return @"ЮТ-88";
}

+ (NSArray *) extensions
{
	return @[@"rku"];
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(UT88:))
	{
		switch (menuItem.tag)
		{
			case 1:	// Монитор 0

				menuItem.state = (self.cpu.PAGE & 0x01) != 0;
                menuItem.hidden = FALSE;
				return YES;

            case 2:	// Монитор F
                
                menuItem.state = (self.cpu.PAGE & 0x02) != 0;
                menuItem.hidden = FALSE;
                return (self.cpu.PAGE & 0x04) != 0;
                
            case 3:	// Дисплейный модуль
                
                menuItem.state = (self.cpu.PAGE & 0x04) != 0;
                menuItem.hidden = FALSE;
                return YES;
                
            case 4: // Старт с F800
                
                menuItem.state = (self.cpu.START & 0xFFFF) == 0xF800;
                menuItem.alternate = TRUE;
                menuItem.hidden = FALSE;
                return YES;
                
            case 5: // Старт с 0000
                
                menuItem.state = (self.cpu.START & 0xFFFF) == 0x0000;
                menuItem.alternate = TRUE;
                menuItem.hidden = FALSE;
                return YES;
                
            default:

                menuItem.state = FALSE;
                menuItem.hidden = TRUE;
                return NO;
		}
	}

    if (menuItem.action == @selector(extraMemory:))
    {
        switch (menuItem.tag)
        {
            case 1:
            {
                menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;

                if (self.ram.length > 0x10800)
                    menuItem.title = [menuItem.title stringByAppendingFormat:@": 64K + %luK", (self.ram.length >> 10) - 66];
                else if (self.ram.length == 0x10800)
                    menuItem.title = [menuItem.title stringByAppendingString:@": 64K"];
                else if (self.ram.length == 0x1800)
                    menuItem.title = [menuItem.title stringByAppendingString:@": 4K"];
                
                menuItem.state = FALSE;
                break;
            }
                
                
            case 2: case 6:
            
                menuItem.state = self.ram.length == menuItem.tag * 1024;
                break;

            case 64000: case 64064: case 64128: case 64192: case 64256:
                
                menuItem.state = self.ram.length == (66 + menuItem.tag - 64000) * 1024;
                break;
                
            default:
                
                menuItem.state = FALSE;
                menuItem.hidden = TRUE;
                return NO;
        }
        
        menuItem.hidden = FALSE;
        return YES;
    }

    if (menuItem.action == @selector(ROMDisk:))
    {
        if (menuItem.tag == 0)
        {
            NSURL *url = [self.ext URL]; if ((menuItem.state = url != nil))
                menuItem.title = [[menuItem.title componentsSeparatedByString:@":"].firstObject stringByAppendingFormat:@": %@", url.lastPathComponent];
            else
                menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;

            menuItem.hidden = FALSE;
            return YES;
        }
        
        else
        {
            menuItem.state = FALSE;
            menuItem.hidden = TRUE;
            return NO;
        }
    }

    return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Монитор 0, монитор F и дисплейный модуль
// -----------------------------------------------------------------------------

- (IBAction)UT88:(NSMenuItem *)menuItem
{
	@synchronized(self.cpu)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		switch (menuItem.tag)
		{
			case 1:
                
                self.cpu.START = ((self.cpu.PAGE ^= 0x01) << 16) | (self.cpu.START & 0xFFFF);
				break;

			case 2:

                self.cpu.START = ((self.cpu.PAGE ^= 0x02) << 16) | (self.cpu.START & 0xFFFF);
				break;

            case 3:
                
                if (self.cpu.PAGE & 0x04)
                {
                    self.cpu.START = ((self.cpu.PAGE &= ~0x06) << 16) | (self.cpu.START & 0xFFFF);
                    memset(self.crt.mutableBytes, 0x80, 0x800);
                }
                else
                {
                    self.cpu.START = ((self.cpu.PAGE |= 0x06) << 16) | (self.cpu.START & 0xFFFF);
                    memset(self.crt.mutableBytes, 0x01, 0x800);
                }

                break;
                
            case 4:
                
                self.cpu.START = (self.cpu.PAGE << 16) | 0xF800;
                break;
                
            case 5:
                
                self.cpu.START = self.cpu.PAGE << 16;
                break;
                
		}
	}
}

// -----------------------------------------------------------------------------
// Модуль ОЗУ
// -----------------------------------------------------------------------------

- (IBAction) extraMemory:(NSMenuItem *)menuItem
{
    @synchronized(self.cpu)
    {
        NSUInteger newLength = self.ram.length;

        switch (menuItem.tag)
        {
            case 1:
                
                newLength = newLength < 66 * 1024 ? 66 * 1024 : 6 * 1024;
                break;
                
            case 2: case 6:
                
                newLength = menuItem.tag * 1024;
                break;
                
            case 64000: case 64064: case 64128: case 64192: case 64256:
                
                newLength = (66 + menuItem.tag - 64000) * 1024;
                break;
        }
        
        if (self.ram.length != newLength)
        {
            [self.document registerUndoWithMenuItem:menuItem];
            
            if ((self.ram.length = newLength) < 0x10800)
                self.cpu.START = ((self.cpu.PAGE = self.cpu.PAGE & ~0x08) << 16) | (self.cpu.START & 0xFFFF);
            else
                self.cpu.START = ((self.cpu.PAGE = self.cpu.PAGE | 0x08) << 16) | (self.cpu.START & 0xFFFF);
        }
    }
}

// -----------------------------------------------------------------------------
// Внешний ROM-диск
// -----------------------------------------------------------------------------

- (IBAction) ROMDisk:(NSMenuItem *)menuItem;
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"rom", @"bin"];
    panel.canChooseDirectories = TRUE;
    panel.title = menuItem.title;
    panel.delegate = self.ext;
    
    if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
    {
        [self.document registerUndoWithMenuItem:menuItem];
        self.ext.URL = panel.URLs.firstObject;
    }
    else if (self.ext.URL != nil)
    {
        [self.document registerUndoWithMenuItem:menuItem];
        self.ext.URL = nil;
    }
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:16000000 start:0xEF800]) == nil)
            return FALSE;
        
    if (self.monitor0 == nil && (self.monitor0 = [[ROM alloc] initWithContentsOfResource:@"UT88-0" mask:0x03FF]) == nil)
        return FALSE;

    if (self.monitorF == nil && (self.monitorF = [[ROM alloc] initWithContentsOfResource:@"UT88-F" mask:0x07FF]) == nil)
        return FALSE;

	if (self.ram == nil)
    {
        if ((self.ram = [[RAM alloc] initWithLength:0x10800]) == nil)
            return FALSE;

        self.ram.offset = 0x0800;
    }

    if (self.kbd == nil && (self.kbd = [[UT88Keyboard alloc] init]) == nil)
		return FALSE;

	if (self.crt == nil && (self.crt = [[UT88Screen alloc] init]) == nil)
		return FALSE;
    
    if (self.sys == nil && (self.sys = [[UT88System alloc] init]) == nil)
        return FALSE;
    
    if (self.ext == nil && (self.ext = [[ROMDisk alloc] init]) == nil)
        return FALSE;

    if (self.snd == nil)
    {
        if ((self.snd = [[X8253 alloc] init]) == nil)
            return FALSE;
        
        self.snd.channel0 = TRUE;
        self.snd.channel1 = TRUE;
        self.snd.channel2 = TRUE;
    }
    
	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
    self.sys.cpu = self.cpu;
    self.cpu.IRQ = self.sys;
    self.cpu.RST = 0xFF;

    self.crt.mem = self.ram;

    self.kbd.snd = self.snd;
    
    MEM *mem_C000; if ((mem_C000 = [self.ram memoryAtOffest:0x0000 mask:0x03FF]) == nil)
        return FALSE;
    
    MEM *mem_F400; if ((mem_F400 = [self.ram memoryAtOffest:0x0400 mask:0x03FF]) == nil)
        return FALSE;

    MEM *mem_3000; if ((mem_3000 = [self.ram memoryAtOffest:0x0800 mask:0x0FFF]) == nil)
        return FALSE;
    
    MEM *mem_0000; if ((mem_0000 = [self.ram memoryAtOffest:0x1800 mask:0xFFFF]) == nil)
        return FALSE;
    
    if (self.inpHook == nil)
    {
        self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
        self.inpHook.mem = self.monitorF;
        self.inpHook.snd = self.snd;
        
        self.inpHook.extension = @"rku";
        self.inpHook.type = 4;
        
        self.inpHook.enabled = TRUE;
    }

    if (self.outHook == nil)
    {
        self.outHook = [[F80C alloc] initWithX8080:self.cpu];
        self.outHook.mem = self.monitorF;
        self.outHook.snd = self.snd;
        
        self.outHook.extension = @"rku";
        self.outHook.type = 4;
        
        self.outHook.enabled = TRUE;
    }
    
    for (uint8_t page = 0; page < 16; page++)
    {
        if (page & 8)
        {
            [self.cpu mapObject:mem_0000 atPage:page from:0x0000 to:0x2FFF];
            [self.cpu mapObject:self.ram atPage:page from:0x4000 to:0xFFFF];
        }

        else if (page & 1)
            [self.cpu mapObject:mem_C000 atPage:page from:0xC000 to:0xCFFF];
        else
            [self.cpu mapObject:mem_C000 atPage:page from:0x0000 to:0x0FFF];
        
        [self.cpu mapObject:self.crt atPage:page from:0x9000 to:0x9FFF RD:self.ram];
        [self.cpu mapObject:mem_3000 atPage:page from:0x3000 to:0x3FFF];
        
        if (page & 4)
        {
            [self.cpu mapObject:self.crt atPage:page from:0xE000 to:0xEFFF];

            if (page & 2)
            {
                [self.cpu mapObject:self.monitorF atPage:page from:0xF800 to:0xFFFF WR:nil];
                [self.cpu mapObject:self.inpHook atPage:page from:0xFF69 to:0xFF69 WR:nil];
                [self.cpu mapObject:self.outHook atPage:page from:0xFF77 to:0xFF77 WR:nil];
                [self.cpu mapObject:mem_F400 atPage:page from:0xF000 to:0xF7FF];
            }
        }

        if (page & 1)
            [self.cpu mapObject:self.monitor0 atPage:page from:0x0000 to:0x0FFF WR:nil];
    }
    
    [self.cpu mapObject:[self.sys RAMDISK:self.ram] atPage:8 from:0x0000 to:0xFFFF];
    
    [self.cpu mapObject:self.kbd atPort:0x00 count:0x10];
    [self.cpu mapObject:self.sys atPort:0x40 count:0x10];
    [self.cpu mapObject:self.snd atPort:0x50 count:0x10];
//	[self.cpu mapObject:self.crt atPort:0x90 count:0x10];
    [self.cpu mapObject:self.kbd atPort:0xA0 count:0x10];
    [self.cpu mapObject:self.ext atPort:0xF0 count:0x10];

    self.cpu.FF = TRUE;
	return TRUE;
}

// -----------------------------------------------------------------------------

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	if (self = [self initWithType:0])
	{
		self.inpHook.buffer = data;
		[self.kbd paste:@"I\n"];
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/decodeWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];

	[encoder encodeObject:self.cpu forKey:@"cpu"];
    [encoder encodeObject:self.monitor0 forKey:@"monitor0"];
    [encoder encodeObject:self.monitorF forKey:@"monitorF"];

    [encoder encodeObject:self.ram forKey:@"ram"];
	[encoder encodeObject:self.kbd forKey:@"kbd"];
    [encoder encodeObject:self.crt forKey:@"crt"];

    [encoder encodeObject:self.sys forKey:@"sys"];

    [encoder encodeObject:self.ext forKey:@"ext"];
    [encoder encodeObject:self.snd forKey:@"snd"];
}

// -----------------------------------------------------------------------------

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
	if (![super decodeWithCoder:decoder])
		return FALSE;

	if ((self.cpu = [decoder decodeObjectForKey:@"cpu"]) == nil)
		return FALSE;

    if ((self.monitor0 = [decoder decodeObjectForKey:@"monitor0"]) == nil)
        return FALSE;
    
    if ((self.monitorF = [decoder decodeObjectForKey:@"monitorF"]) == nil)
        return FALSE;
    
	if ((self.ram = [decoder decodeObjectForKey:@"ram"]) == nil)
		return FALSE;

	if ((self.kbd = [decoder decodeObjectForKey:@"kbd"]) == nil)
		return FALSE;

    if ((self.crt = [decoder decodeObjectForKey:@"crt"]) == nil)
        return FALSE;
    
    if ((self.sys = [decoder decodeObjectForKey:@"sys"]) == nil)
        return FALSE;
    
    if ((self.ext = [decoder decodeObjectForKey:@"ext"]) == nil)
        return FALSE;

    if ((self.snd = [decoder decodeObjectForKey:@"snd"]) == nil)
        return FALSE;
    
    return TRUE;
}

@end
