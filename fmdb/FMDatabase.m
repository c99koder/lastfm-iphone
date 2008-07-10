#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@implementation FMDatabase

+ (id)databaseWithPath:(NSString*)aPath {
    return [[[FMDatabase alloc] initWithPath:aPath] autorelease];
}

- (id)initWithPath:(NSString*)aPath {
    self = [super init];
	
    if (self) {
        databasePath        = [aPath copy];
        db                  = 0x00;
        logsErrors          = 0x00;
        crashOnErrors       = 0x00;
        busyRetryTimeout    = 0x00;
    }
	
	return self;
}

- (void)dealloc {
	[self close];
	[databasePath release];
	[super dealloc];
}

+ (NSString*) sqliteLibVersion {
    return [NSString stringWithFormat:@"%s", sqlite3_libversion()];
}

- (sqlite3*) sqliteHandle {
    return db;
}

- (BOOL) open {
	int err = sqlite3_open( [databasePath fileSystemRepresentation], &db );
	if(err != SQLITE_OK) {
        NSLog(@"error opening!: %d", err);
		return NO;
	}
	
	return YES;
}

- (void) close {
	if (!db) {
        return;
    }
    
    int  rc;
    BOOL retry;
    int numberOfRetries = 0;
    do {
        retry   = NO;
        rc      = sqlite3_close(db);
        if (SQLITE_BUSY == rc) {
            retry = YES;
            usleep(20);
            if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
                [NSException raise:@"FMDatabaseException" format:@"Database too busy."];
            }
        }
        else if (SQLITE_OK != rc) {
            NSLog(@"error closing!: %d", rc);
        }
    }
    while (retry);
    
	db = nil;
}


- (BOOL) goodConnection {
    FMResultSet *rs = [self executeQuery:@"select name from sqlite_master where type='table'"];
    
    if (rs) {
        [rs close];
        return YES;
    }
    
    return NO;
}

- (void) compainAboutInUse {
    NSLog(@"The FMDatabase %@ is currently in use.", self);
    
    if (crashOnErrors) {
        [NSException raise:@"FMDatabase in use" format:@"The FMDatabase %@ is currently in use.", self];
    }
    
}

- (NSString*) lastErrorMessage {
    return [NSString stringWithUTF8String:sqlite3_errmsg(db)];
}

- (BOOL) hadError {
    return ([self lastErrorCode] != SQLITE_OK);
}

- (int) lastErrorCode {
    return sqlite3_errcode(db);
}

- (sqlite_int64) lastInsertRowId {
    
    if (inUse) {
        [self compainAboutInUse];
        return NO;
    }
    [self setInUse:YES];
    
    sqlite_int64 ret = sqlite3_last_insert_rowid(db);
    
    [self setInUse:NO];
    
    return ret;
}

- (void) bindObject:(id)obj toColumn:(int)idx inStatement:(sqlite3_stmt*)pStmt; {
    
    // FIXME - someday check the return codes on these binds.
    if ([obj isKindOfClass:[NSData class]]) {
        sqlite3_bind_blob(pStmt, idx, [obj bytes], [obj length], SQLITE_STATIC);
    }
    else if ([obj isKindOfClass:[NSDate class]]) {
        sqlite3_bind_double(pStmt, idx, [obj timeIntervalSince1970]);
    }
    else if ([obj isKindOfClass:[NSNumber class]]) {
        
        if (strcmp([obj objCType], @encode(BOOL)) == 0) {
            sqlite3_bind_int(pStmt, idx, ([obj boolValue] ? 1 : 0));
        }
        else if (strcmp([obj objCType], @encode(int)) == 0) {
            sqlite3_bind_int64(pStmt, idx, [obj longValue]);
        }
        else if (strcmp([obj objCType], @encode(float)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj floatValue]);
        }
        else if (strcmp([obj objCType], @encode(double)) == 0) {
            sqlite3_bind_double(pStmt, idx, [obj doubleValue]);
        }
        else {
            sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
        }
    }
    else {
        sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
    }
}

