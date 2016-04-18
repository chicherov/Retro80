/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 *****/

@import AudioToolbox;
#import "Retro80.h"
#import "Sound.h"

@implementation Sound
{
	AudioStreamBasicDescription streamFormat;
	AudioQueueRef audioQueue;

	AudioFileID outAudioFile;
	AudioFileID inAudioFile;
	SInt64 audioFilePos;
	SInt64 packetCount;

	Float64 CLK;
	Float64 clk;

	BOOL (*execute)(id, SEL, uint64_t);
	SInt8 (*sample)(id, SEL, uint64_t);

	NSRunLoop *runLoop;

	NSTimer *timer;
	BOOL mute;

	BOOL debug;
	BOOL pause;
}

@synthesize crt;
@synthesize snd;
@synthesize cpu;

@synthesize debug;

@synthesize output;
@synthesize beeper;
@synthesize input;

// -----------------------------------------------------------------------------

- (void) callback:(AudioQueueBufferRef)inBuffer
{
	if ([crt respondsToSelector:@selector(draw)])
		[crt draw];

	if (debug)
	{
		memset(inBuffer->mAudioData, 0, inBuffer->mAudioDataByteSize = inBuffer->mAudioDataBytesCapacity);
	}

	else if (inAudioFile && !pause)
	{
		UInt32 ioNumPackets = inBuffer->mAudioDataBytesCapacity / streamFormat.mBytesPerPacket;

		OSStatus err; if ((AudioFileReadPackets(inAudioFile, true, &inBuffer->mAudioDataByteSize, NULL, audioFilePos, &ioNumPackets, inBuffer->mAudioData)) != noErr && err != eofErr)
			NSLog(@"AudioFileReadPackets error: %d", err);

		if (ioNumPackets > 0)
		{
			audioFilePos += ioNumPackets;

			self.textField.stringValue = [NSString stringWithFormat:@"%02d:%02d/%02d:%02d",
										  (unsigned) (audioFilePos / streamFormat.mSampleRate) / 60,
										  (unsigned) (audioFilePos / streamFormat.mSampleRate) % 60,
										  (unsigned) (packetCount / streamFormat.mSampleRate) / 60,
										  (unsigned) (packetCount / streamFormat.mSampleRate) % 60
										  ];

			uint8_t add = streamFormat.mFormatFlags & kLinearPCMFormatFlagIsSignedInteger ? 0x80 : 0x00;
			uint8_t* ptr = inBuffer->mAudioData + (streamFormat.mBitsPerChannel == 16 ? 1 : 0);

			while (ioNumPackets--)
			{
				input = ((*ptr + add) & 0xFF) > 0x80;
				ptr += streamFormat.mBytesPerPacket;

				if ((debug = !execute(cpu, @selector(execute:), CLK += clk)))
				{
					[self.document.debug performSelectorOnMainThread:@selector(debug:)
															 withObject:self
														  waitUntilDone:FALSE];

					audioFilePos -= ioNumPackets;
					CLK = cpu.CLK;
					break;
				}
			}
		}

		else
		{
			[self stop];
			[self start];

			return;
		}
	}

	else if (streamFormat.mBitsPerChannel == 8)
	{
		memset(inBuffer->mAudioData, 0, inBuffer->mAudioDataByteSize = inBuffer->mAudioDataBytesCapacity);

		if ((debug = !execute(cpu, @selector(execute:), CLK += clk * inBuffer->mAudioDataByteSize)))
		{
			[self.document.debug performSelectorOnMainThread:@selector(debug:)
												  withObject:self
											   waitUntilDone:FALSE];

			CLK = cpu.CLK;
		}
	}

	else
	{
		SInt16 *ptr = inBuffer->mAudioData;
		BOOL out = FALSE;

		for (inBuffer->mAudioDataByteSize = 0; inBuffer->mAudioDataByteSize < inBuffer->mAudioDataBytesCapacity; inBuffer->mAudioDataByteSize += 2, ptr++)
		{
			if ((debug = !execute(cpu, @selector(execute:), CLK += clk)))
			{
				while (inBuffer->mAudioDataByteSize < inBuffer->mAudioDataBytesCapacity)
				{
					inBuffer->mAudioDataByteSize += 2; *ptr++ = 0;
				}

				[self.document.debug performSelectorOnMainThread:@selector(debug:)
													  withObject:self
												   waitUntilDone:FALSE];

				CLK = cpu.CLK;
				break;
			}

			if (outAudioFile)
			{
				*ptr = output ? +20000 : -20000;
				if (output) out = TRUE;
			}
			else
			{
				*ptr = ((output ? 25 : 0) + (beeper && (beeper == 1 || (uint64_t)CLK % beeper > (beeper / 2)) ? 25 : 0) + (sample ? sample(snd, @selector(sample:), CLK) : 0)) << 8;
			}
		}

		if (outAudioFile)
		{
			if (out)
			{
				UInt32 ioNumPackets = (UInt32) (packetCount - audioFilePos);

				if (ioNumPackets)
				{
					if (ioNumPackets > streamFormat.mSampleRate * 3)
						ioNumPackets = streamFormat.mSampleRate * 3;

					NSMutableData *zero = [NSMutableData dataWithLength:ioNumPackets * streamFormat.mBytesPerPacket];

					OSStatus err; if ((err = AudioFileWritePackets(outAudioFile, true, (UInt32) zero.length, NULL, audioFilePos, &ioNumPackets, zero.bytes)) != noErr)
						NSLog(@"AudioFileWritePackets error: %d", err);

					packetCount = audioFilePos += ioNumPackets;
				}

				ioNumPackets = inBuffer->mAudioDataBytesCapacity / streamFormat.mBytesPerPacket;

				OSStatus err; if ((err = AudioFileWritePackets(outAudioFile, true, inBuffer->mAudioDataBytesCapacity, NULL, audioFilePos, &ioNumPackets, inBuffer->mAudioData)) != noErr)
					NSLog(@"AudioFileWritePackets error: %d", err);

				packetCount = audioFilePos += ioNumPackets;

				self.textField.stringValue = [NSString stringWithFormat:@"%02d:%02d",
											  (unsigned) (packetCount / streamFormat.mSampleRate) / 60,
											  (unsigned) (packetCount / streamFormat.mSampleRate) % 60
											  ];
			}

			else if (packetCount)
			{
				packetCount += inBuffer->mAudioDataBytesCapacity / streamFormat.mBytesPerPacket;
			}
		}
	}

	OSStatus err; if ((err = AudioQueueEnqueueBuffer(audioQueue, inBuffer, 0, nil)) != noErr)
		NSLog(@"AudioQueueEnqueueBuffer error: %d", err);
}

