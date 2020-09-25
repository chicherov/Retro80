@interface Sound: NSObject
@end

@implementation Sound
{
	IBOutlet NSTextField *textField;
}

- (void)awakeFromNib
{
    [textField removeFromSuperview];
    textField = nil;
}

@end
