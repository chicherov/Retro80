/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 Базовый класс ретрокомпьютера

 *****/

@class Document;

@class Display;
@class Sound;
@class Debug;

@protocol Enabled
@property(nonatomic,getter=isEnabled) BOOL enabled;
@end

@interface Computer : NSResponder<NSCoding>

@property(class, nonatomic, readonly) NSString *title;

@property(nonatomic, assign) Document *document;
@property(nonatomic, assign) Display *display;
@property(nonatomic, assign) Sound *sound;
@property(nonatomic, assign) Debug *debug;

@property(nonatomic, readonly) unsigned quartz;
@property(nonatomic, readonly) uint64_t clock;

@property(nonatomic, strong, readonly) NSObject<Enabled> *inpHook;
@property(nonatomic, strong, readonly) NSObject<Enabled> *outHook;

- (void)registerUndoWithMenuItem:(NSMenuItem *)menuItem;

- (BOOL)execute:(uint64_t)clki;

- (void)start;
- (void)stop;

- (instancetype)initWithQuartz:(unsigned)quartz NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (BOOL)createObjects;
- (BOOL)mapObjects;

- (BOOL)decodeWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;

@end
