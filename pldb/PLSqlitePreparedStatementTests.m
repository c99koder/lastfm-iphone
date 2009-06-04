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

@interface PLSqlitePreparedStatementTests : SenTestCase {
@private
    PLSqliteDatabase *_db;
}

@end

@implementation PLSqlitePreparedStatementTests

- (void) setUp {
    _db = [[PLSqliteDatabase alloc] initWithPath: @":memory:"];
    STAssertTrue([_db open], @"Couldn't open the test database");

    STAssertTrue([_db executeUpdate: @"CREATE TABLE test ("
                  "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                  "name VARCHAR(255),"
                  "color VARCHAR(255))"],
                 @"Could not create test table");
}

- (void) tearDown {
    [_db release];
}

- (void) testParameterCount {
    NSObject<PLPreparedStatement> *stmt;

    stmt = [_db prepareStatement: @"SELECT * FROM test WHERE name = (?)"];
    STAssertEquals(1, [stmt parameterCount], @"Incorrect parameter count");
}

- (void) testInUseHandling {
    NSObject<PLPreparedStatement> *stmt;
    NSObject<PLResultSet> *rs;
    
    /* Prepare the statement */
    stmt = [_db prepareStatement: @"SELECT * FROM test WHERE name = ?"];
    [stmt bindParameters: [NSArray arrayWithObjects: @"Johnny", nil]];

    /* First result set */
    rs = [stmt executeQuery];
    
    /* Should throw an exception */
    STAssertThrows([stmt executeQuery], @"Did not throw an exception re-executing query");
    STAssertThrows(([stmt bindParameters: [NSArray arrayWithObjects: @"Johnny", nil]]),
                   @"Did not throw an exception re-binding query");

    /* Close and try again (should not throw an exception) */
    [rs close];
    [[stmt executeQuery] close];
}

- (void) testClose {
    NSObject<PLPreparedStatement> *stmt;

    stmt = [_db prepareStatement: @"SELECT * FROM test WHERE name = ?"];
    [stmt close];
    STAssertThrows([stmt executeQuery], @"Did not throw an exception executing query on closed statement");
}


/* Test basic update and query support */
- (void) testUpdateAndQuery {
    NSObject<PLPreparedStatement> *stmt;
    NSObject<PLResultSet> *rs;

    /* Prepare the statement */
    stmt = [_db prepareStatement: @"INSERT INTO test (name, color) VALUES (?, ?)"];

    /* Insert twice */
    [stmt bindParameters: [NSArray arrayWithObjects: @"Johnny", @"blue", nil]];
    STAssertTrue([stmt executeUpdate], @"INSERT failed");

    [stmt bindParameters: [NSArray arrayWithObjects: @"Sarah", @"red", nil]];
    STAssertTrue([stmt executeUpdate], @"INSERT failed");

    /* Now check the values */
    stmt = [_db prepareStatement: @"SELECT * FROM test WHERE name = ?"];

    /* Johnny */
    [stmt bindParameters: [NSArray arrayWithObjects: @"Johnny", nil]];
    rs = [stmt executeQuery];

    STAssertNotNil(rs, @"Query failed");
    STAssertTrue([rs next], @"No results returned");

    STAssertFalse([rs isNullForColumn: @"id"], @"ID column wasn't set");
    STAssertTrue([@"Johnny" isEqual: [rs stringForColumn: @"name"]], @"Name set incorrectly");
    STAssertTrue([@"blue" isEqual: [rs stringForColumn: @"color"]], @"Color set incorrectly");
    [rs close];

    /* Sarah */
    [stmt bindParameters: [NSArray arrayWithObjects: @"Sarah", nil]];
    rs = [stmt executeQuery];
    
    STAssertNotNil(rs, @"Query failed");
    STAssertTrue([rs next], @"No results returned");

    STAssertFalse([rs isNullForColumn: @"id"], @"ID column wasn't set");
    STAssertTrue([@"Sarah" isEqual: [rs stringForColumn: @"name"]], @"Name set incorrectly");
    STAssertTrue([@"red" isEqual: [rs stringForColumn: @"color"]], @"Color set incorrectly");
    [rs close];
}


/* Test dictionary-based binding */
- (void) testBindParameterDictionary {
    NSObject<PLPreparedStatement> *stmt;
    NSMutableDictionary *parameters;

    /* Prepare the statement */
    stmt = [_db prepareStatement: @"INSERT INTO test (name, color) VALUES (:name, :color)"];
    
    /* Create the parameter dictionary */
    parameters = [NSMutableDictionary dictionaryWithCapacity: 2];
    [parameters setObject: @"Appleseed" forKey: @"name"];
    [parameters setObject: @"blue" forKey: @"color"];

    /* Bind and insert our values */
    [stmt bindParameterDictionary: parameters];
    STAssertTrue([stmt executeUpdate], @"INSERT failed");

    /* Fetch the inserted data */
    NSObject<PLResultSet> *rs = [_db executeQuery: @"SELECT * FROM test WHERE color = ?", @"blue"];
    STAssertTrue([rs next], @"No data returned");
    STAssertTrue([@"Appleseed" isEqual: [rs stringForColumn: @"name"]], @"Name incorrectly bound");
    STAssertTrue([@"blue" isEqual: [rs stringForColumn: @"color"]], @"Color incorrectly bound");
}


/* Test handling of all supported parameter data types */
- (void) testBindParameters {
    NSObject<PLPreparedStatement> *stmt;
    NSObject<PLResultSet> *rs;

    /* Create the data table */
    STAssertTrue([_db executeUpdate: @"CREATE TABLE data ("
           "intval int,"
           "int64val int,"
           "stringval varchar(30),"
           "nilval int,"
           "floatval float,"
           "doubleval double precision,"
           "dateval double precision,"
           "dataval blob"
           ")"], @"Could not create table");

    /* Prepare the insert statement */
    stmt = [_db prepareStatement: @"INSERT INTO data (intval, int64val, stringval, nilval, floatval, doubleval, dateval, dataval)"
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)"];
    STAssertNotNil(stmt, @"Could not create statement");
    
    /* Some example data */
    NSDate *now = [NSDate date];
    const char bytes[] = "This is some example test data";
    NSData *data = [NSData dataWithBytes: bytes length: sizeof(bytes)];

    /* Create our parameter list */
    NSArray *values = [NSArray arrayWithObjects:
        [NSNumber numberWithInt: 42],
        [NSNumber numberWithLongLong: INT64_MAX],
        @"test",
        [NSNull null],
        [NSNumber numberWithFloat: 3.14],
        [NSNumber numberWithDouble: 3.14159],
        now,
        data,
        nil
    ];

    /* Bind our values */
    [stmt bindParameters: values];

    /* Execute the update */
    STAssertTrue([stmt executeUpdate], @"INSERT failed");
    
	/* Execute the query */
    rs = [_db executeQuery: @"SELECT * FROM data WHERE intval = 42"];
    STAssertNotNil(rs, @"Query failed");
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

@end
