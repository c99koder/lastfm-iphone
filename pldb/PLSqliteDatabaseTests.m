/*
 * Copyright (c) 2008 Plausible Labs Cooperative, Inc.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of any contributors
 *    may be used to endorse or promote products derived from this
 *    software without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import <SenTestingKit/SenTestingKit.h>

#import "PlausibleDatabase.h"

@interface PLSqliteDatabaseTests : SenTestCase {
@private
    PLSqliteDatabase *_db;
}

@end


@implementation PLSqliteDatabaseTests

- (void) setUp {
    _db = [[PLSqliteDatabase alloc] initWithPath: @":memory:"];
    STAssertTrue([_db open], @"Couldn't open the test database");
}

- (void) tearDown {
    [_db release];
}

- (void) testInitWithPath {
    PLSqliteDatabase *db = [[[PLSqliteDatabase alloc] initWithPath:  @":memory:"] autorelease];
    STAssertNotNil(db, @"Returned database is nil");
}


- (void) testOpen {
    PLSqliteDatabase *db = [[[PLSqliteDatabase alloc] initWithPath:  @":memory:"] autorelease];
    STAssertTrue([db open], @"Could not open the database");
    STAssertTrue([db goodConnection], @"The database did not report a good connection");
    [db close];
}


- (void) testOpenAndReturnError {
    NSError *error;

    PLSqliteDatabase *db = [PLSqliteDatabase databaseWithPath: @"/will/fail/with/a/path/that/can/not/be/opened"];
    STAssertFalse([db openAndReturnError: &error], @"Database was opened, and it should not have been");
    STAssertNotNil(error, @"Returned error was nil");
    STAssertTrue([PLDatabaseErrorDomain isEqual: [error domain]], @"Incorrect error domain");
    [db close];
}

- (void) testGoodConnection {
    PLSqliteDatabase *db = [[[PLSqliteDatabase alloc] initWithPath:  @":memory:"] autorelease];
    STAssertTrue([db open], @"Could not open the database");
    STAssertTrue([db goodConnection], @"The database did not report a good connection");
    [db close];
    STAssertFalse([db goodConnection], @"The database reported a good connection");
}


- (void) testPrepareStatement {
    NSObject<PLPreparedStatement> *stmt;

    /* Create a test table */
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a VARCHAR(10), b VARCHAR(20), c BOOL)"], @"Create table failed");
    
    /* Prepare a statement */
    stmt = [_db prepareStatement: @"INSERT INTO test (a) VALUES (?)" error: nil];
    STAssertNotNil(stmt, @"Could not prepare statement");
}


- (void) testExecuteUpdate {
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a VARCHAR(10), b VARCHAR(20), c BOOL)"], @"Create table failed");
    STAssertTrue([_db tableExists: @"test"], @"Table 'test' not created");
}


/* Verify that the autoreleased statements are explicitly closed when using executeUpdate
 * Issue #6 */
- (void) testUpdateStatementClosure {
    PLSqliteDatabase *db = [[PLSqliteDatabase alloc] initWithPath: @":memory:"];
    NSError *error = nil;
    [db open];

    STAssertTrue([db executeUpdateAndReturnError: &error statement: @"CREATE TABLE test (a VARCHAR(12), b VARCHAR(20))"], @"Create table failed: %@", error);
    
	NSObject<PLPreparedStatement> *stmt = [db prepareStatement:@"INSERT INTO test (a, b) VALUES(:a, :b)"];
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	[dict setObject:@"test category" forKey:@"a"];
	[dict setObject:@"test domain" forKey:@"b"];
	[stmt bindParameterDictionary:dict];
    
	[db beginTransaction];
	STAssertTrue([stmt executeUpdate], @"INSERT failed");
	[db commitTransaction];

	[stmt close];
	[db close];
	[db release];
}


/* Verify that the autoreleased statements are explicitly closed when using executeQuery
 * Issue #6 */
- (void) testExecuteStatementClosure {
    PLSqliteDatabase *db = [[PLSqliteDatabase alloc] initWithPath: @":memory:"];
    NSError *error = nil;
    [db open];
    
    STAssertTrue([db executeUpdateAndReturnError: &error statement: @"CREATE TABLE test (a VARCHAR(12), b VARCHAR(20))"], @"Create table failed: %@", error);
    STAssertTrue(([db executeUpdateAndReturnError: &error statement: @"INSERT INTO test VALUES (?, ?)", @"foo", @"bar"]), @"Data insert failed %@", error);
    
    NSObject<PLResultSet> *resultSet = [db executeQuery: @"SELECT * FROM test"];

	[resultSet close];
	[db close];
	[db release];
}


- (void) testExecuteUpdateQueryParams {
    NSObject<PLResultSet> *rs;

    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a int)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithInt: 42]]), @"Could not insert row");

    rs = [_db executeQuery: @"SELECT a FROM test WHERE a = 42"];
    STAssertTrue([rs next], @"No rows returned");
}


