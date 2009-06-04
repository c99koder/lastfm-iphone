//
//  CXMLElement_ElementTreeExtensions.m
//  WebDAVServer
//
//  Created by Jonathan Wight on 11/14/08.
//  Copyright 2008 toxicsoftware.com. All rights reserved.
//

#import "CXMLElement_ElementTreeExtensions.h"

#import "CXMLElement_CreationExtensions.h"
#import "CXMLNode_CreationExtensions.h"

@implementation CXMLElement (CXMLElement_ElementTreeExtensions)

- (CXMLElement *)subelement:(NSString *)inName;
{
CXMLElement *theSubelement = [CXMLNode elementWithName:inName];
[self addChild:theSubelement];
return(theSubelement);
}

@end
