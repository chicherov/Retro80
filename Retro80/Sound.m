/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Поддеркжа звукового ввода/вывода

 *****/

@import AudioToolbox;
#import "Computer.h"
#import "Sound.h"

@implementation Sound
{
	AudioStreamBasicDescription streamFormat;
	AudioStreamBasicDescription fileFormat;
	AudioQueueRef audioQueue;

	AudioFileID outAudioFile;
	AudioFileID inAudioFile;
	SInt64 audioFilePos;
	SInt64 packetCount;
	BOOL pause;

	AudioConverterRef audioConverter;
	void *audioConverterBuffer;

	unsigned quartz;
	uint64_t frame;

	AudioQueueBufferRef audioQueueBuffer;
	unsigned audioBufferSize;
	SInt16 *audioBufferPtr;

	SInt16 snd_l, snd_r;
	unsigned lastIndex;

	SInt32 s1_l, s1_r;
	SInt32 s2_l, s2_r;
}

@synthesize computer;
@synthesize textField;

static uint32_t filter_diff[2][64] = {
	0x0000, 0x0034, 0x0069, 0x00A1, 0x00DB, 0x0118, 0x015A, 0x01A2,
	0x01EF, 0x0244, 0x02A0, 0x0305, 0x0374, 0x03EE, 0x0474, 0x0506,
	0x05A5, 0x0653, 0x0711, 0x07DE, 0x08BC, 0x09AC, 0x0AAF, 0x0BC5,
	0x0CEF, 0x0E2D, 0x0F81, 0x10EB, 0x126B, 0x1402, 0x15B0, 0x1776,
	0x1953, 0x1B49, 0x1D57, 0x1F7E, 0x21BC, 0x2414, 0x2684, 0x290B,
	0x2BAB, 0x2E63, 0x3131, 0x3417, 0x3713, 0x3A24, 0x3D4B, 0x4086,
	0x43D5, 0x4737, 0x4AAA, 0x4E2F, 0x51C4, 0x5567, 0x5919, 0x5CD7,
	0x60A2, 0x6476, 0x6854, 0x6C39, 0x7026, 0x7418, 0x780D, 0x7C06,
	0x8000, 0x83F9, 0x87F2, 0x8BE7, 0x8FD9, 0x93C6, 0x97AB, 0x9B89,
	0x9F5D, 0xA328, 0xA6E6, 0xAA98, 0xAE3B, 0xB1D0, 0xB555, 0xB8C8,
	0xBC2A, 0xBF79, 0xC2B4, 0xC5DB, 0xC8EC, 0xCBE8, 0xCECE, 0xD19C,
	0xD454, 0xD6F4, 0xD97B, 0xDBEB, 0xDE43, 0xE081, 0xE2A8, 0xE4B6,
	0xE6AC, 0xE889, 0xEA4F, 0xEBFD, 0xED94, 0xEF14, 0xF07E, 0xF1D2,
	0xF310, 0xF43A, 0xF550, 0xF653, 0xF743, 0xF821, 0xF8EE, 0xF9AC,
	0xFA5A, 0xFAF9, 0xFB8B, 0xFC11, 0xFC8B, 0xFCFA, 0xFD5F, 0xFDBB,
	0xFE10, 0xFE5D, 0xFEA5, 0xFEE7, 0xFF24, 0xFF5E, 0xFF96, 0xFFCB
};

static OSStatus audioConverterComplexInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumPackets,
	AudioBufferList *ioData, AudioStreamPacketDescription *__nullable *__nullable outDataPacketDescription,
	void *__nullable inUserData)
{
	Sound *sound = (__bridge Sound *) inUserData;

	UInt32 ioNumBytes = *ioNumPackets*sound->fileFormat.mBytesPerPacket;

	if (sound->audioConverterBuffer)
		free(sound->audioConverterBuffer);

	sound->audioConverterBuffer = malloc(ioNumBytes);

	OSStatus err = AudioFileReadPacketData(sound->inAudioFile, true, &ioNumBytes, NULL, sound->audioFilePos,
		ioNumPackets, sound->audioConverterBuffer);

	if (err != noErr && err != eofErr)
		NSLog(@"AudioFileReadPacketData error: %d", err);

	ioData->mBuffers[0].mNumberChannels = sound->fileFormat.mChannelsPerFrame;
	ioData->mBuffers[0].mDataByteSize = ioNumBytes;
	ioData->mBuffers[0].mData = sound->audioConverterBuffer;

	sound->audioFilePos += *ioNumPackets;
	return err;
}

