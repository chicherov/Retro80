@import AudioToolbox;
#import "Sound.h"
#import "x8080.h"

@implementation Sound
{
	AudioStreamBasicDescription streamFormat;
	AudioQueueRef audioQueue;
	BOOL pause;
	BOOL mute;

	AudioFileID inAudioFile;
	SInt64 inAudioFilePos;
	SInt64 packetCount;

	Float64 CLK;
	Float64 clk;

	void (*execute)(id, SEL, uint64_t);
	SInt8 (*sample)(id, SEL, uint64_t);
}

NSRunLoop *runLoop;

@synthesize output;
@synthesize beeper;
@synthesize input;

@synthesize snd;
@synthesize cpu;

// -----------------------------------------------------------------------------

- (void) callback:(AudioQueueBufferRef)inBuffer
{
	if (inAudioFile)
	{
		if (pause)
		{
			memset(inBuffer->mAudioData, 0, inBuffer->mAudioDataByteSize = inBuffer->mAudioDataBytesCapacity);
		}

		else
		{
			UInt32 ioNumPackets = inBuffer->mAudioDataBytesCapacity / streamFormat.mBytesPerPacket;

			OSStatus err; if ((AudioFileReadPackets(inAudioFile, true, &inBuffer->mAudioDataByteSize, NULL, inAudioFilePos, &ioNumPackets, inBuffer->mAudioData)) != noErr && err != eofErr)
			{
				NSLog(@"AudioFileReadPackets error: %d", err);
			}

			if (ioNumPackets > 0)
			{
				inAudioFilePos += ioNumPackets;

				if ((unsigned) (inAudioFilePos / streamFormat.mSampleRate) != (unsigned) ((inAudioFilePos - ioNumPackets) / streamFormat.mSampleRate))
				{
					self.textField.stringValue = [NSString stringWithFormat:@"%02d:%02d/%02d:%02d",
												  (unsigned) (inAudioFilePos / streamFormat.mSampleRate) / 60,
												  (unsigned) (inAudioFilePos / streamFormat.mSampleRate) % 60,
												  (unsigned) (packetCount / streamFormat.mSampleRate) / 60,
												  (unsigned) (packetCount / streamFormat.mSampleRate) % 60
												  ];
				}

				uint8_t add = streamFormat.mFormatFlags & kLinearPCMFormatFlagIsSignedInteger ? 0x80 : 0x00;
				uint8_t* ptr = inBuffer->mAudioData + (streamFormat.mBitsPerChannel == 16 ? 1 : 0);

				while (ioNumPackets--)
				{
					input = ((*ptr + add) & 0xFF) > 0x80;
					ptr += streamFormat.mBytesPerPacket;

					execute(cpu, @selector(execute:), CLK += clk);
				}
			}

			else
			{
				[self stop];
				[self close];
				[self start];

				return;
			}
		}
	}
	else
	{
		SInt8 *ptr = inBuffer->mAudioData;

		for (inBuffer->mAudioDataByteSize = 0; inBuffer->mAudioDataByteSize < inBuffer->mAudioDataBytesCapacity; inBuffer->mAudioDataByteSize++, ptr++)
		{
			execute(cpu, @selector(execute:), CLK += clk);

			*ptr = mute ? 0 : (output ? 25 : 0) + (beeper && (beeper == 1 || (uint64_t)CLK % beeper > (beeper / 2)) ? 25 : 0) + sample(snd, @selector(sample:), CLK);

			if (streamFormat.mBitsPerChannel == 16)
			{
				*(SInt16*)ptr = *ptr * 256; inBuffer->mAudioDataByteSize++; ptr++;
			}
		}
	}

	OSStatus err; if ((err = AudioQueueEnqueueBuffer(audioQueue, inBuffer, 0, nil)) != noErr)
		NSLog(@"AudioQueueEnqueueBuffer error: %d", err);
}

// -----------------------------------------------------------------------------

static void OutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{
	Sound *sound = (__bridge Sound*) inUserData; @synchronized(sound)
	{
		if (sound->CLK != (uint64_t) -1)
		{
			[sound callback:inBuffer];
		}
	}
}

// -----------------------------------------------------------------------------

- (void) receiveSleepNote: (NSNotification*) note
{
#ifdef DEBUG
    NSLog(@"receiveSleepNote: %@", [note name]);
#endif

	[self stop];

	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
														   selector:@selector(receiveWakeNote:)
															   name:NSWorkspaceDidWakeNotification
															 object:nil];
}

