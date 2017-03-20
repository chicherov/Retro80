/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 *****/

@class Document;
@class Computer;

@interface DocumentController : NSDocumentController

- (Document *)makeUntitledDocumentOfType:(NSString *)typeName
								   error:(NSError **)outError;

@end
