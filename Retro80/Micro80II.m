/*****
 
 Проект «Ретро КР580» (http://uart.myqnapcloud.com/retro80.html)
 Copyright © 2014-2016 Andrey Chicherov <chicherov@mac.com>
 
 ПЭВМ «Микро-80» с доработками
 
 *****/

#import "Micro80.h"

@implementation Micro80II

// -----------------------------------------------------------------------------
// validateMenuItem
// -----------------------------------------------------------------------------

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
    if (menuItem.action == @selector(ROMDisk:))
    {
        if (menuItem.tag == 0)
        {
            NSURL *url = [self.ext URL]; if ((menuItem.state = url != nil))
                menuItem.title = [[menuItem.title componentsSeparatedByString:@":"].firstObject stringByAppendingFormat:@": %@", url.lastPathComponent];
            else
                menuItem.title = [menuItem.title componentsSeparatedByString:@":"].firstObject;
            
            menuItem.hidden = FALSE;
            return YES;
        }
    }

    return [super validateMenuItem:menuItem];
}

// -----------------------------------------------------------------------------
// Внешний ROM-диск
// -----------------------------------------------------------------------------

- (IBAction) ROMDisk:(NSMenuItem *)menuItem;
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedFileTypes = @[@"rom", @"bin"];
    panel.canChooseDirectories = TRUE;
    panel.title = menuItem.title;
    panel.delegate = self.ext;
    
    if ([panel runModal] == NSFileHandlingPanelOKButton && panel.URLs.count == 1)
    {
        [self.document registerUndoWithMenuItem:menuItem];
        self.ext.URL = panel.URLs.firstObject;
    }
    else if (self.ext.URL != nil)
    {
        [self.document registerUndoWithMenuItem:menuItem];
        self.ext.URL = nil;
    }
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (BOOL) createObjects
{
    if (self.rom == nil && (self.rom = [[ROM alloc] initWithContentsOfResource:@"M80RK86" mask:0x07FF]) == nil)
        return FALSE;

    if (self.ext == nil && (self.ext = [[ROMDisk alloc] init]) == nil)
        return FALSE;

    return [super createObjects];
}

// -----------------------------------------------------------------------------

- (BOOL) mapObjects
{
    if ([super mapObjects] == FALSE)
        return FALSE;
    
    [self.cpu mapObject:self.ext atPort:0xA0 count:0x04];

    [self.cpu mapObject:self.crt from:0xE000 to:0xEFFF];
    
    self.inpHook.type = 1;
    self.outHook.type = 1;

    return TRUE;
}

// -----------------------------------------------------------------------------
// encodeWithCoder/decodeWithCoder
// -----------------------------------------------------------------------------

- (void) encodeWithCoder:(NSCoder *)encoder
{
    [super encodeWithCoder:encoder];
    
    [encoder encodeObject:self.ext forKey:@"ext"];
}

// -----------------------------------------------------------------------------

- (BOOL) decodeWithCoder:(NSCoder *)decoder
{
    if (![super decodeWithCoder:decoder])
        return FALSE;
    
    if ((self.ext = [decoder decodeObjectForKey:@"ext"]) == nil)
        return FALSE;
    
    return TRUE;
}

@end