- (void)audioQueueOutputCallback:(AudioQueueBufferRef)inBuffer
{
	memset(inBuffer->mAudioData, 0, inBuffer->mAudioDataByteSize = inBuffer->mAudioDataBytesCapacity);

	OSStatus err;

	if (audioQueueBuffer)
	{
		if ((err = AudioQueueEnqueueBuffer(audioQueue, inBuffer, 0, nil)) != noErr)
			NSLog(@"AudioQueueEnqueueBuffer error: %d", err);
	}
	else
	{
		if (inAudioFile && !pause)
		{
			AudioBufferList audioBufferList;
			audioBufferList.mNumberBuffers = 1;
			audioBufferList.mBuffers[0].mNumberChannels = streamFormat.mChannelsPerFrame;
			audioBufferList.mBuffers[0].mDataByteSize = inBuffer->mAudioDataBytesCapacity;
			audioBufferList.mBuffers[0].mData = inBuffer->mAudioData;

			UInt32 ioNumPackets = inBuffer->mAudioDataBytesCapacity/streamFormat.mBytesPerPacket;

			err = AudioConverterFillComplexBuffer(audioConverter, audioConverterComplexInputDataProc,
				(__bridge void *) self, &ioNumPackets, &audioBufferList, NULL);

			if (err != noErr && err != eofErr)
				NSLog(@"AudioConverterFillComplexBuffer error: %d", err);

			free(audioConverterBuffer);
			audioConverterBuffer = 0;

			if (ioNumPackets > 0)
			{
				[textField performSelectorOnMainThread:@selector(setStringValue:)
											withObject:[NSString stringWithFormat:@"%02d:%02d/%02d:%02d",
																				  (unsigned) (audioFilePos / fileFormat.mSampleRate) / 60,
																				  (unsigned) (audioFilePos / fileFormat.mSampleRate) % 60,
																				  (unsigned) (packetCount / fileFormat.mSampleRate) / 60,
																				  (unsigned) (packetCount / fileFormat.mSampleRate) % 60]
										 waitUntilDone:NO];
			}
			else
			{
				inBuffer->mAudioDataByteSize = inBuffer->mAudioDataBytesCapacity;

				if ((err = AudioConverterDispose(audioConverter)) != noErr)
					NSLog(@"AudioConverterDispose error: %d", err);

				audioConverter = 0;

				if ((err = AudioFileClose(inAudioFile)) != noErr)
					NSLog(@"AudioFileClose error: %d", err);

				inAudioFile = 0;

				[textField performSelectorOnMainThread:@selector(setStringValue:)
											withObject:@"--:--"
										 waitUntilDone:NO];
			}
		}

		audioBufferSize = inBuffer->mAudioDataByteSize/streamFormat.mBytesPerPacket;
		audioBufferPtr = inBuffer->mAudioData;

		audioQueueBuffer = inBuffer;
		lastIndex &= 63;
	}

	uint64_t interval = ((uint64_t) quartz*audioQueueBuffer->mAudioDataByteSize)/(streamFormat.mSampleRate*
		streamFormat.mBytesPerPacket);

	if (![self.computer execute:frame + interval])
		return;

	[self flush:frame + interval];

#ifdef DEBUG
	if (inAudioFile == 0 && audioBufferSize)
		NSLog(@"audioBufferSize=%d", audioBufferSize);

	unsigned index = (unsigned) ((interval*(unsigned) streamFormat.mSampleRate*64)/quartz);

	if (inAudioFile == 0 && (lastIndex ^ index) & ~63)
		NSLog(@"lastIndex: %d", lastIndex/64);
#endif

	if (outAudioFile)
	{
		UInt32 count = audioQueueBuffer->mAudioDataByteSize/2;
		SInt16 *ptr = audioQueueBuffer->mAudioData;

		for (SInt16 v = *ptr; --count && *++ptr == v;);

		if (count)
		{
			UInt32 ioNumPackets = MIN(packetCount - audioFilePos, streamFormat.mSampleRate*3);

			if (ioNumPackets)
			{
				NSMutableData *zero = [NSMutableData dataWithLength:ioNumPackets*streamFormat.mBytesPerPacket];

				err = AudioFileWritePackets(outAudioFile, true, (UInt32) zero.length, NULL, audioFilePos, &ioNumPackets,
					zero.bytes);

				if (err != noErr)
					NSLog(@"AudioFileWritePackets error: %d", err);

				packetCount = audioFilePos += ioNumPackets;
			}

			ioNumPackets = audioQueueBuffer->mAudioDataBytesCapacity/streamFormat.mBytesPerPacket;

			err = AudioFileWritePackets(outAudioFile, true, audioQueueBuffer->mAudioDataBytesCapacity, NULL,
				audioFilePos, &ioNumPackets, audioQueueBuffer->mAudioData);

			if (err != noErr)
				NSLog(@"AudioFileWritePackets error: %d", err);

			packetCount = audioFilePos += ioNumPackets;

			[textField performSelectorOnMainThread:@selector(setStringValue:)
										withObject:[NSString stringWithFormat:@"%02d:%02d",
																			  (unsigned) (packetCount / streamFormat.mSampleRate) / 60,
																			  (unsigned) (packetCount / streamFormat.mSampleRate) % 60]
									 waitUntilDone:NO];
		}

		else if (packetCount)
			packetCount += audioQueueBuffer->mAudioDataBytesCapacity/streamFormat.mBytesPerPacket;
	}

	if ((err = AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffer, 0, nil)) != noErr)
		NSLog(@"AudioQueueEnqueueBuffer error: %d", err);

	audioQueueBuffer = 0;
	frame += interval;
}

