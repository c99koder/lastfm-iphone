/* UIApplication+openURLWithWarning.m - Display a warning before opening an external URL
 * 
 * Copyright 2009 Last.fm Ltd.
 *   - Primarily authored by Sam Steele <sam@last.fm>
 *
 * This file is part of MobileLastFM.
 *
 * MobileLastFM is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * MobileLastFM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MobileLastFM.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "UIApplication+openURLWithWarning.h"
#import "LastFMRadio.h"

NSURL *__redirectURL;

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
		NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self startImmediately:YES];
		[conn release];
	}
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
	[__redirectURL release];
	__redirectURL = [[response URL] retain];
	return request;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[[UIApplication sharedApplication] openURL:__redirectURL];
}
@end
