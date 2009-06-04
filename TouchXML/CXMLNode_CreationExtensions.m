//
//  CXMLNode_CreationExtensions.m
//  WebDAVServer
//
//  Created by Jonathan Wight on 11/11/08.
//  Copyright 2008 toxicsoftware.com. All rights reserved.
//

#import "CXMLNode_CreationExtensions.h"

#import "CXMLDocument.h"
#import "CXMLElement.h"
#import "CXMLNode_PrivateExtensions.h"
#import "CXMLDocument_PrivateExtensions.h"

@implementation CXMLNode (CXMLNode_CreationExtensions)

+ (id)document;
{
xmlDocPtr theDocumentNode = xmlNewDoc((const xmlChar *)"1.0");
NSAssert(theDocumentNode != NULL, @"xmlNewDoc failed");
CXMLDocument *theDocument = [[[CXMLDocument alloc] initWithLibXMLNode:(xmlNodePtr)theDocumentNode] autorelease];
return(theDocument);
}

+ (id)documentWithRootElement:(CXMLElement *)element;
{
xmlDocPtr theDocumentNode = xmlNewDoc((const xmlChar *)"1.0");
NSAssert(theDocumentNode != NULL, @"xmlNewDoc failed");
xmlDocSetRootElement(theDocumentNode, element.node);
CXMLDocument *theDocument = [[[CXMLDocument alloc] initWithLibXMLNode:(xmlNodePtr)theDocumentNode] autorelease];
[theDocument.nodePool addObject:element];
return(theDocument);
}

+ (id)elementWithName:(NSString *)name
{
xmlNodePtr theElementNode = xmlNewNode(NULL, (const xmlChar *)[name UTF8String]);
CXMLElement *theElement = [[[CXMLElement alloc] initWithLibXMLNode:(xmlNodePtr)theElementNode] autorelease];
return(theElement);
}

+ (id)elementWithName:(NSString *)name URI:(NSString *)URI
{
xmlNodePtr theElementNode = xmlNewNode(NULL, (const xmlChar *)[name UTF8String]);
xmlNsPtr theNSNode = xmlNewNs(theElementNode, (const xmlChar *)[URI UTF8String], NULL);
theElementNode->ns = theNSNode;

CXMLElement *theElement = [[[CXMLElement alloc] initWithLibXMLNode:(xmlNodePtr)theElementNode] autorelease];
return(theElement);
}

+ (id)elementWithName:(NSString *)name stringValue:(NSString *)string
{
xmlNodePtr theElementNode = xmlNewNode(NULL, (const xmlChar *)[name UTF8String]);
CXMLElement *theElement = [[[CXMLElement alloc] initWithLibXMLNode:(xmlNodePtr)theElementNode] autorelease];
theElement.stringValue = string;
return(theElement);
}

+ (id)namespaceWithName:(NSString *)name stringValue:(NSString *)stringValue
{
xmlNsPtr theNode = xmlNewNs(NULL, (const xmlChar *)[stringValue UTF8String], (const xmlChar *)[name UTF8String]);
NSAssert(theNode != NULL, @"xmlNewNs failed");
CXMLNode *theNodeObject = [[[CXMLNode alloc] initWithLibXMLNode:(xmlNodePtr)theNode] autorelease];
return(theNodeObject);
}

+ (id)processingInstructionWithName:(NSString *)name stringValue:(NSString *)stringValue;
{
xmlNodePtr theNode = xmlNewPI((const xmlChar *)[name UTF8String], (const xmlChar *)[stringValue UTF8String]);
NSAssert(theNode != NULL, @"xmlNewPI failed");
CXMLNode *theNodeObject = [[[CXMLNode alloc] initWithLibXMLNode:theNode] autorelease];
return(theNodeObject);
}

- (void)setStringValue:(NSString *)inStringValue
{
NSAssert(NO, @"TODO");
}

@end

