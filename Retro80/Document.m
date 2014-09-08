#import "Retro80.h"

// -----------------------------------------------------------------------------
// Документ, содержащий тот или иной компьютер
// -----------------------------------------------------------------------------

@implementation Document

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

// -----------------------------------------------------------------------------
// Undo/Redo
// -----------------------------------------------------------------------------

- (void) performUndo:(NSData *)data
{
	[self.computer stop]; [self.computer.crt removeFromSuperviewWithoutNeedingDisplay];

	[self.undoManager registerUndoWithTarget:self
									selector:@selector(performUndo:)
									  object:[NSKeyedArchiver archivedDataWithRootObject:self.computer]];

	self.computer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	self.computer.document = self;

	[self.windowControllers.firstObject windowDidLoad];
}

- (void) performUndoMenuItem:(NSMenuItem *)menuItem
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
	[self.computer performSelector:menuItem.action withObject:menuItem];
#pragma clang diagnostic pop
}

// -----------------------------------------------------------------------------

- (void) registerUndoMenuItem:(NSMenuItem *)menuItem
{
	[self.undoManager registerUndoWithTarget:self
									selector:@selector(performUndoMenuItem:)
									  object:menuItem];

	[self.undoManager setActionName:menuItem.title];
}

// -----------------------------------------------------------------------------

- (void) registerUndo:(NSString *)actionName
{
	@synchronized(self.computer.snd)
	{
		if (![self.undoManager.undoActionName isEqualToString:actionName])
		{
			[self.undoManager registerUndoWithTarget:self
											selector:@selector(performUndo:)
											  object:[NSKeyedArchiver archivedDataWithRootObject:self.computer]];

			[self.undoManager setActionName:actionName];
		}
	}
}

// -----------------------------------------------------------------------------
//
// -----------------------------------------------------------------------------

- (NSString *) defaultDraftName
{
	if (self.computer)
	{
		return [[self.computer class] title];
	}
	else
	{
		return [super defaultDraftName];
	}
}

- (void) makeWindowControllers
{
	[self addWindowController:[[WindowController alloc] initWithWindowNibName:@"Document"]];
}

+ (BOOL) autosavesInPlace
{
    return YES;
}

- (NSData *) dataOfType:(NSString *)typeName error:(NSError **)outError
{
	@synchronized(self.computer.snd)
	{
		return [NSKeyedArchiver archivedDataWithRootObject:self.computer];
	}
}

- (BOOL) readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	NSData *data = [NSData dataWithContentsOfURL:url options:0 error:outError];

	if (data)
	{
		id object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		if ([object isKindOfClass:[Computer class]])
		{
			self.computer = object;
			return TRUE;
		}
	}

	return FALSE;
}

- (BOOL) revertToContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	[self.computer stop];

	Screen *screen = self.computer.crt;

	if ([self readFromURL:url ofType:typeName error:outError])
	{
		[screen removeFromSuperviewWithoutNeedingDisplay];
		[self.windowControllers.firstObject windowDidLoad];
		return TRUE;
	}

	[self.computer start];
	return FALSE;
}

@end
