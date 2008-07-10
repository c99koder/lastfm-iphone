#import "FMResultSet.h"
#import "FMDatabase.h"

@interface FMResultSet (Private)
- (NSMutableDictionary *)columnNameToIndexMap;
- (void)setColumnNameToIndexMap:(NSMutableDictionary *)value;
@end

@implementation FMResultSet

+ (id) resultSetWithStatement:(sqlite3_stmt *)stmt usingParentDatabase:(FMDatabase*)aDB; {
    
    FMResultSet *rs = [[FMResultSet alloc] init];
    
    [rs setPStmt:stmt];
    [rs setParentDB:aDB];
    
    return [rs autorelease];
}

- (id)init {
	self = [super init];
    if (self) {
        [self setColumnNameToIndexMap:[NSMutableDictionary dictionary]];
    }
	
	return self;
}


- (void)dealloc {
    [self close];
    
    [query autorelease];
    query = nil;
    
    [columnNameToIndexMap autorelease];
    columnNameToIndexMap = nil;
    
	[super dealloc];
}

- (void) close; {
    
    [parentDB setInUse:NO]; 
    
    if (!pStmt) {
        return;
    }
    
    /* Finalize the virtual machine. This releases all memory and other
    ** resources allocated by the sqlite3_prepare() call above.
    */
    int rc = sqlite3_finalize(pStmt);
    if (rc != SQLITE_OK) {
        NSLog(@"error finalizing for query: %@", [self query]);
    }
    
    pStmt = nil;
}

- (void) setupColumnNames {
    
    int columnCount = sqlite3_column_count(pStmt);
    
    int columnIdx = 0;
    for (columnIdx = 0; columnIdx < columnCount; columnIdx++) {
        [columnNameToIndexMap setObject:[NSNumber numberWithInt:columnIdx]
                                 forKey:[[NSString stringWithUTF8String:sqlite3_column_name(pStmt, columnIdx)] lowercaseString]];
    }
}

- (void) kvcMagic:(id)object {
    
    int columnCount = sqlite3_column_count(pStmt);
    
    int columnIdx = 0;
    for (columnIdx = 0; columnIdx < columnCount; columnIdx++) {
        
        const char *c = (const char *)sqlite3_column_text(pStmt, columnIdx);
        
        // check for a null row
        if (c) {
            NSString *s = [NSString stringWithUTF8String:c];
            
            [object setValue:s forKey:[NSString stringWithUTF8String:sqlite3_column_name(pStmt, columnIdx)]];
        }
    }
}

- (BOOL) next {
    
    int rc;
    BOOL retry;
    int numberOfRetries = 0;
    do {
        retry = NO;
        
        rc = sqlite3_step(pStmt);
        
        if (SQLITE_BUSY == rc) {
            // this will happen if the db is locked, like if we are doing an update or insert.
            // in that case, retry the step... and maybe wait just 10 milliseconds.
            retry = YES;
            usleep(20);
            
            if ([parentDB busyRetryTimeout] && (numberOfRetries++ > [parentDB busyRetryTimeout])) {
                [NSException raise:@"FMDatabaseException" format:@"Database too busy."];
            }
            
        }
        else if (SQLITE_DONE == rc || SQLITE_ROW == rc) {
            // all is well, let's return.
        }
        else if (SQLITE_ERROR == rc) {
            NSLog(@"Error calling sqlite3_step (%d: %s) rs", rc, sqlite3_errmsg([parentDB sqliteHandle]));
            [NSException raise:@"SQLITE_ERROR" format:@"sqlite3_step"];
        } 
        else if (SQLITE_MISUSE == rc) {
            // uh oh.
            NSLog(@"Error calling sqlite3_step (%d: %s) rs", rc, sqlite3_errmsg([parentDB sqliteHandle]));
            [NSException raise:@"SQLITE_MISUSE" format:@"sqlite3_step"];
        }
        else {
            // wtf?
            NSLog(@"Unknown error calling sqlite3_step (%d: %s) rs", rc, sqlite3_errmsg([parentDB sqliteHandle]));
            [NSException raise:@"sqlite unknown rs" format:@"sqlite3_step"];
        }
        
    } while (retry);
    
    if (!columnNamesSetup) {
        [self setupColumnNames];
    }
    
    if (rc != SQLITE_ROW) {
        [self close];
    }
    
    return (rc == SQLITE_ROW);
}

