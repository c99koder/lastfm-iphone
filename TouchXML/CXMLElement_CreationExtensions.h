//
//  CXMLElement_CreationExtensions.h
//  WebDAVServer
//
//  Created by Jonathan Wight on 11/11/08.
//  Copyright 2008 toxicsoftware.com. All rights reserved.
//

#import "CXMLElement.h"

@interface CXMLElement (CXMLElement_CreationExtensions)

- (void)addChild:(CXMLNode *)inNode;

- (void)addNamespace:(CXMLNode *)inNamespace;

@end