- (void) testExecuteQueryNoParameters {
    NSObject<PLResultSet> *result = [_db executeQuery: @"PRAGMA user_version"];
    STAssertNotNil(result, @"No result returned from query");
    STAssertTrue([result next], @"No rows were returned");
}

/* Test handling of all supported parameter data types */
- (void) testParameterHandling {
	NSObject<PLResultSet> *rs;
	BOOL ret;
    NSDate *now = [NSDate date];
    const char bytes[] = "This is some example test data";
    NSData *data = [NSData dataWithBytes: bytes length: sizeof(bytes)];

	/* Create the test table */
    ret = [_db executeUpdate: @"CREATE TABLE test ("
           "intval int,"
           "int64val int,"
           "stringval varchar(30),"
           "nilval int,"
           "floatval float,"
           "doubleval double precision,"
           "dateval double precision,"
           "dataval blob"
           ")"];
	STAssertTrue(ret, nil);

	/* Insert the test data */
    ret = [_db executeUpdate: @"INSERT INTO test "
           "(intval, int64val, stringval, nilval, floatval, doubleval, dateval, dataval)"
           "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
		   [NSNumber numberWithInt: 42],
           [NSNumber numberWithLongLong: INT64_MAX],
           @"test",
           nil,
           [NSNumber numberWithFloat: 3.14],
           [NSNumber numberWithDouble: 3.14159],
           now,
           data];
	STAssertTrue(ret, nil);

	/* Retrieve the data */
    rs = [_db executeQuery: @"SELECT * FROM test WHERE intval = 42"];
    STAssertTrue([rs next], @"No rows returned");

    /* NULL value */
    STAssertTrue([rs isNullForColumn: @"nilval"], @"NULL value not returned.");
    
    /* Date value */
    STAssertEquals([now timeIntervalSince1970], [[rs dateForColumn: @"dateval"] timeIntervalSince1970], @"Date value incorrect.");
    
    /* String */
    STAssertTrue([@"test" isEqual: [rs stringForColumn: @"stringval"]], @"String value incorrect.");

    /* Integer */
    STAssertEquals(42, [rs intForColumn: @"intval"], @"Integer value incorrect.");
    
    /* 64-bit integer value */
    STAssertEquals(INT64_MAX, [rs bigIntForColumn: @"int64val"], @"64-bit integer value incorrect");

    /* Float */
    STAssertEquals(3.14f, [rs floatForColumn: @"floatval"], @"Float value incorrect");

    /* Double */
    STAssertEquals(3.14159, [rs doubleForColumn: @"doubleval"], @"Double value incorrect");
    
    /* Data */
    STAssertTrue([data isEqualToData: [rs dataForColumn: @"dataval"]], @"Data value incorrect");
}

- (void) testBeginAndRollbackTransaction {
    STAssertTrue([_db beginTransaction], @"Could not start a transaction");
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a int)"], @"Could not create test table");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithInt: 42]]), @"Inserting test data failed");
    STAssertTrue([_db tableExists: @"test"], @"Table was not created");
    STAssertTrue([_db rollbackTransaction], @"Could not roll back");
    STAssertFalse([_db tableExists: @"test"], @"Table was not rolled back");
}


- (void) testBeginAndCommitTransaction {
    STAssertTrue([_db beginTransaction], @"Could not start a transaction");
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a int)"], @"Could not create test table");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithInt: 42]]), @"Inserting test data failed");
    STAssertTrue([_db tableExists: @"test"], @"Table was not created");
    STAssertTrue([_db commitTransaction], @"Could not commit");
    STAssertTrue([_db tableExists: @"test"], @"Table was not comitted");
}

- (void) testTableExists {
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a VARCHAR(10), b VARCHAR(20), c BOOL)"], @"Create table failed");
    STAssertTrue([_db tableExists: @"test"], @"These are not the tables you are looking for");
    STAssertFalse([_db tableExists: @"not exists"], @"Returned true on non-existent table");
}

- (void) testLastInsertRowId {
    NSObject<PLResultSet> *rs;
    int64_t rowId;
    
    /* Create test table */
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a INTEGER PRIMARY KEY AUTOINCREMENT, b INTEGER)"], @"Create table failed");
    STAssertTrue([_db tableExists: @"test"], @"Table 'test' not created");
    
    /* Insert test data */
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a, b) VALUES (?, ?)", nil, [NSNumber numberWithInt: 42]]), @"Inserting test data failed");
    rowId = [_db lastInsertRowId];
    
    /* Try to fetch the test data again */
    rs = [_db executeQuery: @"SELECT b FROM test WHERE rowId = ?", [NSNumber numberWithLongLong: rowId]];
    STAssertTrue([rs next], @"No result returned");
    STAssertEquals(42, [rs intForColumn: @"b"], @"Did not retrieve expected column");
}

- (void) testLastError {
    STAssertNotNil([_db lastErrorMessage], @"Initial last error message was nil.");
    STAssertEquals(SQLITE_OK, [_db lastErrorCode], @"Initial last error code was not SQLITE_OK");
}


@end