static void audioQueueOutputCallback(void *__nullable inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{
	Sound *sound = (__bridge Sound *) inUserData;

	@synchronized(sound->computer)
	{
		if (sound->frame != -1)
			[sound audioQueueOutputCallback:inBuffer];
	}
}

- (BOOL)input:(uint64_t)clock
{
	if (audioQueueBuffer == nil || inAudioFile == 0)
		return NO;

	unsigned index = ((clock - frame) * streamFormat.mSampleRate) / quartz;
	index *= streamFormat.mChannelsPerFrame;

	if (index*sizeof(SInt16) >= audioQueueBuffer->mAudioDataByteSize)
		index = audioQueueBuffer->mAudioDataByteSize/sizeof(SInt16) - streamFormat.mChannelsPerFrame;

	return ((SInt16 *) audioQueueBuffer->mAudioData)[index] < 0;
}

- (void)flush:(uint64_t)clock
{
	if (inAudioFile || audioQueueBuffer == 0)
		return;

	unsigned index = (unsigned) (((clock - frame)*(unsigned) streamFormat.mSampleRate*64)/quartz);

	if (index == lastIndex)
		return;

	uint32_t scale;

	if (((index ^ lastIndex) & ~63) == 0)
	{
		scale = filter_diff[1][index & 63] - filter_diff[1][lastIndex & 63];
		s2_l += snd_l*scale;
		s2_r += snd_r*scale;

		scale = filter_diff[0][index & 63] - filter_diff[0][lastIndex & 63];
		s1_l += snd_l*scale;
		s1_r += snd_r*scale;
	}
	else
	{
		scale = 0x10000 - filter_diff[1][lastIndex & 63];
		uint16_t l = (snd_l*scale + s2_l) >> 16;
		uint16_t r = (snd_l*scale + s2_r) >> 16;

		scale = 0x8000 - filter_diff[0][lastIndex & 63];
		s2_l = s1_l + snd_l*scale;
		s2_r = s1_r + snd_r*scale;

		if (audioBufferSize)
		{
			*audioBufferPtr++ = l;

			if (streamFormat.mChannelsPerFrame == 2)
				*audioBufferPtr++ = r;

			--audioBufferSize;
		}
#ifdef DEBUG
		else NSLog(@"bug 1");
#endif

		lastIndex |= 63;
		lastIndex++;

		uint32_t val_l = snd_l*0x8000;
		uint32_t val_r = snd_r*0x8000;

		while ((index ^ lastIndex) & ~63)
		{
			l = (s2_l + val_l) >> 16;
			r = (s2_r + val_r) >> 16;

			if (audioBufferSize)
			{
				*audioBufferPtr++ = l;

				if (streamFormat.mChannelsPerFrame == 2)
					*audioBufferPtr++ = r;

				--audioBufferSize;
			}
#ifdef DEBUG
			else NSLog(@"bug 2");
#endif

			lastIndex += 64;
			s2_l = val_l;
			s2_r = val_r;
		}

		scale = filter_diff[1][index & 63] - 0x8000;
		s2_l += snd_l*scale;
		s2_r += snd_r*scale;

		scale = filter_diff[0][index & 63];
		s1_l = snd_l*scale;
		s1_r = snd_r*scale;
	}

	lastIndex = index;
}

- (void)update:(uint64_t)clock output:(BOOL)output left:(int16_t)left right:(int16_t)right
{
	if (outAudioFile)
		left = right = output ? 20000 : -20000;

	if (snd_l ^ left || snd_r ^ right)
	{
		[self flush:clock];

		snd_l = left;
		snd_r = right;
	}
}

- (void)openWave:(NSURL *)URL
{
	@synchronized(computer)
	{
		OSStatus err;

		if (outAudioFile && (err = AudioFileClose(outAudioFile)) != noErr)
			NSLog(@"AudioFileClose error: %d", err);

		outAudioFile = 0;

		if (audioConverter && (err = AudioConverterDispose(audioConverter)) != noErr)
			NSLog(@"AudioConverterDispose error: %d", err);

		audioConverter = 0;

		if (inAudioFile && (err = AudioFileClose(inAudioFile)) != noErr)
			NSLog(@"AudioFileClose error: %d", err);

		inAudioFile = 0;

		@try
		{
			err = AudioFileOpenURL((__bridge CFURLRef) URL, kAudioFileReadPermission, kAudioFileWAVEType, &inAudioFile);

			if (err != noErr)
				@throw [NSString stringWithFormat:@"AudioFileOpenURL error: %d", err];

			UInt32 size = sizeof(fileFormat);

			err = AudioFileGetProperty(inAudioFile, kAudioFilePropertyDataFormat, &size, &fileFormat);

			if (err != noErr)
				@throw [NSString stringWithFormat:@"AudioFileGetProperty error: %d", err];

			size = sizeof(packetCount);

			err = AudioFileGetProperty(inAudioFile, kAudioFilePropertyAudioDataPacketCount, &size, &packetCount);

			if (err != noErr)
				@throw [NSString stringWithFormat:@"AudioFileGetProperty error: %d", err];

			if (fileFormat.mFormatID != kAudioFormatLinearPCM)
				@throw [NSString stringWithFormat:@"AudioStreamBasicDescription: mFormatID=%d", fileFormat.mFormatID];

			if (fileFormat.mBytesPerPacket == 0 || fileFormat.mFramesPerPacket == 0)
				@throw @"AudioStreamBasicDescription: VBR";

			err = AudioConverterNew(&fileFormat, &streamFormat, &audioConverter);

			if (err != noErr)
				@throw [NSString stringWithFormat:@"AudioConverterNew error: %d", err];

			textField.stringValue = [NSString stringWithFormat:@"00:00/%02d:%02d",
															   (unsigned) (packetCount/fileFormat.mSampleRate)/60,
															   (unsigned) (packetCount/fileFormat.mSampleRate)%60];

			textField.textColor = [NSColor blackColor];

			audioFilePos = 0;
			pause = NO;
			return;
		}
		@catch(NSString *string)
		{
			NSLog(@"%@", string);
		}

		if (inAudioFile && (err = AudioFileClose(inAudioFile)) != noErr)
			NSLog(@"AudioFileClose error: %d", err);

		inAudioFile = 0;
	}
}

- (BOOL)start
{
	dispatch_async(dispatch_get_main_queue(), ^{
        self->textField.textColor = [NSColor blackColor];
        self->textField.stringValue = @"--:--";
	});

	quartz = self.computer.quartz;
	frame = self.computer.clock;

	OSStatus err = AudioQueueNewOutput(&streamFormat, audioQueueOutputCallback, (__bridge void *) self,
		[[NSRunLoop currentRunLoop] getCFRunLoop], NULL, 0, &audioQueue);

	if (err != noErr)
	{
		NSLog(@"AudioQueueNewOutput error: %d", err);
		return NO;
	}

	@try
	{
		for (int i = 0; i < 3; i++)
		{
			AudioQueueBufferRef buffer;

			err = AudioQueueAllocateBuffer(audioQueue, streamFormat.mSampleRate/50*streamFormat.mBytesPerPacket,
				&buffer);

			if (err != noErr)
				@throw [NSString stringWithFormat:@"AudioQueueAllocateBuffer error: %d", err];

			memset(buffer->mAudioData, 0, buffer->mAudioDataByteSize = buffer->mAudioDataBytesCapacity);

			if ((err = AudioQueueEnqueueBuffer(audioQueue, buffer, 0, nil)) != noErr)
				@throw [NSString stringWithFormat:@"AudioQueueEnqueueBuffer error: %d", err];
		}

		if ((err = AudioQueueStart(audioQueue, nil)) != noErr)
			@throw [NSString stringWithFormat:@"AudioQueueStart error: %d", err];

#ifdef DEBUG
		NSLog(@"Sound start");
#endif

		return YES;
	}
	@catch(NSString *string)
	{
		NSLog(@"%@", string);
	}

	if ((err = AudioQueueDispose(audioQueue, YES)) != noErr)
		NSLog(@"AudioQueueDispose error: %d", err);

	return NO;
}

- (void)stop
{
	@synchronized(computer)
	{
		frame = -1;
	}

	OSStatus err;

	if (outAudioFile && (err = AudioFileClose(outAudioFile)) != noErr)
		NSLog(@"AudioFileClose error: %d", err);

	outAudioFile = 0;

	if (audioConverter && (err = AudioConverterDispose(audioConverter)) != noErr)
		NSLog(@"AudioConverterDispose error: %d", err);

	audioConverter = 0;

	if (inAudioFile && (err = AudioFileClose(inAudioFile)) != noErr)
		NSLog(@"AudioFileClose error: %d", err);

	inAudioFile = 0;

	textField.stringValue = @"";

	if ((err = AudioQueueStop(audioQueue, YES)) != noErr)
		NSLog(@"AudioQueueStop error: %d", err);

	if ((err = AudioQueueDispose(audioQueue, YES)) != noErr)
		NSLog(@"AudioQueueDispose error: %d", err);

#ifdef DEBUG
	NSLog(@"Sound stop");
#endif
}

- (BOOL)isOutput
{
	return outAudioFile != 0;
}

- (BOOL)isInput
{
	return inAudioFile != 0;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(tape_play:))
	{
		if (inAudioFile)
			menuItem.title = pause ? @"Возобновить" : @"Пауза";
		else
			menuItem.title = @"Воспроизвести";

		return YES;
	}

	if (menuItem.action == @selector(tape_stop:))
		return inAudioFile != 0;

	if (menuItem.action == @selector(tape_backward:))
		return inAudioFile != 0;

	if (menuItem.action == @selector(tape_forward:))
		return inAudioFile != 0;

	if (menuItem.action == @selector(tape_record:))
	{
		menuItem.state = outAudioFile != 0;
		return inAudioFile == 0;
	}

	return NO;
}

