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

// -----------------------------------------------------------------------------
// Undo/Redo
// -----------------------------------------------------------------------------

- (void) performUndo:(NSData *)data
{
	[self.computer stop]; [self.computer.crt removeFromSuperviewWithoutNeedingDisplay];

	[self.undoManager registerUndoWithTarget:self
									selector:lastUndoAction = @selector(performUndo:)
									  object:[NSKeyedArchiver archivedDataWithRootObject:self.computer]];

	lastUndoType = 0;

	self.computer = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	self.computer.document = self;

	[self.windowControllers.firstObject windowDidLoad];
}

// -----------------------------------------------------------------------------

- (void) registerUndoWitString:(NSString *)string type:(NSInteger)type
{
	@synchronized(self.computer.snd)
	{
		if (type != lastUndoType)
		{
			lastUndoType = type;

			[self.undoManager registerUndoWithTarget:self
											selector:@selector(performUndo:)
											  object:[NSKeyedArchiver archivedDataWithRootObject:self.computer]];

			[self.undoManager setActionName:string];
		}
	}
}

// -----------------------------------------------------------------------------

- (void) registerUndoWithMenuItem:(NSMenuItem *)menuItem
{
	@synchronized(self.computer.snd)
	{
		if (lastUndoType || menuItem.action != lastUndoAction)
		{
			lastUndoType = 0; lastUndoAction = menuItem.action;

			[self.undoManager registerUndoWithTarget:self
											selector:@selector(performUndo:)
											  object:[NSKeyedArchiver archivedDataWithRootObject:self.computer]];

			[self.undoManager setActionName:menuItem.title];
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

- (BOOL) readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
	@try
	{
		id object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
		if ([object isKindOfClass:[Computer class]])
		{
			if (self.computer)
			{
				[self.computer stop]; [self.computer.crt removeFromSuperviewWithoutNeedingDisplay];
				self.computer = object; [self.windowControllers.firstObject windowDidLoad];
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

	if (outError)
	{
		*outError = [NSError errorWithDomain:@"ru.uart.Retro80"
										code:2
									userInfo:nil];
	}

	return FALSE;
}

@end
