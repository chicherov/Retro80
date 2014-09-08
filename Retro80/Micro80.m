#import "Micro80.h"
#import "Sound.h"

// -----------------------------------------------------------------------------
// Интерфейс сопряжения "Микро-80"
// -----------------------------------------------------------------------------

@implementation Micro80Recorder

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	self.output = data != 0x00;
}

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	return self.input;
}

@end

// -----------------------------------------------------------------------------
// Интерфейс клавиатуры "Микро-80"
// -----------------------------------------------------------------------------

@implementation Micro80Keyboard

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	[super WR:addr ^ 3 byte:data CLK:clock];
}

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock status:(uint8_t)status
{
	return [super RD:addr ^ 3 CLK:clock status:status];
}

- (id) init
{
	if (self = [super init])
	{
		kbdmap = @[@124, @123, @126, @125, @36,  @117, @115, @999,
				   @6,   @33,  @42,  @30,  @39,  @10,  @49,  @999,
				   @1,   @17,  @32,  @9,   @13,  @7,   @16,  @999,
				   @37,  @46,  @45,  @31,  @35,  @12,  @15,  @999,
				   @14,  @3,   @5,   @4,   @34,  @38,  @40,  @999,
				   @47,  @44,  @41,  @0,   @11,  @8,   @2,   @999,
				   @26,  @28,  @25,  @24,  @50,  @43,  @27,  @999,
				   @29,  @18,  @19,  @20,  @21,  @23,  @22,  @999
				   ];

		RUSLAT = 0x01;
		SHIFT = 0x04;
		CTRL = 0x02;
	}

	return self;
}

@end

// -----------------------------------------------------------------------------
// ПЭВМ "Микро-80"
// -----------------------------------------------------------------------------

@implementation Micro80

+ (NSString *) title
{
	return @"Микро-80";
}

// -----------------------------------------------------------------------------
// Управление компьютером
// -----------------------------------------------------------------------------

- (void) start
{
	[self.snd start];
}

- (void) reset
{
	[self stop];

	if (self.snd.isInput)
		[self.snd close];

	self.cpu.PC = 0xF800;
	self.cpu.IF = FALSE;

	[self start];
}

- (void) stop
{
	[self.snd stop];
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
	if ((self.cpu = [[X8080 alloc] initWithQuartz:18000000]) == nil)
		return FALSE;

	if ((self.ram = [[RAM alloc] initWithLength:0xF800 mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.crt = [[TextScreen alloc] init]) == nil)
		return FALSE;

	if ((self.kbd = [[Micro80Keyboard alloc] init]) == nil)
		return FALSE;

	return TRUE;
}

- (BOOL) mapObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Micro80" mask:0x07FF]) == nil)
		return FALSE;

	if ((self.snd = [[Micro80Recorder alloc] init]) == nil)
		return FALSE;

	self.snd.cpu = self.cpu;

	self.cpu.HOLD = self.crt;

	[self.cpu mapObject:self.ram atPage:0x00 count:0xF8];
	[self.cpu mapObject:self.rom atPage:0xF8 count:0x08];

	[self.cpu mapObject:self.crt atPage:0xE0 count:0x10];

	[self.cpu mapObject:self.snd atPort:0x00 count:0x02];
	[self.cpu mapObject:self.kbd atPort:0x04 count:0x04];

	[self.cpu mapHook:self.kbdHook = [[F812 alloc] initWithRKKeyboard:self.kbd] atAddress:0xF812];
	[self.cpu mapHook:[[F803 alloc] initWithF812:self.kbdHook] atAddress:0xF803];

	[self.cpu mapHook:self.inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xF806];
	self.inpHook.extension = @"rk8";

	[self.cpu mapHook:self.outHook = [[F80C alloc] init] atAddress:0xF80C];
	self.outHook.extension = @"rk8";
	self.outHook.Micro80 = TRUE;

	return TRUE;
}

- (id) init
{
	if (self = [super init])
	{
		if (![self createObjects])
			return self = nil;

		if (![self mapObjects])
			return self = nil;

		self.cpu.PC = 0xF800;

		self.kbdHook.enabled = TRUE;
		self.inpHook.enabled = TRUE;
		self.outHook.enabled = TRUE;
	}

	return self;
	
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:self.cpu forKey:@"cpu"];
	[encoder encodeObject:self.ram forKey:@"ram"];
	[encoder encodeObject:self.crt forKey:@"crt"];
	[encoder encodeObject:self.kbd forKey:@"kbd"];

	[encoder encodeBool:self.kbdHook.enabled forKey:@"kbdHook"];
	[encoder encodeBool:self.inpHook.enabled forKey:@"inpHook"];
	[encoder encodeBool:self.outHook.enabled forKey:@"outHook"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if ((self.cpu = [decoder decodeObjectForKey:@"cpu"]) == nil)
		return self = nil;

	if ((self.ram = [decoder decodeObjectForKey:@"ram"]) == nil)
		return self = nil;

	if ((self.crt = [decoder decodeObjectForKey:@"crt"]) == nil)
		return self = nil;

	if ((self.kbd = [decoder decodeObjectForKey:@"kbd"]) == nil)
		return self = nil;

	if (![self mapObjects])
		return self = nil;

	self.kbdHook.enabled = [decoder decodeBoolForKey:@"kbdHook"];
	self.inpHook.enabled = [decoder decodeBoolForKey:@"inpHook"];
	self.outHook.enabled = [decoder decodeBoolForKey:@"outHook"];

	return self;
}

@end
