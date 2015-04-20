/*******************************************************************************
 ПЭВМ «Микро-80»
 ******************************************************************************/

#import "Micro80.h"

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
	if ((self.cpu = [[X8080 alloc] initWithQuartz:18000000 start:0xF800]) == nil)
		return FALSE;

	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"Micro80" mask:0x07FF]) == nil)
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
	if ((self.snd = [[Micro80Recorder alloc] init]) == nil)
		return FALSE;

	self.crt.WR = self.ram;

	[self.cpu mapObject:self.ram from:0x0000 to:0xDFFF];
	[self.cpu mapObject:self.crt from:0xE000 to:0xEFFF RD:self.ram];
	[self.cpu mapObject:self.ram from:0xF000 to:0xF7FF];
	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF WR:nil];

	[self.cpu mapObject:self.snd atPort:0x00 count:0x02];
	[self.cpu mapObject:self.kbd atPort:0x04 count:0x04];

	[self.cpu mapHook:self.kbdHook = [[F812 alloc] initWithRKKeyboard:self.kbd] atAddress:0xF812];
	[self.cpu mapHook:[[F803 alloc] initWithF812:self.kbdHook] atAddress:0xF803];

	[self.cpu mapHook:self.inpHook = [[F806 alloc] initWithSound:self.snd] atAddress:0xF806];
	self.inpHook.extension = @"rk8";

	[self.cpu mapHook:self.outHook = [[F80C alloc] init] atAddress:0xF80C];
	self.outHook.extension = @"rk8";

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

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	if (self = [self init])
	{
		[self.inpHook setData:data];
		[self.kbd paste:@"I\n"];
	}

	return self;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/initWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
	[super encodeWithCoder:encoder];

	[encoder encodeObject:self.cpu forKey:@"cpu"];
	[encoder encodeObject:self.rom forKey:@"rom"];
	[encoder encodeObject:self.ram forKey:@"ram"];
	[encoder encodeObject:self.crt forKey:@"crt"];
	[encoder encodeObject:self.kbd forKey:@"kbd"];

	[encoder encodeBool:self.kbdHook.enabled forKey:@"kbdHook"];
	[encoder encodeBool:self.inpHook.enabled forKey:@"inpHook"];
	[encoder encodeBool:self.outHook.enabled forKey:@"outHook"];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if (self = [super initWithCoder:decoder])
	{
		if ((self.cpu = [decoder decodeObjectForKey:@"cpu"]) == nil)
			return self = nil;

		if ((self.rom = [decoder decodeObjectForKey:@"rom"]) == nil)
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
	}
	
	return self;
}

@end

// -----------------------------------------------------------------------------
// Интерфейс сопряжения "Микро-80"
// -----------------------------------------------------------------------------

@implementation Micro80Recorder

@synthesize sound;

- (SInt8) sample:(uint64_t)clock
{
	return 0;
}

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock data:(uint8_t)data
{
	return sound.input;
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	sound.output = data != 0x00;
}

@end

// -----------------------------------------------------------------------------
// Интерфейс клавиатуры "Микро-80"
// -----------------------------------------------------------------------------

@implementation Micro80Keyboard

- (uint8_t) RD:(uint16_t)addr CLK:(uint64_t)clock data:(uint8_t)data
{
	return [super RD:addr ^ 3 CLK:clock data:data];
}

- (void) WR:(uint16_t)addr byte:(uint8_t)data CLK:(uint64_t)clock
{
	[super WR:addr ^ 3 byte:data CLK:clock];
}

- (id) init
{
	if (self = [super init])
	{
		kbdmap = @[
				   // 18 08    19    1A    0D    1F    0C    ?
				   @124, @123, @126, @125, @36,  @117, @115, @-1,
				   // 5A 5B    5C    5D    5E    5F    20    ?
				   @35,  @34,  @39,  @31,  @7,   @51,  @49,  @-1,
				   // 53 54    55    56    57    58    59    ?
				   @8,   @45,  @14,  @41,  @2,   @46,  @1,   @-1,
				   // 4C 4D    4E    4F    50    51    52    ?
				   @40,  @9,   @16,  @38,  @5,   @6,   @4,   @-1,
				   // 45 46    47    48    49    4A    4B    ?
				   @17,  @0,   @32,  @33,  @11,  @12,  @15,  @-1,
				   // 2E 2F    40    41    42    43    44    ?
				   @42,  @50,  @47,  @3,   @43,  @13,  @37,  @-1,
				   // 37 38    39    3A    3B    2C    2D    ?
				   @26,  @28,  @25,  @30,  @10,  @44,  @27,  @-1,
				   // 30 31    32    33    34    35    36    ?
				   @29,  @18,  @19,  @20,  @21,  @23,  @22,  @-1
				   ];

		RUSLAT = 0x01;
		SHIFT = 0x04;
		CTRL = 0x02;

		TAPEI = 0x00;
		TAPEO = 0x00;
	}

	return self;
}

@end