- (id) executeQuery:(NSString*)objs, ... {
    
    if (inUse) {
        [self compainAboutInUse];
        return nil;
    }
    [self setInUse:YES];
    
    FMResultSet *rs = nil;
    
    NSString *sql = objs;
    int rc;
    sqlite3_stmt *pStmt;
    
    if (traceExecution && sql) {
        NSLog(@"FMDatabase executeQuery: %@", sql);
    }
    
    int numberOfRetries = 0;
    BOOL retry;
    do {
        retry   = NO;
        rc      = sqlite3_prepare(db, [sql UTF8String], -1, &pStmt, 0);
        
        if (SQLITE_BUSY == rc) {
            retry = YES;
            usleep(20);
            
            if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
                [NSException raise:@"FMDatabaseException" format:@"Database too busy."];
            }
        }
        else if (SQLITE_OK != rc) {
            
            rc = sqlite3_finalize(pStmt);
            
            if (logsErrors) {
                NSLog(@"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                NSLog(@"DB Query: %@", sql);
                if (crashOnErrors) {
                    [NSException raise:@"FMDatabaseException" format:@"(%d) \"%@\"", [self lastErrorCode], [self lastErrorMessage]];
                }
            }
            
            [self setInUse:NO];
            return nil;
        }
    }
    while (retry);
    
    id obj;
    int idx = 0;
    int queryCount = sqlite3_bind_parameter_count(pStmt); // pointed out by Dominic Yu (thanks!)
    va_list argList;
    va_start(argList, objs);
    
    while (idx < queryCount) {
        obj = va_arg(argList, id);
        idx++;
        
        [self bindObject:obj toColumn:idx inStatement:pStmt];
        
    }
    
    va_end(argList);
    
    // the statement gets close in rs's dealloc or [rs close];
    rs = [FMResultSet resultSetWithStatement:pStmt usingParentDatabase:self];
    [rs setQuery:sql];
    
    return rs;
}


