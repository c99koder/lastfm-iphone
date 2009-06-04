//
//  CXMLNode_CreationExtensions.h
//  WebDAVServer
//
//  Created by Jonathan Wight on 11/11/08.
//  Copyright 2008 toxicsoftware.com. All rights reserved.
//

#import "CXMLNode.h"

@class CXMLElement;

@interface CXMLNode (CXMLNode_CreationExtensions)

//- (id)initWithKind:(NSXMLNodeKind)kind;
//- (id)initWithKind:(NSXMLNodeKind)kind options:(NSUInteger)options; //primitive
+ (id)document;
+ (id)documentWithRootElement:(CXMLElement *)element;
+ (id)elementWithName:(NSString *)name;
+ (id)elementWithName:(NSString *)name URI:(NSString *)URI;
+ (id)elementWithName:(NSString *)name stringValue:(NSString *)string;
//+ (id)elementWithName:(NSString *)name children:(NSArray *)children attributes:(NSArray *)attributes;
//+ (id)attributeWithName:(NSString *)name stringValue:(NSString *)stringValue;
//+ (id)attributeWithName:(NSString *)name URI:(NSString *)URI stringValue:(NSString *)stringValue;
+ (id)namespaceWithName:(NSString *)name stringValue:(NSString *)stringValue;
+ (id)processingInstructionWithName:(NSString *)name stringValue:(NSString *)stringValue;
//+ (id)commentWithStringValue:(NSString *)stringValue;
//+ (id)textWithStringValue:(NSString *)stringValue;
//+ (id)DTDNodeWithXMLString:(NSString *)string;

- (void)setStringValue:(NSString *)inStringValue;

@end
