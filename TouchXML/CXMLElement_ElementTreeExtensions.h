//
//  CXMLElement_ElementTreeExtensions.h
//  WebDAVServer
//
//  Created by Jonathan Wight on 11/14/08.
//  Copyright 2008 toxicsoftware.com. All rights reserved.
//

#import "CXMLElement.h"


@interface CXMLElement (CXMLElement_ElementTreeExtensions)

- (CXMLElement *)subelement:(NSString *)inName;

@end
