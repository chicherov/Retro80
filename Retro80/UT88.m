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
	if (menuItem.action == @selector(extraMemory:))
	{
		menuItem.state = self.ram.length != 0x10000;
		return YES;
	}

	if (menuItem.action == @selector(monitorROM:))
	{
		menuItem.state = self.isMonitor;
		menuItem.hidden = FALSE;
		return YES;
	}

	return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Модуль ОЗУ
// -----------------------------------------------------------------------------

- (IBAction) extraMemory:(NSMenuItem *)menuItem
{
	UT88RAM *ram = [[UT88RAM alloc] initWithLength:self.ram.length == 0x10000 ? 0x50000 : 0x10000 mask:0xFFFF];

	if (ram) @synchronized(self.snd.sound)
	{
		[self.document registerUndoWithMenuItem:menuItem];

		memcpy(ram.mutableBytes, self.ram.mutableBytes, 0x10000);
		self.ram = ram; [self mapObjects];
	}
}

// -----------------------------------------------------------------------------
// ПЗУ монитора
// -----------------------------------------------------------------------------

- (IBAction)monitorROM:(NSMenuItem *)menuItem
{
	@synchronized(self.snd.sound)
	{
		[self.document registerUndoWithMenuItem:menuItem];
		self.isMonitor = !self.isMonitor;
		[self mapObjects];
	}
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"UT88" mask:0x07FF]) == nil)
		return FALSE;

	self.isMonitor = TRUE;

	if (self.ram == nil && (self.ram = [[UT88RAM alloc] initWithLength:0x10000 mask:0xFFFF]) == nil)
		return FALSE;

	return [super createObjects];
}

- (BOOL) mapObjects
{
	if (self.snd == nil && (self.snd = [[Micro80Recorder alloc] init]) == nil)
		return FALSE;

	if (self.crt == nil && (self.crt = [[Micro80Screen alloc] init]) == nil)
		return FALSE;

	self.crt.memory = self.ram.mutableBytes + 0xE800;
	self.crt.cursor = self.ram.mutableBytes + 0xE800;
	self.crt.rows = 28;

	if (self.sys == nil && (self.sys = [[UT88Port40 alloc] init]) == nil)
		return FALSE;

	self.sys.ram = self.ram;

	if (self.inpHook == nil)
	{
		self.inpHook = [[F806 alloc] initWithX8080:self.cpu];
		self.inpHook.mem = self.rom;
		self.inpHook.snd = self.snd;

		self.inpHook.extension = @"rku";
		self.inpHook.type = 1;
	}

	if (self.outHook == nil)
	{
		self.outHook = [[F80C alloc] initWithX8080:self.cpu];
		self.outHook.mem = self.rom;
		self.outHook.snd = self.snd;

		self.outHook.extension = @"rku";
		self.outHook.type = 1;
	}

	[self.cpu mapObject:self.ram from:0x0000 to:0xF7FF];

	if (self.isMonitor)
	{
		[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF WR:nil];
		[self.cpu mapObject:self.inpHook from:0xFB71 to:0xFB71 WR:nil];
		[self.cpu mapObject:self.outHook from:0xFBEE to:0xFBEE WR:nil];
	}
	else
	{
		[self.cpu mapObject:self.ram from:0xF800 to:0xFFFF];
	}

	[self.cpu mapObject:self.snd atPort:0xA1 count:0x01];
	[self.cpu mapObject:self.kbd atPort:0x04 count:0x04];
	[self.cpu mapObject:self.sys atPort:0x40 count:0x01];

	return TRUE;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	[encoder encodeBool:self.isMonitor forKey:@"isMonitor"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	self.isMonitor = [decoder decodeBoolForKey:@"isMonitor"];
	return [super initWithCoder:decoder];
}

@end

// -----------------------------------------------------------------------------
// UT88RAM
// -----------------------------------------------------------------------------

@implementation UT88RAM
{
	NSUInteger offset;
}

@synthesize page;

- (void) SYNC:(uint16_t)addr status:(uint8_t)status
{
	if (!(status & 0x04) || (offset = page << 16) >= length)
		offset = 0;
}

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	*data = mutableBytes[addr + offset];
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	mutableBytes[addr + offset] = data;
}

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];
	[encoder encodeInt:page forKey:@"page"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
		page = [decoder decodeIntForKey:@"page"];

	return self;
}

@end

@implementation UT88Port40

@synthesize ram;

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
}

- (void) WR:(uint16_t)addr data:(uint8_t)data CLK:(uint64_t)clock
{
	ram.page = data & 0x08 ? data & 0x04 ? data & 0x02 ? data & 0x01 ? 0 : 1 : 2 : 3 : 4;
}

@end