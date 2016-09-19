/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 ПЭВМ «Микро-80»

 *****/

#import "Micro80.h"

// -----------------------------------------------------------------------------

@implementation Micro80

+ (NSString *) title
{
	return @"Микро-80";
}

+ (NSArray *) extensions
{
	return @[@"rk8"];
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.cpu == nil && (self.cpu = [[X8080 alloc] initWithQuartz:18000000 start:0xF800]) == nil)
		return FALSE;

	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"Micro80" mask:0x07FF]) == nil)
		return FALSE;

	if (self.ram == nil && (self.ram = [[RAM alloc] initWithLength:0x10000 mask:0xFFFF]) == nil)
		return FALSE;

	if (self.crt == nil && (self.crt = [[Micro80Screen alloc] init]) == nil)
		return FALSE;

	if (self.kbd == nil && (self.kbd = [[Micro80Keyboard alloc] init]) == nil)
		return FALSE;

	return TRUE;
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
	if (self.snd == nil && (self.snd = [[Micro80Recorder alloc] init]) == nil)
		return FALSE;

    self.crt.ram = self.ram;
    
	[self.cpu mapObject:self.ram from:0x0000 to:0xDFFF];
    [self.cpu mapObject:self.crt from:0xE000 to:0xEFFF RD:self.ram];
	[self.cpu mapObject:self.ram from:0xF000 to:0xF7FF];
	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF WR:nil];

    if (self.inpHook == nil)
    {
        self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
        self.inpHook.mem = self.rom;
        self.inpHook.snd = self.snd;
        
        self.inpHook.extension = @"rk8";
    }
    
    if (self.outHook == nil)
    {
        self.outHook = [[F80C alloc] initWithX8080:self.cpu];
        self.outHook.mem = self.rom;
        self.outHook.snd = self.snd;
        
        self.outHook.extension = @"rk8";
    }
    
    uint16_t F806 = (self.rom.mutableBytes[0x08] << 8) | self.rom.mutableBytes[0x07];
    [self.cpu mapObject:self.inpHook from:F806 to:F806 WR:nil];

    uint16_t F80C = (self.rom.mutableBytes[0x0E] << 8) | self.rom.mutableBytes[0x0D];
    [self.cpu mapObject:self.outHook from:F80C to:F80C WR:nil];
    
	[self.cpu mapObject:self.snd atPort:0x00 count:0x02];
	[self.cpu mapObject:self.kbd atPort:0x04 count:0x04];

	return TRUE;
}

// -----------------------------------------------------------------------------

- (id) initWithType:(NSInteger)type
{
    if (type == 2)
        return self = [[Micro80II alloc] initWithType:0];
    else
        return [super initWithType:0];
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
	[encoder encodeObject:self.rom forKey:@"rom"];
	[encoder encodeObject:self.ram forKey:@"ram"];
	[encoder encodeObject:self.crt forKey:@"crt"];
	[encoder encodeObject:self.kbd forKey:@"kbd"];
}

// -----------------------------------------------------------------------------

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
	if (![super decodeWithCoder:decoder])
		return FALSE;

	if ((self.cpu = [decoder decodeObjectForKey:@"cpu"]) == nil)
		return FALSE;

	if ((self.rom = [decoder decodeObjectForKey:@"rom"]) == nil)
		return FALSE;

	if ((self.ram = [decoder decodeObjectForKey:@"ram"]) == nil)
		return FALSE;

	if ((self.crt = [decoder decodeObjectForKey:@"crt"]) == nil)
		return FALSE;

	if ((self.kbd = [decoder decodeObjectForKey:@"kbd"]) == nil)
		return FALSE;

	return TRUE;
}

@end