// -----------------------------------------------------------------------------

static void OutputCallback(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer)
{
	Sound *sound = (__bridge Sound*) inUserData; @synchronized(sound->cpu)
	{
		if (sound->CLK >= 0.00)
			[sound callback:inBuffer];
	}
}

// -----------------------------------------------------------------------------

- (void) timer
{
	@synchronized(self.cpu)
	{
		if (CLK >= 0.00)
		{
			if ([crt respondsToSelector:@selector(draw)])
				[crt draw];

			if (!debug && (debug = !execute(cpu, @selector(execute:), CLK += clk)))
			{
				[self.document.debug performSelectorOnMainThread:@selector(debug:)
													  withObject:self
												   waitUntilDone:FALSE];

				CLK = cpu.CLK;
			}
		}
	}
}

// -----------------------------------------------------------------------------

- (void) thread
{
#ifdef DEBUG
	NSLog(@"Thread start");
#endif

	runLoop = [NSRunLoop currentRunLoop];
	[self start];

	while ([runLoop runMode:NSDefaultRunLoopMode
				 beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]]);

	runLoop = nil;

#ifdef DEBUG
	NSLog(@"Thread stop");
#endif
}

// -----------------------------------------------------------------------------

- (void) start:(NSURL *)URL
{
	@try
	{
		OSStatus err; if ((err = AudioFileOpenURL((__bridge CFURLRef)URL, kAudioFileReadPermission, kAudioFileWAVEType, &inAudioFile)) != noErr)
		{
			inAudioFile = 0;

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

		self.textField.textColor = [NSColor blackColor];

		audioFilePos = 0;
		pause = FALSE;
	}

	@catch (NSException *exception)
	{
		NSLog(@"%@", exception);

		OSStatus err; if (inAudioFile && (err = AudioFileClose(inAudioFile)) != noErr)
			NSLog(@"AudioFileClose error: %d", err);

		inAudioFile = 0;
	}

	[self start];
}

// -----------------------------------------------------------------------------

- (void) start
{
	if (runLoop == nil)
	{
		[NSThread detachNewThreadSelector:@selector(thread)
								 toTarget:self
							   withObject:self];

		return;
	}

	if (inAudioFile == 0)
	{
		streamFormat.mSampleRate = 44100;
		streamFormat.mFormatID = kAudioFormatLinearPCM;
		streamFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
		streamFormat.mBitsPerChannel = 16;
		streamFormat.mChannelsPerFrame = 1;
		streamFormat.mBytesPerPacket = streamFormat.mBitsPerChannel / 8 * streamFormat.mChannelsPerFrame;
		streamFormat.mBytesPerFrame = streamFormat.mBitsPerChannel / 8 * streamFormat.mChannelsPerFrame;
		streamFormat.mFramesPerPacket = 1;
		streamFormat.mReserved = 0;

		[self.textField performSelectorOnMainThread:@selector(setStringValue:)
										 withObject:@"--:--"
									  waitUntilDone:FALSE];

		[self.textField performSelectorOnMainThread:@selector(setTextColor:)
										 withObject:[NSColor blackColor]
									  waitUntilDone:FALSE];
	}

	execute = (BOOL (*) (id, SEL, uint64_t)) [self.cpu methodForSelector:@selector(execute:)];

	if ([self.snd respondsToSelector:@selector(sample:)])
		sample = (SInt8 (*) (id, SEL, uint64_t)) [self.snd methodForSelector:@selector(sample:)];
	else
		sample = 0;

	CLK = [self.cpu CLK]; clk = [self.cpu quartz] / streamFormat.mSampleRate;

	if (inAudioFile == 0 && (self.document.inViewingMode || mute))
	{
		timer = [NSTimer scheduledTimerWithTimeInterval:0.02
												 target:self
											   selector:@selector(timer)
											   userInfo:nil
												repeats:YES];

		clk = self.cpu.quartz * timer.timeInterval;

		[runLoop addTimer:timer forMode:NSDefaultRunLoopMode];

#ifdef DEBUG
		NSLog(@"Timer start");
#endif
	}

	else
	{
		OSStatus err; if ((err = AudioQueueNewOutput(&streamFormat, OutputCallback, (__bridge void *)self, [runLoop getCFRunLoop], NULL, 0, &audioQueue)) == noErr)
		{
			for (int i = 0; i < 3; i++)
			{
				AudioQueueBufferRef buffer;

				if ((err = AudioQueueAllocateBuffer(audioQueue, streamFormat.mSampleRate/50 * streamFormat.mBytesPerPacket, &buffer)) == noErr)
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

#ifdef DEBUG
		NSLog(@"Sound start");
#endif
	}
}

// -----------------------------------------------------------------------------

- (void) stop
{
	@synchronized(self.cpu)
	{
		CLK = -1.0;
	}

	OSStatus err; if (inAudioFile && (err = AudioFileClose(inAudioFile)) != noErr)
		NSLog(@"AudioFileClose error: %d", err);

	if (outAudioFile && (err = AudioFileClose(outAudioFile)) != noErr)
		NSLog(@"AudioFileClose error: %d", err);

	self.textField.stringValue = @"";
	inAudioFile = outAudioFile = 0;

	if (timer)
	{
		[timer invalidate];
		timer = nil;

#ifdef DEBUG
		NSLog(@"Timer stop");
#endif
	}

	else
	{
		OSStatus err; if ((err = AudioQueueStop(audioQueue, TRUE)) != noErr)
			NSLog(@"AudioQueueStop error: %d", err);

		if ((err = AudioQueueDispose(audioQueue, TRUE)) != noErr)
			NSLog(@"AudioQueueDispose error: %d", err);

#ifdef DEBUG
		NSLog(@"Sound stop");
#endif
	}
}

// ----------------------------------------------------------------------

- (BOOL) isOutput
{
	return outAudioFile != 0;
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
	if (menuItem.action == @selector(playstart:))
	{
		if (inAudioFile)
			menuItem.title = pause ? NSLocalizedString(@"Возобновить", "Resume") : NSLocalizedString(@"Пауза", "Pause");
		else
			menuItem.title = NSLocalizedString(@"Воспроизвести", "Play");

		return YES;
	}

	if (menuItem.action == @selector(playstop:))
	{
		return inAudioFile != 0;
	}

	if (menuItem.action == @selector(stepBackward:))
	{
		return inAudioFile != 0;
	}

	if (menuItem.action == @selector(stepForward:))
	{
		return inAudioFile != 0;
	}

	if (menuItem.action == @selector(record:))
	{
		menuItem.state = outAudioFile != 0;
		return inAudioFile == 0;
	}

	return NO;
}

// -----------------------------------------------------------------------------
// play
// -----------------------------------------------------------------------------

- (IBAction) playstart:(id)sender
{
	if (inAudioFile == 0)
	{
		NSOpenPanel *panel = [NSOpenPanel openPanel]; panel.allowedFileTypes = @[@"wav"];

		if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
		{
			[self stop]; [self start:panel.URLs.firstObject];
		}
	}
	else
	{
		pause = !pause;
	}
}

// -----------------------------------------------------------------------------
// stop
// -----------------------------------------------------------------------------

- (IBAction) playstop:(id)sender
{
	[self stop]; [self start];
}

- (void) stepBackward:(id)sender
{
	@synchronized(self.cpu)
	{
		if (inAudioFile)
		{
			if (audioFilePos >= streamFormat.mSampleRate)
				audioFilePos -= streamFormat.mSampleRate;
			else
				audioFilePos = 0;
		}
	}
}

- (void) stepForward:(id)sender
{
	@synchronized(self.cpu)
	{
		if (inAudioFile && audioFilePos + streamFormat.mSampleRate < packetCount)
			audioFilePos += streamFormat.mSampleRate;
	}
}

// -----------------------------------------------------------------------------
// record
// -----------------------------------------------------------------------------

- (IBAction) record:(id)sender
{
	if (outAudioFile)
	{
		OSStatus err; if ((err = AudioFileClose(outAudioFile)) != noErr)
			NSLog(@"AudioFileClose error: %d", err);

		self.textField.textColor = [NSColor blackColor];
		self.textField.stringValue = @"--:--";

		outAudioFile = 0;
	}

	else if (inAudioFile == 0)
	{
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		savePanel.allowedFileTypes = @[@"wav"];

		if ([savePanel runModal] == NSFileHandlingPanelOKButton) @synchronized(self.cpu)
		{
			OSStatus err; if ((err = AudioFileCreateWithURL((__bridge CFURLRef)savePanel.URL, kAudioFileWAVEType, &streamFormat, kAudioFileFlags_EraseFile, &outAudioFile)) != noErr)
			{
				NSLog(@"AudioFileCreateWithURL error: %d", err);
				outAudioFile = 0;
			}
			else
			{
				self.textField.textColor = [NSColor redColor];
				self.textField.stringValue = @"--:--";

				audioFilePos = 0;
				packetCount = 0;
			}
		}
	}
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (void) awakeFromNib
{
	mute = [[NSUserDefaults standardUserDefaults] boolForKey:@"mute"];
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
