@import AudioToolbox;
#import "Sound.h"
#import "x8080.h"

@implementation Sound
{
	AudioStreamBasicDescription streamFormat;
	AudioQueueRef audioQueue;
	BOOL pause;

	AudioFileID inAudioFile;
	SInt64 inAudioFilePos;
	SInt64 packetCount;

	uint32_t quartz;
	uint64_t CLK;
}

// ----------------------------------------------------------------------

static void OutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{
	Sound *sound = (__bridge Sound*) inUserData; @synchronized(sound)
	{
		if (sound->CLK != (uint64_t) -1)
		{
			uint64_t clk = sound->quartz / sound->streamFormat.mSampleRate;

			if (sound->inAudioFile)
			{
				if (sound->pause)
				{
					memset(inBuffer->mAudioData, 0, inBuffer->mAudioDataByteSize = inBuffer->mAudioDataBytesCapacity);
				}
				else
				{
					UInt32 ioNumPackets = inBuffer->mAudioDataBytesCapacity / sound->streamFormat.mBytesPerPacket;

					OSStatus err; if ((AudioFileReadPackets(sound->inAudioFile, true, &inBuffer->mAudioDataByteSize, NULL, sound->inAudioFilePos, &ioNumPackets, inBuffer->mAudioData)) != noErr && err != eofErr)
					{
						NSLog(@"AudioFileReadPackets error: %d", err);
					}

					if (ioNumPackets > 0)
					{
						sound->inAudioFilePos += ioNumPackets;

						sound->_text.stringValue = [NSString stringWithFormat:@"%02d:%02d/%02d:%02d",
													(unsigned) (sound->inAudioFilePos / sound->streamFormat.mSampleRate) / 60,
													(unsigned) (sound->inAudioFilePos / sound->streamFormat.mSampleRate) % 60,
													(unsigned) (sound->packetCount / sound->streamFormat.mSampleRate) / 60,
													(unsigned) (sound->packetCount / sound->streamFormat.mSampleRate) % 60
													];

						uint8_t add = sound->streamFormat.mFormatFlags & kLinearPCMFormatFlagIsSignedInteger ? 0x80 : 0x00;
						uint8_t* ptr = inBuffer->mAudioData + (sound->streamFormat.mBitsPerChannel == 16 ? 1 : 0);

						while (ioNumPackets--)
						{
							sound->_input = ((*ptr + add) & 0xFF) > 0x80;
							ptr += sound->streamFormat.mBytesPerPacket;
							[sound->_cpu execute:sound->CLK += clk];
						}
					}
					else
					{
						[sound stop];
						[sound close];
						[sound start];
						return;
					}
				}
			}
			else
			{
				SInt8 *ptr = inBuffer->mAudioData;

				for (inBuffer->mAudioDataByteSize = 0; inBuffer->mAudioDataByteSize < inBuffer->mAudioDataBytesCapacity; inBuffer->mAudioDataByteSize++)
				{
					[sound->_cpu execute:sound->CLK += clk];
					*ptr++ = (sound->_output ? 20 : 0) + (sound->_beeper ? 20 : 0) + [sound sample:sound->CLK];
				}
			}

			OSStatus err; if ((err = AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil)) != noErr)
				NSLog(@"AudioQueueEnqueueBuffer error: %d", err);
		}
	}
}

// -----------------------------------------------------------------------------

- (BOOL) open:(NSURL *)url
{
	@try
	{
		OSStatus err; if ((err = AudioFileOpenURL((__bridge CFURLRef)url, kAudioFileReadPermission, kAudioFileWAVEType, &inAudioFile)) != noErr)
		{
			@throw [NSException exceptionWithName:@"Ошибка при открытии аудио файла"
										   reason:[NSString stringWithFormat:@"AudioFileOpenURL error: %d", err]
										 userInfo:nil];
		}

		UInt32 size = sizeof(streamFormat);

		if ((err = AudioFileGetProperty(inAudioFile, kAudioFilePropertyDataFormat, &size, &streamFormat)) != noErr)
		{
			@throw [NSException exceptionWithName:@"Ошибка при открытии аудио файла"
										   reason:[NSString stringWithFormat:@"AudioFileGetProperty error: %d", err]
										 userInfo:nil];
		}

		size = sizeof(packetCount);

		if ((err = AudioFileGetProperty(inAudioFile, kAudioFilePropertyAudioDataPacketCount, &size, &packetCount)) != noErr)
		{
			@throw [NSException exceptionWithName:@"Ошибка при открытии аудио файла"
										   reason:[NSString stringWithFormat:@"AudioFileGetProperty error: %d", err]
										 userInfo:nil];
		}

		if (streamFormat.mFormatID != kAudioFormatLinearPCM)
		{
			@throw [NSException exceptionWithName:@"Ошибка при открытии аудио файла"
										   reason:[NSString stringWithFormat:@"AudioStreamBasicDescription: mFormatID=%d", streamFormat.mFormatID]
										 userInfo:nil];
		}

		if ((streamFormat.mFormatFlags & (kLinearPCMFormatFlagIsFloat | kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsPacked)) != kLinearPCMFormatFlagIsPacked)
		{
			@throw [NSException exceptionWithName:@"Ошибка при открытии аудио файла"
										   reason:[NSString stringWithFormat:@"AudioStreamBasicDescription: mFormatFlags=%d", streamFormat.mFormatFlags]
										 userInfo:nil];
		}

		if (streamFormat.mBytesPerPacket == 0 || streamFormat.mFramesPerPacket == 0)
		{
			@throw [NSException exceptionWithName:@"Ошибка при открытии аудио файла"
										   reason:[NSString stringWithFormat:@"AudioStreamBasicDescription: VBR"]
										 userInfo:nil];
		}

		self.text.stringValue = [NSString stringWithFormat:@"--:--/%02d:%02d",
								 (unsigned) (packetCount / streamFormat.mSampleRate) / 60,
								 (unsigned) (packetCount / streamFormat.mSampleRate) % 60
								 ];

		[self.text setHidden:FALSE];

		inAudioFilePos = 0;
		pause = FALSE;
		return TRUE;
	}

	@catch (NSException *exception)
	{
		NSLog(@"%@", exception);

		if (inAudioFile)
		{
			AudioFileClose(inAudioFile);
			inAudioFile = 0;
		}

		return FALSE;
	}
}