- (BOOL) executeUpdate:(NSString*)objs, ... {
    
    if (inUse) {
        [self compainAboutInUse];
        return NO;
    }
    [self setInUse:YES];
    
    NSString *sql       = objs;
    int rc              = 0x00;
    sqlite3_stmt *pStmt = 0x00;
    
    if (traceExecution && sql) {
        NSLog(@"FMDatabase executeUpdate: %@", sql);
    }
    
    int numberOfRetries = 0;
    BOOL retry;
    do {
        retry   = NO;
        rc      = sqlite3_prepare(db, [sql UTF8String], -1, &pStmt, 0);
        if (SQLITE_BUSY == rc) {
            retry = YES;
            usleep(20);
            if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
                [NSException raise:@"FMDatabaseException" format:@"Database too busy."];
            }
        }
        else if (SQLITE_OK != rc) {
            int ret = rc;
            rc = sqlite3_finalize(pStmt);
            
            if (logsErrors) {
                NSLog(@"DB Error: %d \"%@\"", [self lastErrorCode], [self lastErrorMessage]);
                NSLog(@"DB Query: %@", sql);
                if (crashOnErrors) {
                    [NSException raise:@"FMDatabaseException" format:@"(%d) \"%@\"", [self lastErrorCode], [self lastErrorMessage]];
                }
            }
            
            [self setInUse:NO];
            return ret;
        }
    }
    while (retry);
    
    
    id obj;
    int idx = 0;
    int queryCount = sqlite3_bind_parameter_count(pStmt);
    va_list argList;
    va_start(argList, objs);
    
    while (idx < queryCount) {
        
        obj = va_arg(argList, id);
        idx++;
        
        [self bindObject:obj toColumn:idx inStatement:pStmt];
    }
    
    va_end(argList);
    
    /* Call sqlite3_step() to run the virtual machine. Since the SQL being
    ** executed is not a SELECT statement, we assume no data will be returned.
    */
    numberOfRetries = 0;
    do {
        rc      = sqlite3_step(pStmt);
        retry   = NO;
        
        if (SQLITE_BUSY == rc) {
            // this will happen if the db is locked, like if we are doing an update or insert.
            // in that case, retry the step... and maybe wait just 10 milliseconds.
            retry = YES;
            usleep(20);
            if (busyRetryTimeout && (numberOfRetries++ > busyRetryTimeout)) {
                [NSException raise:@"FMDatabaseException" format:@"Database too busy."];
            }
        }
        else if (SQLITE_DONE == rc || SQLITE_ROW == rc) {
            // all is well, let's return.
        }
        else if (SQLITE_ERROR == rc) {
            NSLog(@"Error calling sqlite3_step (%d: %s) eu", rc, sqlite3_errmsg(db));
            NSLog(@"DB Query: %@", sql);
            [NSException raise:@"SQLITE_ERROR eu" format:@"sqlite3_step"];
        }
        else if (SQLITE_MISUSE == rc) {
            // uh oh.
            NSLog(@"Error calling sqlite3_step (%d: %s) eu", rc, sqlite3_errmsg(db));
            NSLog(@"DB Query: %@", sql);
            [NSException raise:@"SQLITE_MISUSE eu" format:@"sqlite3_step"];
        }
        else {
            // wtf?
            NSLog(@"Unknown error calling sqlite3_step (%d: %s) eu", rc, sqlite3_errmsg(db));
            NSLog(@"DB Query: %@", sql);
            [NSException raise:@"sqlite unknown eu" format:@"sqlite3_step"];
        }
        
    } while (retry);
    
    assert( rc!=SQLITE_ROW );
    
    /* Finalize the virtual machine. This releases all memory and other
    ** resources allocated by the sqlite3_prepare() call above.
    */
    rc = sqlite3_finalize(pStmt);
    
    [self setInUse:NO];
    
    return (rc == SQLITE_OK);
}

- (BOOL) rollback {
    BOOL b = [self executeUpdate:@"ROLLBACK TRANSACTION;"];
    if (b) {
        inTransaction = NO;
    }
    return b;
}

- (BOOL) commit {
    BOOL b =  [self executeUpdate:@"COMMIT TRANSACTION;"];
    if (b) {
        inTransaction = NO;
    }
    return b;
}

- (BOOL) beginDeferredTransaction {
    BOOL b =  [self executeUpdate:@"BEGIN DEFERRED TRANSACTION;"];
    if (b) {
        inTransaction = YES;
    }
    return b;
}

- (BOOL) beginTransaction {
    BOOL b =  [self executeUpdate:@"BEGIN EXCLUSIVE TRANSACTION;"];
    if (b) {
        inTransaction = YES;
    }
    return b;
}

- (BOOL)logsErrors {
    return logsErrors;
}
- (void)setLogsErrors:(BOOL)flag {
    logsErrors = flag;
}

- (BOOL)crashOnErrors {
    return crashOnErrors;
}
- (void)setCrashOnErrors:(BOOL)flag {
    crashOnErrors = flag;
}

- (BOOL)inUse {
    return inUse || inTransaction;
}
- (void)setInUse:(BOOL)flag {
    inUse = flag;
}

- (BOOL)inTransaction {
    return inTransaction;
}
- (void)setInTransaction:(BOOL)flag {
    inTransaction = flag;
}

- (BOOL)traceExecution {
    return traceExecution;
}
- (void)setTraceExecution:(BOOL)flag {
    traceExecution = flag;
}

- (BOOL)checkedOut {
    return checkedOut;
}
- (void)setCheckedOut:(BOOL)flag {
    checkedOut = flag;
}


- (int)busyRetryTimeout {
    return busyRetryTimeout;
}
- (void)setBusyRetryTimeout:(int)newBusyRetryTimeout {
    busyRetryTimeout = newBusyRetryTimeout;
}


@end
