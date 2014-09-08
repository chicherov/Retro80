#import "x8255.h"

@interface Floppy : X8255

- (void) setUrl:(NSURL *)url disk:(NSInteger)disk;
- (BOOL) state:(NSInteger)disk;

@end
