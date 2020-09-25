/*****

 Проект «Ретро КР580» (https://github.com/chicherov/Retro80)
 Copyright © 2014-2018 Andrey Chicherov <chicherov@mac.com>

 *****/

#import "Document.h"
#import "Computer.h"

#import "DocumentController.h"
#import "WindowController.h"
#import "ComputerFactory.h"

@implementation Document

@synthesize computer;

- (id)init
{
	if (self = [super init])
		self.undoManager.levelsOfUndo = 10;

	return self;
}

- (instancetype)initWithComputerType:(Computer *)object typeName:(NSString *)typeName error:(NSError **)outError
{
	if ((self = object ? [super initWithType:typeName error:outError] : nil))
		computer = object;

	return self;
}

- (void)performUndo:(NSData *)data
{
	WindowController *windowController = self.windowControllers.firstObject;

	[windowController stopComputer];

	[self.undoManager registerUndoWithTarget:self
									selector:@selector(performUndo:)
									  object:[NSKeyedArchiver archivedDataWithRootObject:self.computer]];

	computer = [NSKeyedUnarchiver unarchiveObjectWithData:data];

	[windowController startComputer];
}

- (void)registerUndo:(NSString *)string
{
	@synchronized(self.computer)
	{
		[self.undoManager registerUndoWithTarget:self
										selector:@selector(performUndo:)
										  object:[NSKeyedArchiver archivedDataWithRootObject:self.computer]];

		[self.undoManager setActionName:string];
	}
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	DocumentController *documentController = DocumentController.sharedDocumentController;

	if ([typeName isEqualToString:documentController.defaultType])
	{
		@synchronized(self.computer)
		{
			return [NSKeyedArchiver archivedDataWithRootObject:self.computer];
		}
	}

	return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	@try
	{
		DocumentController *documentController = DocumentController.sharedDocumentController;

		id object;

		if ([typeName isEqualToString:documentController.defaultType])
		{
			object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		}
		else
		{
			object = [ComputerFactory computerFromData:data URL:self.fileURL];

			self.fileType = documentController.defaultType;
			self.fileURL = nil;
		}

		if ([object isKindOfClass:[Computer class]])
		{
			WindowController *windowController = self.windowControllers.firstObject;
			[windowController stopComputer];

			computer = object;

			[windowController startComputer];
			return YES;
		}
	}
	@catch(NSException *exception)
	{
		NSLog(@"%@", exception);
	}

	return NO;
}

- (void)makeWindowControllers
{
	[self addWindowController:[[WindowController alloc] initWithWindowNibName:@"Document"]];
}

- (NSString *)defaultDraftName
{
	return [self.computer.class title];
}

+ (BOOL)preservesVersions
{
	return YES;
}

+ (BOOL)autosavesInPlace
{
	return YES;
}

#ifdef DEBUG
- (void)dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
