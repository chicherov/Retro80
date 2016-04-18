/*****

 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>

 *****/

#import "x8255.h"

@interface Floppy : X8255

- (void) setDisk:(NSInteger)disk URL:(NSURL *)url;
- (NSURL *) getDisk:(NSInteger)disk;
- (NSInteger) selected;

@end
