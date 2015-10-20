#import "Retro80.h"

// -----------------------------------------------------------------------------
// Документ, содержащий тот или иной компьютер
// -----------------------------------------------------------------------------

@implementation Document
{
	NSInteger lastUndoType;
	SEL lastUndoAction;
}

// -----------------------------------------------------------------------------
// Инициализация
// -----------------------------------------------------------------------------

- (id) init
{
	if (self = [super init])
	{
		self.undoManager.levelsOfUndo = 100;
	}

	return self;
}

- (id) initWithComputer:(Computer *)computer type:(NSString *)typeName error:(NSError **)outError
{
	if (self = [super initWithType:typeName error:outError])
	{
		self.computer = computer;
	}

	return self;
}

// -----------------------------------------------------------------------------
// Undo/Redo
// -----------------------------------------------------------------------------

- (void) performUndo:(NSData *)data
{
	[self.windowControllers.firstObject windowWillClose:[NSNotification notificationWithName:NSWindowWillCloseNotification object:nil]];

	[self.undoManager registerUndoWithTarget:self
									selector:lastUndoAction = @selector(performUndo:)
									  object:[NSKeyedArchiver archivedDataWithRootObject:self.computer]];

	lastUndoType = 0; lastUndoAction = nil;

	self.computer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	[self.windowControllers.firstObject windowDidLoad];
}

// -----------------------------------------------------------------------------

- (void) registerUndoWitString:(NSString *)string type:(NSInteger)type
{
	@synchronized(self.sound)
	{
		if (type != lastUndoType)
		{
			[self.undoManager registerUndoWithTarget:self
											selector:@selector(performUndo:)
											  object:[NSKeyedArchiver archivedDataWithRootObject:self.computer]];

			lastUndoType = type; lastUndoAction = nil;
			[self.undoManager setActionName:string];
		}
	}
}

// -----------------------------------------------------------------------------

- (void) registerUndoWithMenuItem:(NSMenuItem *)menuItem
{
	@synchronized(self.sound)
	{
		if (lastUndoType || menuItem.action != lastUndoAction)
		{
			[self.undoManager registerUndoWithTarget:self
											selector:@selector(performUndo:)
											  object:[NSKeyedArchiver archivedDataWithRootObject:self.computer]];

			lastUndoType = 0; lastUndoAction = menuItem.action;
			[self.undoManager setActionName:menuItem.title];
		}
	}
}

// -----------------------------------------------------------------------------
// Save/Load
// -----------------------------------------------------------------------------

- (NSData *) dataOfType:(NSString *)typeName error:(NSError **)outError
{
	@synchronized(self.sound)
	{
		return [NSKeyedArchiver archivedDataWithRootObject:self.computer];
	}
}

- (BOOL) readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError
{
	@try
	{
		DocumentController *documentController = [DocumentController sharedDocumentController];

		id object; if ([typeName isEqualToString:documentController.defaultType])
		{
			object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		}
		else
		{
			object = [documentController computerByFileExtension:self.fileURL data:data];
			self.fileURL = nil;
		}

		if ([object isKindOfClass:[Computer class]])
		{
			if (self.computer)
			{
				[self.windowControllers.firstObject windowWillClose:[NSNotification notificationWithName:NSWindowWillCloseNotification object:nil]];
				self.computer = object;
				[self.windowControllers.firstObject windowDidLoad];
			}
			else
			{
				self.computer = object;
			}

			return TRUE;
		}
	}

	@catch (NSException *exception)
	{
		NSLog(@"%@", exception);
	}

	*outError = nil;
	return FALSE;
}

// -----------------------------------------------------------------------------
// NSDocument
// -----------------------------------------------------------------------------

- (void) makeWindowControllers
{
	[self addWindowController:[[WindowController alloc] initWithWindowNibName:@"Document" owner:self]];
}

- (NSString *) defaultDraftName
{
	if (self.computer)
		return [[self.computer class] title];
	else
		return [super defaultDraftName];
}

+ (BOOL) preservesVersions
{
	return YES;
}

+ (BOOL) autosavesInPlace
{
    return YES;
}

// -----------------------------------------------------------------------------
// DEBUG: dealloc
// -----------------------------------------------------------------------------

#ifdef DEBUG
- (void) dealloc
{
	NSLog(@"%@ dealloc", NSStringFromClass(self.class));
}
#endif

@end