// -----------------------------------------------------------------------------

- (void) close
{
	OSStatus err; if ((err = AudioFileClose(inAudioFile)) != noErr)
		NSLog(@"AudioFileClose error: %d", err);

	self.text.stringValue = @"";
	[self.text setHidden:TRUE];

	inAudioFile = 0;
}

// -----------------------------------------------------------------------------

- (void) start
{

#ifdef DEBUG
	NSLog(@"Sound start");
#endif

	if (inAudioFile == 0)
	{
		streamFormat.mSampleRate = 44100;
		streamFormat.mFormatID = kAudioFormatLinearPCM;
		streamFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
		streamFormat.mBitsPerChannel = 8;
		streamFormat.mChannelsPerFrame = 1;
		streamFormat.mBytesPerPacket = 1 * streamFormat.mChannelsPerFrame;
		streamFormat.mBytesPerFrame = 1 * streamFormat.mChannelsPerFrame;
		streamFormat.mFramesPerPacket = 1;
		streamFormat.mReserved = 0;

		self.text.stringValue = @"--:--";
	}

	OSStatus err; if ((err = AudioQueueNewOutput(&streamFormat, OutputCallback, (__bridge void *)self, NULL, NULL, 0, &audioQueue)) == noErr)
	{
		quartz = [self.cpu quartz];
		CLK = [self.cpu CLK];

		for (int i = 0; i < 3; i++)
		{
			AudioQueueBufferRef buffer;

			if ((err = AudioQueueAllocateBuffer(audioQueue, streamFormat.mSampleRate/100 * streamFormat.mBytesPerPacket, &buffer)) == noErr)
				OutputCallback((__bridge void *)self, audioQueue, buffer);

			else
			{
				NSLog(@"AudioQueueAllocateBuffer error: %d", err);
			}
		}

		if ((err = AudioQueueStart(audioQueue, nil)) != noErr)
		{
			NSLog(@"AudioQueueStart error: %d", err);
		}
	}
	else
	{
		NSLog(@"AudioQueueNewOutput error: %d", err);
	}
}

// -----------------------------------------------------------------------------

- (void) stop
{

#ifdef DEBUG
	NSLog(@"Sound stop");
#endif

	@synchronized(self)
	{
		CLK = (uint64_t) -1;
	}

	OSStatus err; if ((err = AudioQueueStop(audioQueue, TRUE)) != noErr)
		NSLog(@"AudioQueueStop error: %d", err);

	if ((err = AudioQueueDispose(audioQueue, TRUE)) != noErr)
		NSLog(@"AudioQueueDispose error: %d", err);
}

// ----------------------------------------------------------------------

- (BOOL) isInput
{
	return inAudioFile != 0;
}

// ----------------------------------------------------------------------

- (SInt8) sample:(uint64_t)clock
{
	return 0;
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(play:))
	{
		menuItem.title = inAudioFile ? pause ? @"Resume" : @"Pause" : @"Play";
		return YES;
	}

	if (menuItem.action == @selector(stop:))
	{
		return inAudioFile != 0;
	}

	if (menuItem.action == @selector(stepBackward:))
	{
		return inAudioFile && inAudioFilePos > streamFormat.mSampleRate;
	}

	if (menuItem.action == @selector(stepForward:))
	{
		return inAudioFile && inAudioFilePos + streamFormat.mSampleRate < packetCount;
	}

	return NO;
}

// -----------------------------------------------------------------------------
// play
// -----------------------------------------------------------------------------

- (IBAction) play:(id)sender
{
	@synchronized(self)
	{
		if (inAudioFile)
		{
			pause = pause == FALSE;
			return;
		}
	}

	NSOpenPanel *panel = [NSOpenPanel openPanel]; panel.allowedFileTypes = @[@"wav"];

	if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
	{
		[self stop];
		[self open:panel.URLs.firstObject];
		[self start];
	}
}

// -----------------------------------------------------------------------------
// stop
// -----------------------------------------------------------------------------

- (IBAction) stop:(id)sender
{
	[self stop];

	if (self.isInput)
		[self close];

	[self start];
}

- (void) stepBackward:(id)sender
{
	@synchronized(self)
	{
		if (inAudioFile && inAudioFilePos > streamFormat.mSampleRate)
			inAudioFilePos -= streamFormat.mSampleRate;
	}
}

- (void) stepForward:(id)sender
{
	@synchronized(self)
	{
		if (inAudioFile && inAudioFilePos + streamFormat.mSampleRate < packetCount)
			inAudioFilePos += streamFormat.mSampleRate;
	}
}

// -----------------------------------------------------------------------------
// DEBUG: dealloc
// -----------------------------------------------------------------------------

#ifdef DEBUG
- (void) dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