- (int) columnIndexForName:(NSString*)columnName {
    
    columnName = [columnName lowercaseString];
    
    NSNumber *n = [columnNameToIndexMap objectForKey:columnName];
    
    if (n) {
        return [n intValue];
    }
    
    NSLog(@"Warning: I could not find the column named '%@'.", columnName);
    
    return -1;
}



- (int) intForColumn:(NSString*)columnName; {
    
    int columnIdx = [self columnIndexForName:columnName];
    
    if (columnIdx == -1) {
        return 0;
    }
    
    return sqlite3_column_int(pStmt, columnIdx);
}
- (int) intForColumnIndex:(int)columnIdx; {
    return sqlite3_column_int(pStmt, columnIdx);
}

- (long) longForColumn:(NSString*)columnName; {
    
    int columnIdx = [self columnIndexForName:columnName];
    
    if (columnIdx == -1) {
        return 0;
    }
    
    return sqlite3_column_int64(pStmt, columnIdx);
}
- (long) longForColumnIndex:(int)columnIdx; {
    return sqlite3_column_int64(pStmt, columnIdx);
}

- (BOOL) boolForColumn:(NSString*)columnName; {
    return ([self intForColumn:columnName] != 0);
}

- (BOOL) boolForColumnIndex:(int)columnIdx; {
    return ([self intForColumnIndex:columnIdx] != 0);
}

- (double) doubleForColumn:(NSString*)columnName; {
    
    int columnIdx = [self columnIndexForName:columnName];
    
    if (columnIdx == -1) {
        return 0;
    }
    
    return sqlite3_column_double(pStmt, columnIdx);
}

- (double) doubleForColumnIndex:(int)columnIdx; {
    return sqlite3_column_double(pStmt, columnIdx);
}


#pragma mark string functions

- (NSString*) stringForColumnIndex:(int)columnIdx; {
    
    const char *c = (const char *)sqlite3_column_text(pStmt, columnIdx);
    
    if (!c) {
        // null row.
        return nil;
    }
    
    return [NSString stringWithUTF8String:c];
}

- (NSString*) stringForColumn:(NSString*)columnName; {
    
    int columnIdx = [self columnIndexForName:columnName];
    
    if (columnIdx == -1) {
        return nil;
    }
    
    return [self stringForColumnIndex:columnIdx];
}




- (NSDate*) dateForColumn:(NSString*)columnName; {
    int columnIdx = [self columnIndexForName:columnName];
    
    if (columnIdx == -1) {
        return nil;
    }
    
    return [NSDate dateWithTimeIntervalSince1970:[self doubleForColumn:columnName]];
}

- (NSDate*) dateForColumnIndex:(int)columnIdx; {
    return [NSDate dateWithTimeIntervalSince1970:[self doubleForColumnIndex:columnIdx]];
}


- (NSData*) dataForColumn:(NSString*)columnName; {
    int columnIdx = [self columnIndexForName:columnName];
    
    if (columnIdx == -1) {
        return nil;
    }
    
    int dataSize = sqlite3_column_bytes(pStmt, columnIdx);
    
    NSMutableData *data = [NSMutableData dataWithLength:dataSize];
    
    memcpy([data mutableBytes], sqlite3_column_blob(pStmt, columnIdx), dataSize);
    
    return data;
}

- (NSData*) dataForColumnIndex:(int)columnIdx; {
    
    int dataSize = sqlite3_column_bytes(pStmt, columnIdx);
    
    NSMutableData *data = [NSMutableData dataWithLength:dataSize];
    
    memcpy([data mutableBytes], sqlite3_column_blob(pStmt, columnIdx), dataSize);
    
    return data;
}



- (void)setPStmt:(sqlite3_stmt *)newsqlite3_stmt {
    pStmt = newsqlite3_stmt;
}

- (void)setParentDB:(FMDatabase *)newDb;{
    parentDB = newDb;
}


- (NSString *)query {
    return query;
}

- (void)setQuery:(NSString *)value {
    [value retain];
    [query release];
    query = value;
}

- (NSMutableDictionary *)columnNameToIndexMap {
    return columnNameToIndexMap;
}

- (void)setColumnNameToIndexMap:(NSMutableDictionary *)value {
    [value retain];
    [columnNameToIndexMap release];
    columnNameToIndexMap = value;
}




@end
