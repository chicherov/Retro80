@implementation NSLayoutConstraint (GNUstep)
- (void)setConstant:(CGFloat)constant { }
@end

@implementation NSMenuItem (GNUstep)
- (void)setHidden:(BOOL)hidden {}
- (BOOL)hidden { return NO; }
@end

@implementation NSDocument (GNUstep)
- (BOOL)inViewingMode { return NO; }
@end
