/* UIApplication+openURLWithWarning.m - Display a warning before opening an external URL
 * Copyright (C) 2008 Sam Steele
 *
 * This file is part of MobileLastFM.
 *
 * MobileLastFM is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2
 * as published by the Free Software Foundation.
 *
 * MobileLastFM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */

#import "UIApplication+openURLWithWarning.h"
#import "LastFMRadio.h"

@interface URLWarningDelegate : NSObject<UIAlertViewDelegate> {
	NSURL *_url;
}
-(id)initWithURL:(NSURL *)url;
@end

@implementation URLWarningDelegate
-(id)initWithURL:(NSURL *)url {
	if(self = [super init])
		_url = [url retain];
	return self;
}
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if(buttonIndex == 1)
		[[UIApplication sharedApplication] openURL:_url];
}
- (void)dealloc {
	[super dealloc];
	[_url release];
}
@end

@implementation UIApplication (openURLWithWarning)
-(void)openURLWithWarning:(NSURL *)url {
	if([[LastFMRadio sharedInstance] state] != RADIO_IDLE) {
		URLWarningDelegate *delegate = [[URLWarningDelegate alloc] initWithURL:url];
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"EXTERNAL_LINK_TITLE", @"External link title")
																										 message:NSLocalizedString(@"EXTERNAL_LINK", @"External link")
																										delegate:delegate 
																					 cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel") 
																					 otherButtonTitles:NSLocalizedString(@"Continue", @"Continue"), nil] autorelease];
		[alert show];
	} else {
		[self openURL:url];
	}
}
@end
