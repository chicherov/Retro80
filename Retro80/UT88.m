/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «ЮТ-88»

 *****/

#import "UT88.h"

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
		menuItem.hidden = menuItem.tag < 1 || menuItem.tag > 4;

		switch (menuItem.tag)
		{
			case 1:	// Монитор 0

				menuItem.state = self.cpu.PAGE & 0x01;
				return YES;

			case 2:	// Монитор F

                menuItem.state = self.cpu.PAGE & 0x02;
				return YES;

			case 3:	// RAM диск

				menuItem.state = self.ram.length > 0x10000;
				return YES;
		}
	}

    if (menuItem.action == @selector(ROMDisk:) && menuItem.tag == 0)
    {
        NSURL *url = [self.ext URL]; if ((menuItem.state = url != nil))
            menuItem.title = [((NSString *)[menuItem.title componentsSeparatedByString:@":"].firstObject) stringByAppendingFormat:@": %@", url.lastPathComponent];
        else
            menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;
        
        menuItem.submenu = nil;
        return YES;
    }

    return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Монитор 0/Монитор F/RAM диск
// -----------------------------------------------------------------------------

- (IBAction)UT88:(NSMenuItem *)menuItem
{
	@synchronized(self.cpu)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		switch (menuItem.tag)
		{
			case 1:
                
                self.cpu.PAGE ^= 0x01;
				break;

			case 2:

                self.cpu.PAGE ^= 0x02;
				break;

			case 3:
            {
                RAM *ram = [[RAM alloc] initWithLength:self.ram.length == 0x10000 ? 0x50000 : 0x10000 mask:0xFFFF];
                memcpy(ram.mutableBytes, self.ram.mutableBytes, 0x10000);
                self.ram = ram; [self mapObjects];
            }

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
// reset
// -----------------------------------------------------------------------------

- (IBAction) reset:(NSMenuItem *)menuItem
{
	@synchronized(self.cpu)
	{
		[self.document registerUndoWithMenuItem:menuItem];

        uint8_t page = self.cpu.PAGE; [self.cpu reset];

        if ((self.cpu.PAGE = page) & 0x01)
            self.cpu.PC = 0x0000;
	}
}


// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:16000000 start:0x2F800]) == nil)
		return FALSE;

    if (self.monitor0 == nil && (self.monitor0 = [[ROM alloc] initWithContentsOfResource:@"UT88-0" mask:0x03FF]) == nil)
        return FALSE;
    
    if (self.monitorF == nil && (self.monitorF = [[ROM alloc] initWithContentsOfResource:@"UT88-F" mask:0x07FF]) == nil)
        return FALSE;
    
	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x10000 mask:0xFFFF]) == nil)
		return FALSE;

	if (self.kbd == nil && (self.kbd = [[UT88Keyboard alloc] init]) == nil)
		return FALSE;

	if (self.crt == nil && (self.crt = [[UT88Screen alloc] init]) == nil)
		return FALSE;
    
    if (self.ext == nil && (self.ext = [[ROMDisk alloc] init]) == nil)
        return FALSE;

    if (self.snd == nil && (self.snd = [[X8253 alloc] init]) == nil)
        return FALSE;
    
    self.snd.channel0 = TRUE;
    self.snd.channel1 = TRUE;
    self.snd.channel2 = TRUE;

	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	if (self.sys == nil && (self.sys = [[UT88Port40 alloc] init]) == nil)
		return FALSE;
    
	self.sys.cpu = self.cpu;

    self.crt.ram = self.ram;
    
	self.cpu.IRQ = self.crt;
	self.cpu.RST = 0xFF;
	self.cpu.FF = TRUE;
    
    self.kbd.snd = self.snd;
    
    [self.cpu mapObject:self.ram atPage:0 from:0x0000 to:0xFFFF];
    [self.cpu mapObject:self.ram atPage:1 from:0x0000 to:0xFFFF];
    [self.cpu mapObject:self.ram atPage:2 from:0x0000 to:0xFFFF];
    [self.cpu mapObject:self.ram atPage:3 from:0x0000 to:0xFFFF];

    // 0000-0FFF
    
    [self.cpu mapObject:self.monitor0 atPage:1 from:0x0000 to:0x0FFF WR:nil];
    [self.cpu mapObject:self.monitor0 atPage:3 from:0x0000 to:0x0FFF WR:nil];

	// 9000-9FFF

    [self.cpu mapObject:self.crt atPage:0 from:0x9000 to:0x9FFF RD:self.ram];
    [self.cpu mapObject:self.crt atPage:1 from:0x9000 to:0x9FFF RD:self.ram];
    [self.cpu mapObject:self.crt atPage:2 from:0x9000 to:0x9FFF RD:self.ram];
    [self.cpu mapObject:self.crt atPage:3 from:0x9000 to:0x9FFF RD:self.ram];
    
	// E800-EFFF

    [self.cpu mapObject:self.crt atPage:0 from:0xE800 to:0xEFFF RD:self.ram];
    [self.cpu mapObject:self.crt atPage:1 from:0xE800 to:0xEFFF RD:self.ram];
    [self.cpu mapObject:self.crt atPage:2 from:0xE800 to:0xEFFF RD:self.ram];
    [self.cpu mapObject:self.crt atPage:3 from:0xE800 to:0xEFFF RD:self.ram];

	// F800-FFFF

    [self.cpu mapObject:self.monitorF atPage:2 from:0xF800 to:0xFFFF WR:nil];
    [self.cpu mapObject:self.monitorF atPage:3 from:0xF800 to:0xFFFF WR:nil];

    if (self.inpHook == nil)
    {
        self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
        self.inpHook.mem = self.monitorF;
        self.inpHook.snd = self.snd;
        
        self.inpHook.extension = @"rku";
        self.inpHook.type = 4;
        
        self.inpHook.enabled = TRUE;
    }

    [self.cpu mapObject:self.inpHook atPage:2 from:0xFF69 to:0xFF69 WR:nil];
    [self.cpu mapObject:self.inpHook atPage:3 from:0xFF69 to:0xFF69 WR:nil];
    
    if (self.outHook == nil)
    {
        self.outHook = [[F80C alloc] initWithX8080:self.cpu];
        self.outHook.mem = self.monitorF;
        self.outHook.snd = self.snd;
        
        self.outHook.extension = @"rku";
        self.outHook.type = 4;
        
        self.outHook.enabled = TRUE;
    }

    [self.cpu mapObject:self.outHook atPage:2 from:0xFF77 to:0xFF77 WR:nil];
    [self.cpu mapObject:self.outHook atPage:3 from:0xFF77 to:0xFF77 WR:nil];

    [self.cpu mapObject:self.kbd atPort:0x04 count:0x04];
    [self.cpu mapObject:self.snd atPort:0x50 count:0x10];
	[self.cpu mapObject:self.crt atPort:0x90 count:0x10];
    [self.cpu mapObject:self.kbd atPort:0xA0 count:0x02];
    [self.cpu mapObject:self.ext atPort:0xF8 count:0x04];

	if (self.ram.length > 0x10000)
	{
		[self.cpu mapObject:self.sys atPort:0x40 count:0x01];

		for (unsigned page = 4; page <= 7; page++)
			[self.cpu mapObject:[self.ram memoryAtOffest:page << 16 length:0x10000 mask:0xFFFF]
						 atPage:page from:0x0000 to:0xFFFF];
	}
	else
	{
		[self.cpu mapObject:nil atPort:0x40 count:0x10];
	}

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
    
    if ((self.ext = [decoder decodeObjectForKey:@"ext"]) == nil)
        return FALSE;

    if ((self.snd = [decoder decodeObjectForKey:@"snd"]) == nil)
        return FALSE;
    
    return TRUE;
}

@end
