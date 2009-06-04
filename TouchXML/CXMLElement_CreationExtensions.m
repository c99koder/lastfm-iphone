//
//  CXMLElement_CreationExtensions.m
//  WebDAVServer
//
//  Created by Jonathan Wight on 11/11/08.
//  Copyright 2008 toxicsoftware.com. All rights reserved.
//

#import "CXMLElement_CreationExtensions.h"

@implementation CXMLElement (CXMLElement_CreationExtensions)

- (void)addChild:(CXMLNode *)inNode
{
NSAssert(inNode->_node->doc == NULL, @"Cannot addChild with a node that already is part of a document. Copy it first!");
NSAssert(self->_node != NULL, @"_node should not be null");
NSAssert(inNode->_node != NULL, @"_node should not be null");
xmlAddChild(self->_node, inNode->_node);
}

- (void)addNamespace:(CXMLNode *)inNamespace
{
xmlSetNs(self->_node, (xmlNsPtr)inNamespace->_node);
}

- (void)setStringValue:(NSString *)inStringValue
{
NSAssert(inStringValue != NULL, @"CXMLElement setStringValue should not be null");
xmlNodePtr theContentNode = xmlNewText((const xmlChar *)[inStringValue UTF8String]);
NSAssert(self->_node != NULL, @"_node should not be null");
xmlAddChild(self->_node, theContentNode);
}

@end
