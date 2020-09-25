/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Адаптер SD-CARD для Специалист

 *****/

#import "SpecialistSDCard.h"
#import "RKRecorder.h"

@implementation SpecialistSDCard

- (BOOL)validateFile:(NSURL *)url error:(NSError **)outError
{
	return NO;
}

- (NSString *)sdbiosrk
{
	return @"boot/sdbios.rks";
}

- (NSString *)bootrk
{
	return @"boot/boot.rks";
}

- (uint8_t)A
{
	return 0xFF;
}

- (uint8_t)C
{
	return sdcard ? out : 0xFF;
}

- (void)setB:(uint8_t)data
{
	switch (sdcard)
	{
		case 1:

			if ((B & 0x80) && (data & 0x80) == 0x00)
				sdcard = C == 0x13 ? 2 : 1;

			break;

		case 2:

			if ((B & 0x80) && (data & 0x80) == 0x00)
				sdcard = C == 0xB4 ? 3 : 1;

			break;

		case 3:

			if ((B & 0x80) && (data & 0x80) == 0x00)
				sdcard = C == 0x57 ? 4 : 1;

			break;

		case 4:

			if ((B & 0x80) && (data & 0x80) == 0x00)
			{
				request[0] = C;

				buffer = nil;
				pos = 0;

				out = ERR_START;
				sdcard++;
			}

			break;

		case 5:

			if ((B & 0x80) && (data & 0x80) == 0x00)
			{
				uint8_t err; if ((err = [self execute:request[0]]))
					buffer = [NSMutableData dataWithBytes:&err length:1];

				if (buffer.length)
				{
					sdcard = 8;
					pos = 0;
				}
				else
				{
					sdcard++;
				}
			}

			break;

		case 6:

			if ((B & 0x80) && (data & 0x80) == 0x00)
			{
				if (out != ERR_OK_DISK)
					out = ERR_OK_DISK;
				else
					sdcard++;
			}

			break;

		case 7:

			if ((B & 0x80) && (data & 0x80) == 0x00)
			{
				uint8_t err; if ((err = [self execute:C]))
					buffer = [NSMutableData dataWithBytes:&err length:1];

				if (buffer)
				{
					sdcard = 8;
					pos = 0;
				}
			}

			break;

		case 8:

			if ((B & 0x80) && (data & 0x80) == 0x00)
			{
				if (pos < buffer.length && mode.H && mode.L)
					[buffer getBytes:&out range:NSMakeRange(pos++, 1)];
				else
					sdcard = 1;
			}

			break;
	}
}

- (uint8_t)sendFileHandle:(NSFileHandle *)fileHandle length:(uint16_t)length
{
	if (fileHandle == nil)
		return ERR_NOT_OPENED;

	NSData *data = [fileHandle readDataOfLength:length];

	char header[3];
	header[0] = 0x00;
	header[1] = (uint8_t) (data.length & 0xFF);
	header[2] = (uint8_t) (data.length >> 8);

	if (buffer == nil)
		buffer = [NSMutableData dataWithCapacity:length + 4];

	[buffer appendBytes:header length:3];
	[buffer appendData:data];

	header[0] = ERR_OK_READ;
	[buffer appendBytes:header length:1];

	return ERR_OK;
}

- (uint8_t)sendRKFileHandle:(NSFileHandle *)fileHandle
{
	if (fileHandle == nil)
		return ERR_NOT_OPENED;

	NSData* data = [fileHandle readDataOfLength:4];

	if (data && data.length == 4)
	{
		const uint8_t *ptr = (const uint8_t *)data.bytes;

		char header[3];
		header[0] = ERR_OK_RKS;
		header[1] = ptr[0];
		header[2] = ptr[1];

		uint16_t length = ((ptr[3] << 8) | ptr[2]) - ((ptr[1] << 8) | ptr[0]) + 1;
		buffer = [NSMutableData dataWithCapacity:length + 7];
		[buffer appendBytes:header length:3];

		return [self sendFileHandle:fileHandle length:length];
	}
	else
	{
		buffer = [NSMutableData dataWithCapacity:4];
		return [self sendFileHandle:fileHandle length:0];
	}
}

- (void)RESET:(uint64_t)clock
{
	if (sdcard && self.computer.inpHook.enabled)
	{
		if ([self.computer.inpHook isKindOfClass:F806.class])
		{
			[(F806 *)self.computer.inpHook setBuffer:self.rom];
			[(F806 *)self.computer.inpHook setPos:0];
		}
	}

	[super RESET:clock];
}

@end
