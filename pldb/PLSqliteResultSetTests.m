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

@interface PLSqliteResultSetTests : SenTestCase {
@private
    PLSqliteDatabase *_db;
}

@end

@implementation PLSqliteResultSetTests

- (void) setUp {
    _db = [[PLSqliteDatabase alloc] initWithPath: @":memory:"];
    STAssertTrue([_db open], @"Couldn't open the test database");
}

- (void) tearDown {
    [_db release];
}

/* Test close by trying to rollback a transaction after opening (and closing) a result set. */
- (void) testClose {
    /* Start the transaction and create the test data */
    STAssertTrue([_db beginTransaction], @"Could not start a transaction");
    
    /* Create a result, move to the first row, and then close it */
    NSObject<PLResultSet> *result = [_db executeQuery: @"PRAGMA user_version"];
    [result next];
    [result close];

    /* Roll back the transaction */
    STAssertTrue([_db rollbackTransaction], @"Could not roll back, was result actually closed?");
}

- (void) testColumnIndexForName {
    NSObject<PLResultSet> *result = [_db executeQuery: @"PRAGMA user_version"];
    STAssertEquals(0, [result columnIndexForName: @"user_version"], @"user_version column not found");
    STAssertEquals(0, [result columnIndexForName: @"USER_VERSION"], @"Column index lookup appears to be case sensitive.");

    STAssertThrows([result columnIndexForName: @"not_a_column"], @"Did not throw an exception for bad column");
}

- (void) testDateForColumn {
    NSObject<PLResultSet> *result;
    NSDate *now = [NSDate date];
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a date)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", now]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertEquals([now timeIntervalSince1970], [[result dateForColumn: @"a"] timeIntervalSince1970], @"Did not return correct date value");
}

- (void) testStringForColumn {
    NSObject<PLResultSet> *result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a varchar(30))"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", @"TestString"]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertTrue([@"TestString" isEqual: [result stringForColumn: @"a"]], @"Did not return correct string value");
}

- (void) testIntForColumn {
    NSObject<PLResultSet> *result = [_db executeQuery: @"PRAGMA user_version"];
    STAssertNotNil(result, @"No result returned from query");
    STAssertTrue([result next], @"No rows were returned");
    
    STAssertEquals(0, [result intForColumn: @"user_version"], @"Could not retrieve user_version column");
}

- (void) testBigIntForColumn {
    NSObject<PLResultSet> *result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a bigint)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithLongLong: INT64_MAX]]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertEquals(INT64_MAX, [result bigIntForColumn: @"a"], @"Did not return correct big integer value");
}

- (void) testBoolForColumn {
    NSObject<PLResultSet> *result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a bool)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithBool: YES]]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertTrue([result boolForColumn: @"a"], @"Did not return correct bool value");
}

- (void) testFloatForColumn {
    NSObject<PLResultSet> *result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a float)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithFloat: 3.14]]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertEquals(3.14f, [result floatForColumn: @"a"], @"Did not return correct float value");
}

- (void) testDoubleForColumn {
    NSObject<PLResultSet> *result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a double)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", [NSNumber numberWithDouble: 3.14159]]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertEquals(3.14159, [result doubleForColumn: @"a"], @"Did not return correct double value");
}

- (void) testDataForColumn {
    const char bytes[] = "This is some example test data";
    NSData *data = [NSData dataWithBytes: bytes length: sizeof(bytes)];
    NSObject<PLResultSet> *result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a blob)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", data]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertTrue([data isEqualToData: [result dataForColumn: @"a"]], @"Did not return correct data value");
}

- (void) testIsNullForColumn {
    NSObject<PLResultSet> *result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a integer)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", nil]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    STAssertTrue([result isNullForColumn: @"a"], @"Column value should be NULL");
}

/* Test that dereferencing a null value throws an exception. */
- (void) testNullValueException {
    NSObject<PLResultSet> *result;
    
    STAssertTrue([_db executeUpdate: @"CREATE TABLE test (a integer)"], @"Create table failed");
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a) VALUES (?)", nil]), @"Could not insert row");
    
    result = [_db executeQuery: @"SELECT a FROM test"];
    STAssertTrue([result next], @"No rows returned");
    
    STAssertThrows([result intForColumn: @"a"], @"Did not throw an exception for NULL column");
}

- (void) testObjectForColumn {
    NSObject<PLResultSet> *result;
    NSNumber *testInteger;
    NSString *testString;
    NSNumber *testDouble;
    NSData *testBlob;
    NSError *error;
    
    /* Initialize test data */
    testInteger = [NSNumber numberWithInt: 42];
    testString = @"Test string";
    testDouble = [NSNumber numberWithDouble: 42.42];
    testBlob = [@"Test data" dataUsingEncoding: NSUTF8StringEncoding]; 

    STAssertTrue([_db executeUpdateAndReturnError: &error statement: @"CREATE TABLE test (a integer, b varchar(20), c double, d blob, e varchar(20))"], @"Create table failed: %@", error);
    STAssertTrue(([_db executeUpdate: @"INSERT INTO test (a, b, c, d, e) VALUES (?, ?, ?, ?, ?)",
                   testInteger, testString, testDouble, testBlob, nil]), @"Could not insert row");
    
    /* Query the data */
    result = [_db executeQuery: @"SELECT * FROM test"];
    STAssertTrue([result next], @"No rows returned");
    
    STAssertTrue([testInteger isEqual: [result objectForColumn: @"a"]], @"Did not return correct integer value");
    STAssertTrue([testString isEqual: [result objectForColumn: @"b"]], @"Did not return correct string value");
    STAssertTrue([testDouble isEqual: [result objectForColumn: @"c"]], @"Did not return correct double value");
    STAssertTrue([testBlob isEqual: [result objectForColumn: @"d"]], @"Did not return correct data value");
    STAssertTrue([NSNull null] == [result objectForColumn: @"e"], @"Did not return correct NSNull value");
}

@end
