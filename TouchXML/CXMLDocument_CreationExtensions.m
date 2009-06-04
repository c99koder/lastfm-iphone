//
//  CXMLDocument_CreationExtensions.m
//  TouchXML
//
//  Created by Jonathan Wight on 11/11/08.
//  Copyright 2008 toxicsoftware.com. All rights reserved.
//

#import "CXMLDocument_CreationExtensions.h"

#import "CXMLElement.h"
#import "CXMLNode_PrivateExtensions.h"
#import "CXMLDocument_PrivateExtensions.h"

@implementation CXMLDocument (CXMLDocument_CreationExtensions)

- (void)insertChild:(CXMLNode *)child atIndex:(NSUInteger)index
{
[self.nodePool addObject:child];

CXMLNode *theCurrentNode = [self.children objectAtIndex:index];
xmlAddPrevSibling(theCurrentNode->_node, child->_node);
}

- (void)addChild:(CXMLNode *)child
{
[self.nodePool addObject:child];

xmlAddChild(self->_node, child->_node);
}

@end
