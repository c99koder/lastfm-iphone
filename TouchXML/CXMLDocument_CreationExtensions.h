//
//  CXMLDocument_CreationExtensions.h
//  TouchXML
//
//  Created by Jonathan Wight on 11/11/08.
//  Copyright 2008 toxicsoftware.com. All rights reserved.
//

#import "CXMLDocument.h"

@interface CXMLDocument (CXMLDocument_CreationExtensions)

//- (void)setVersion:(NSString *)version; //primitive
//- (void)setStandalone:(BOOL)standalone; //primitive
//- (void)setDocumentContentKind:(CXMLDocumentContentKind)kind; //primitive
//- (void)setMIMEType:(NSString *)MIMEType; //primitive
//- (void)setDTD:(CXMLDTD *)documentTypeDeclaration; //primitive
//- (void)setRootElement:(CXMLNode *)root;
- (void)insertChild:(CXMLNode *)child atIndex:(NSUInteger)index;
//- (void)insertChildren:(NSArray *)children atIndex:(NSUInteger)index;
//- (void)removeChildAtIndex:(NSUInteger)index; //primitive
//- (void)setChildren:(NSArray *)children; //primitive
- (void)addChild:(CXMLNode *)child;
//- (void)replaceChildAtIndex:(NSUInteger)index withNode:(CXMLNode *)node;

@end
