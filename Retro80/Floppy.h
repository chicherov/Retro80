#import "x8255.h"

@interface Floppy : X8255

- (void) setDisk:(NSInteger)disk URL:(NSURL *)url;
- (NSURL *) getDisk:(NSInteger)disk;
- (NSInteger) selected;

@end