- (IBAction)tape_play:(id)sender
{
	if (inAudioFile == 0)
	{
		NSOpenPanel *panel = [NSOpenPanel openPanel];
		panel.allowedFileTypes = @[@"wav"];

		if ([panel runModal] == NSModalResponseOK && panel.URLs.count == 1)
			[self openWave:panel.URLs.firstObject];
	}
	else
	{
		pause = !pause;
	}
}

- (IBAction)tape_stop:(id)sender
{
	@synchronized(computer)
	{
		OSStatus err;

		if (outAudioFile && (err = AudioFileClose(outAudioFile)) != noErr)
			NSLog(@"AudioFileClose error: %d", err);

		outAudioFile = 0;

		if (audioConverter && (err = AudioConverterDispose(audioConverter)) != noErr)
			NSLog(@"AudioConverterDispose error: %d", err);

		audioConverter = 0;

		if (inAudioFile && (err = AudioFileClose(inAudioFile)) != noErr)
			NSLog(@"AudioFileClose error: %d", err);

		inAudioFile = 0;

		textField.textColor = [NSColor blackColor];
		textField.stringValue = @"--:--";
	}
}

- (IBAction)tape_backward:(id)sender
{
	@synchronized(computer)
	{
		if (inAudioFile)
		{
			if (audioFilePos >= fileFormat.mSampleRate)
				audioFilePos -= fileFormat.mSampleRate;
			else
				audioFilePos = 0;

			textField.stringValue = [NSString stringWithFormat:@"%02d:%02d/%02d:%02d",
															   (unsigned) (audioFilePos/fileFormat.mSampleRate)/60,
															   (unsigned) (audioFilePos/fileFormat.mSampleRate)%60,
															   (unsigned) (packetCount/fileFormat.mSampleRate)/60,
															   (unsigned) (packetCount/fileFormat.mSampleRate)%60];
		}
	}
}