// -----------------------------------------------------------------------------

- (void) receiveWakeNote: (NSNotification*) note
{
#ifdef DEBUG
    NSLog(@"receiveWakeNote: %@", [note name]);
#endif

	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

	[self start];
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

		self.textField.stringValue = [NSString stringWithFormat:@"00:00/%02d:%02d",
									  (unsigned) (packetCount / streamFormat.mSampleRate) / 60,
									  (unsigned) (packetCount / streamFormat.mSampleRate) % 60
									  ];

		[self.textField setHidden:FALSE];

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

	self.textField.stringValue = @"";
	[self.textField setHidden:TRUE];

	inAudioFile = 0;
}

// -----------------------------------------------------------------------------

- (void) start:(NSRunLoop *)runLoop
{
	if (inAudioFile == 0)
	{
		streamFormat.mSampleRate = 44100;
		streamFormat.mFormatID = kAudioFormatLinearPCM;
		streamFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
		streamFormat.mBitsPerChannel = 8;
		streamFormat.mChannelsPerFrame = 1;
		streamFormat.mBytesPerPacket = streamFormat.mBitsPerChannel / 8 * streamFormat.mChannelsPerFrame;
		streamFormat.mBytesPerFrame = streamFormat.mBitsPerChannel / 8 * streamFormat.mChannelsPerFrame;
		streamFormat.mFramesPerPacket = 1;
		streamFormat.mReserved = 0;

		self.textField.stringValue = @"--:--";
		[self.textField setHidden:TRUE];
	}

	OSStatus err; if ((err = AudioQueueNewOutput(&streamFormat, OutputCallback, (__bridge void *)self, [runLoop getCFRunLoop], NULL, 0, &audioQueue)) == noErr)
	{
		execute = (void (*) (id, SEL, uint64_t)) [self.cpu methodForSelector:@selector(execute:)];
		sample = (SInt8 (*) (id, SEL, uint64_t)) [self.snd methodForSelector:@selector(sample:)];

		CLK = [self.cpu CLK]; clk = [self.cpu quartz] / streamFormat.mSampleRate;

		mute = self.cpu.HALT = self.document.inViewingMode;

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

		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
															   selector:@selector(receiveSleepNote:)
																   name:NSWorkspaceWillSleepNotification
																 object:nil];
	}
	else
	{
		NSLog(@"AudioQueueNewOutput error: %d", err);
	}

#ifdef DEBUG
	NSLog(@"Sound start");
#endif

}

// -----------------------------------------------------------------------------

- (void) thread
{
#ifdef DEBUG
	NSLog(@"Thread start");
#endif

	runLoop = [NSRunLoop currentRunLoop];
	[self start:runLoop];
	[runLoop run];

	runLoop = nil;

#ifdef DEBUG
	NSLog(@"Thread stop");
#endif
}

// -----------------------------------------------------------------------------

- (void) start
{
//	[self performSelectorInBackground:@selector(thread) withObject:nil];

	if (runLoop == nil)
		[NSThread detachNewThreadSelector:@selector(thread) toTarget:self withObject:nil];
	else
		[self start:runLoop];
}


// -----------------------------------------------------------------------------

- (void) stop
{
	@synchronized(self)
	{
		CLK = (uint64_t) -1;
	}

#ifdef DEBUG
	NSLog(@"Sound stop");
#endif

	OSStatus err; if ((err = AudioQueueStop(audioQueue, TRUE)) != noErr)
		NSLog(@"AudioQueueStop error: %d", err);

	if ((err = AudioQueueDispose(audioQueue, TRUE)) != noErr)
		NSLog(@"AudioQueueDispose error: %d", err);

	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

// ----------------------------------------------------------------------

- (BOOL) isInput
{
	return inAudioFile != 0;
}

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(play:))
	{
		if (inAudioFile)
		{
			menuItem.title = pause ? NSLocalizedString(@"Возобновить", "Resume") : NSLocalizedString(@"Пауза", "Pause");
		}
		else
		{
			menuItem.title = NSLocalizedString(@"Воспроизвести", "Play");
		}

		return YES;
	}

	if (menuItem.action == @selector(playstop:))
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

- (IBAction) playstop:(id)sender
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
