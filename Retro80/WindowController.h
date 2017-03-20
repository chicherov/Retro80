/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 *****/

@class Document;

@class Display;
@class Sound;
@class Debug;

@interface WindowController : NSWindowController<NSWindowDelegate>

@property(assign) Document *document;

@property IBOutlet Display *display;
@property IBOutlet Sound *sound;
@property IBOutlet Debug *debug;

- (void)startComputer;
- (void)stopComputer;

- (void)resize;

@end
