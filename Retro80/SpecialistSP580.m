/*******************************************************************************
 Модификация ПЭВМ «Специалист» с монитором от SP580
 ******************************************************************************/

#import "SpecialistSP580.h"

@implementation SpecialistSP580

+ (NSArray *) extensions
{
	return @[@"sp580"];
}

- (BOOL) createObjects
{
	if ((self.rom = [[ROM alloc] initWithContentsOfResource:@"SpecialistSP580" mask:0x0FFF]) == nil)
		return FALSE;

	if ((self.ram = [[RAM alloc] initWithLength:0x10000 mask:0xFFFF]) == nil)
		return FALSE;

	if ((self.kbd = [[SpecialistSP580Keyboard alloc] init]) == nil)
		return FALSE;

	if ([super createObjects] == FALSE)
		return FALSE;

	self.snd.channel0 = TRUE;
	self.snd.rkmode = TRUE;
	return TRUE;
}

- (BOOL) mapObjects
{
	self.crt.screen = self.ram.mutableBytes + 0x9000;

	if (self.inpHook == nil)
	{
		self.inpHook = [[SpecialistSP580_F806 alloc] initWithX8080:self.cpu];
		self.inpHook.mem = self.rom;
		self.inpHook.snd = self.snd;
	}

	if (self.outHook == nil)
	{
		self.outHook = [[SpecialistSP580_F80C alloc] initWithX8080:self.cpu];
		self.outHook.mem = self.rom;
	}

	[self.cpu mapObject:self.ram from:0x0000 to:0x8FFF];
	[self.cpu mapObject:self.crt from:0x9000 to:0xBFFF RD:self.ram];
	[self.cpu mapObject:self.rom from:0xC000 to:0xC7FF WR:nil];
	[self.cpu mapObject:self.ram from:0xC800 to:0xDFFF];
	[self.cpu mapObject:self.snd from:0xE000 to:0xE7FF];
	[self.cpu mapObject:self.ext from:0xE800 to:0xEFFF];
	[self.cpu mapObject:self.kbd from:0xF000 to:0xF7FF];
	[self.cpu mapObject:self.rom from:0xF800 to:0xFFFF WR:nil];

	[self.cpu mapObject:self.inpHook from:0xFD49 to:0xFD49 WR:nil];
	[self.cpu mapObject:self.inpHook from:0xFDEB to:0xFDEB WR:nil];

	[self.cpu mapObject:self.outHook from:0xFD31 to:0xFD31 WR:nil];
	[self.cpu mapObject:self.outHook from:0xFD9A to:0xFD9A WR:nil];

	self.kbd.crt = self.crt;
	self.kbd.snd = self.snd;
	return TRUE;
}

- (id) initWithData:(NSData *)data URL:(NSURL *)url
{
	if (self = [self init])
	{
		self.inpHook.buffer = data;
		[self.kbd paste:@"I\n"];
	}

	return self;
}

@end

// -----------------------------------------------------------------------------
// Интерфейс клавиатуры ПЭВМ «Специалист» с монитором от SP580
// -----------------------------------------------------------------------------

@implementation SpecialistSP580Keyboard

- (id) init
{
	if (self = [super init])
	{
		kbdmap = @[
				   @53,  @48,  @122, @120, @99,  @118, @96,  @97,  @98,  @109, @103, @117,
				   @10,  @18,  @19,  @20,  @21,  @23,  @22,  @26,  @28,  @25,  @29,  @27,
				   @12,  @13,  @14,  @15,  @17,  @16,  @32,  @34,  @31,  @35,  @33,  @30,
				   @0,   @1,   @2,   @3,   @5,   @4,   @38,  @40,  @37,  @41,  @39,  @42,
				   @6,   @7,   @8,   @9,   @11,  @45,  @46,  @43,  @47,  @44,  @50,  @51,
				   @999, @115, @126, @125, @48,  @53,  @49,  @123, @111, @124, @76,  @36
				   ];

		chr1Map = @"\x1B\t+1234567890-JCUKENG[]ZH:FYWAPROLDV\\.Q^SMITXB@,/_\0\0\0 \x03\r";
		chr2Map = @"\x1B\t;!\"#$%&'()\0=ЙЦУКЕНГШЩЗХ*ФЫВАПРОЛДЖЭ>ЯЧСМИТЬБЮ<?\0\0\0\0 \x03\r";
	}

	return self;
}

@end

// -----------------------------------------------------------------------------
// Интерфейс магнитофона монитора от SP580: F806
// -----------------------------------------------------------------------------

@implementation SpecialistSP580_F806

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if (*data == 0xA2 && self.enabled && !self.snd.sound.isInput)
	{
		if (panel != nil)
		{
			self.cpu.PC--;
			*data = 0x00;
			return;
		}

		if (cancel)
		{
			cancel = FALSE;
		}

		else if (addr == 0xFD49)
		{
			if (self.pos >= self.buffer.length)
			{
				[self performSelectorOnMainThread:@selector(openPanel)
									   withObject:nil
									waitUntilDone:TRUE];

				[self performSelectorOnMainThread:@selector(open)
									   withObject:nil
									waitUntilDone:FALSE];

				self.cpu.PC--;
				*data = 0x00;
				return;
			}

			self.cpu.F &= ~1;
			*data = 0xC9;
			return;
		}

		else if (self.pos < self.buffer.length)
		{
			self.cpu.A = ((const uint8_t *)self.buffer.bytes) [self.pos++];

			self.cpu.F &= ~1;
			*data = 0xC9;
			return;
		}

		self.cpu.F |= 1;
		*data = 0xC9;
		return;
	}

	[self.mem RD:addr data:data CLK:clock];
}

// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		self.extension = @"sp580";
		self.type = 4;
	}

	return self;
}

@end

// -----------------------------------------------------------------------------
// Интерфейс магнитофона монитора от SP580: F80C
// -----------------------------------------------------------------------------

@implementation SpecialistSP580_F80C

- (void) RD:(uint16_t)addr data:(uint8_t *)data CLK:(uint64_t)clock
{
	if (*data == 0xA2 && self.enabled)
	{
		@synchronized(self)
		{
			if (addr == 0xFD31)
			{
				if (self.buffer == nil)
				{
					self.buffer = [NSMutableData data];

					last = [NSProcessInfo processInfo].systemUptime;

					[self performSelectorOnMainThread:@selector(save)
										   withObject:nil
										waitUntilDone:FALSE];
				}
			}
			else if (self.buffer != nil)
			{
				uint8_t byte = self.cpu.C;

				last = [NSProcessInfo processInfo].systemUptime;
				[self.buffer appendBytes:&byte length:1];
			}
			else
			{

			}
		}

		*data = 0xC9;
		return;
	}

	[self.mem RD:addr data:data CLK:clock];
}

// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		self.extension = @"sp580";
		self.type = 4;
	}

	return self;
}

@end
