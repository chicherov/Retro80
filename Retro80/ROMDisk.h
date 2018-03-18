/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 ROM-диск

 *****/

#import "x8255.h"

@interface ROMDisk : X8255 <NSOpenSavePanelDelegate>
{
	NSString *resource;

	uint16_t latch;
	uint32_t addr;

	NSData *rom;
	NSURL *URL;
}

@property(nonatomic, readonly) NSData *rom;
@property(nonatomic, strong) NSURL *URL;
@property(nonatomic) uint8_t MSB;

- (instancetype)initWithContentsOfResource:(NSString *)aResource;

- (BOOL)validateDirectory:(NSURL *)url error:(NSError **)outError;
- (BOOL)validateFile:(NSURL *)url error:(NSError **)outError;

- (IBAction)ROMDisk:(NSMenuItem *)menuItem;

@end