- (IBAction)tape_forward:(id)sender
{
	@synchronized(computer)
	{
		if (inAudioFile)
		{
			if (audioFilePos + fileFormat.mSampleRate < packetCount)
				audioFilePos += fileFormat.mSampleRate;

			textField.stringValue = [NSString stringWithFormat:@"%02d:%02d/%02d:%02d",
															   (unsigned) (audioFilePos/fileFormat.mSampleRate)/60,
															   (unsigned) (audioFilePos/fileFormat.mSampleRate)%60,
															   (unsigned) (packetCount/fileFormat.mSampleRate)/60,
															   (unsigned) (packetCount/fileFormat.mSampleRate)%60];
		}
	}
}

- (IBAction)tape_record:(id)sender
{
	OSStatus err;

	if (outAudioFile)
	{
		@synchronized(computer)
		{
			if ((err = AudioFileClose(outAudioFile)) != noErr)
				NSLog(@"AudioFileClose error: %d", err);

			textField.textColor = [NSColor blackColor];
			textField.stringValue = @"--:--";

			outAudioFile = 0;
		}
	}
	else if (inAudioFile == 0)
	{
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		savePanel.allowedFileTypes = @[@"wav"];

		if ([savePanel runModal] == NSModalResponseOK)
		{
			@synchronized(computer)
			{
				err = AudioFileCreateWithURL((__bridge CFURLRef) savePanel.URL, kAudioFileWAVEType, &streamFormat,
					kAudioFileFlags_EraseFile, &outAudioFile);

				if (err != noErr)
					NSLog(@"AudioFileCreateWithURL error: %d", err);

				else
				{
					textField.textColor = [NSColor redColor];
					textField.stringValue = @"--:--";

					audioFilePos = 0;
					packetCount = 0;
				}
			}
		}
	}
}

- (void)awakeFromNib
{
	streamFormat.mSampleRate = 48000;
	streamFormat.mFormatID = kAudioFormatLinearPCM;
	streamFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
	streamFormat.mBitsPerChannel = 16;
	streamFormat.mChannelsPerFrame = 2;
	streamFormat.mBytesPerPacket = streamFormat.mBitsPerChannel/8*streamFormat.mChannelsPerFrame;
	streamFormat.mBytesPerFrame = streamFormat.mBitsPerChannel/8*streamFormat.mChannelsPerFrame;
	streamFormat.mFramesPerPacket = 1;
	streamFormat.mReserved = 0;
}

#ifdef DEBUG
- (void)dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
