#import "Retro80.h"

// -----------------------------------------------------------------------------
// Документ, содержащий тот или иной компьютер
// -----------------------------------------------------------------------------

@implementation Document

- (void) undo:(NSData *)data
{
	[self undoPoint:nil];

	[self.computer stop];
	self.computer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	[self.windowControllers.firstObject windowDidLoad];
}

- (void) undoPoint:(NSString *)actionName
{
	@synchronized(self.computer.snd)
	{
		if (![self.undoManager.undoActionName isEqualToString:actionName])
		{
			NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.computer];

			[self.undoManager registerUndoWithTarget:self
											selector:@selector(undo:)
											  object:data];

			if (actionName != nil)
			{
				[self.undoManager setActionName:NSLocalizedString(actionName, nil)];
			}
		}
	}
}

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

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
	@synchronized(self.computer.snd)
	{
		return [NSKeyedArchiver archivedDataWithRootObject:self.computer];
	}
}

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	NSData *data = [NSData dataWithContentsOfURL:url options:0 error:outError];

	if (data)
	{
		id object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		if ([object conformsToProtocol:@protocol(Computer)])
		{
			self.computer = object;
			return TRUE;
		}
	}

	return FALSE;
}

- (BOOL)revertToContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	[self.computer stop];

	if ([self readFromURL:url ofType:typeName error:outError])
	{
		[self.windowControllers.firstObject windowDidLoad];
		return TRUE;
	}

	[self.computer start];
	return FALSE;
}

@end
