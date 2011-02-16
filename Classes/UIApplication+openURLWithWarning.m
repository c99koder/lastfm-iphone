/* UIApplication+openURLWithWarning.m - Display a warning before opening an external URL
 * 
 * Copyright 2011 Last.fm Ltd.
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
#import "MobileLastFMApplicationDelegate.h"
#import "ArtistViewController.h"
#import "AlbumViewController.h"
#import "TrackViewController.h"
#import "TagViewController.h"
#import "HomeViewController.h"
#import "RecentTracksViewController.h"
#import "WeeklyArtistsViewController.h"
#import "PlaybackViewController.h"
#import "NSString+URLEscaped.h"

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
	if(buttonIndex == 1) {
		NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:_url] delegate:[UIApplication sharedApplication] startImmediately:YES];
		__redirectURL = [_url retain];
		[conn release];
	}
}
- (void)dealloc {
	[super dealloc];
	[_url release];
}
@end

@implementation UIApplication (openURLWithWarning)
-(UINavigationController *)findCurrentNavController:(HomeViewController *)root {
	if(!((UINavigationController *)root.selectedViewController).navigationBarHidden) {
		return (UINavigationController *)root.selectedViewController;
  } else {
		return [self findCurrentNavController:(HomeViewController *)((UINavigationController *)root.selectedViewController).topViewController];
	}
}
-(void)openURLWithWarning:(NSURL *)url {
	if([[url scheme] isEqualToString:@"lastfm"]) {
		if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
			[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
		} else {
			if([[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] topViewController] isKindOfClass:[PlaybackViewController class]]) {
				[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:[url absoluteString] animated:NO];
			} else {
				[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:[url absoluteString] animated:YES];
			}
		}
		return;
	}
	
	if([[url scheme] isEqualToString:@"lastfm-user"]) {
		ProfileViewController *profile = [[ProfileViewController alloc] initWithUsername:[[url host] unURLEscape]];
		if([[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] topViewController] isKindOfClass:[PlaybackViewController class]]) {
			[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] popViewControllerAnimated:NO];
			[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
		}
		[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] pushViewController:profile animated:YES];
		[profile release];
		return;
	}
	
	if([[url scheme] isEqualToString:@"lastfm-friends"]) {
		FriendsViewController *friends = [[FriendsViewController alloc] initWithUsername:[[url host] unURLEscape]];
		if([[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] topViewController] isKindOfClass:[PlaybackViewController class]]) {
			[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] popViewControllerAnimated:NO];
			[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
			//[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController].navigationBar setBarStyle:UIBarStyleDefault];
		}
		[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] pushViewController:friends animated:YES];
		[friends release];
		return;
	}
	
	if([[url scheme] isEqualToString:@"lastfm-recenttracks"]) {
		RecentTracksViewController *tracks = [[RecentTracksViewController alloc] initWithUsername:[[url host] unURLEscape]];
		if([[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] topViewController] isKindOfClass:[PlaybackViewController class]]) {
			[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] popViewControllerAnimated:NO];
			[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
			//[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController].navigationBar setBarStyle:UIBarStyleDefault];
		}
		[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] pushViewController:tracks animated:YES];
		[tracks release];
		return;
	}
	
	if([[url scheme] isEqualToString:@"lastfm-weeklyartists"]) {
		WeeklyArtistsViewController *artists = [[WeeklyArtistsViewController alloc] initWithUsername:[[url host] unURLEscape]];
		if([[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] topViewController] isKindOfClass:[PlaybackViewController class]]) {
			[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] popViewControllerAnimated:NO];
			[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
			//[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController].navigationBar setBarStyle:UIBarStyleDefault];
		}
		[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] pushViewController:artists animated:YES];
		[artists release];
		return;
	}
	
	if([[url scheme] isEqualToString:@"lastfm-artist"]) {
		ArtistViewController *artist = [[ArtistViewController alloc] initWithArtist:[[url host] unURLEscape]];
		if([[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] topViewController] isKindOfClass:[PlaybackViewController class]]) {
			[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] popViewControllerAnimated:NO];
			[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
			//[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController].navigationBar setBarStyle:UIBarStyleDefault];
		}
		[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] pushViewController:artist animated:YES];
		[artist release];
		return;
	}
	
	if([[url scheme] isEqualToString:@"lastfm-album"]) {
		NSString *artist = [[url host] unURLEscape];
		NSString *album = [[[url path] substringFromIndex:1] unURLEscape];
		AlbumViewController *view = [[AlbumViewController alloc] initWithAlbum:album byArtist:artist];
		if([[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] topViewController] isKindOfClass:[PlaybackViewController class]]) {
			[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] popViewControllerAnimated:NO];
			[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
			//[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController].navigationBar setBarStyle:UIBarStyleDefault];
		}
		[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] pushViewController:view animated:YES];
		[view release];
		return;
	}
	
	if([[url scheme] isEqualToString:@"lastfm-track"]) {
		NSString *artist = [[url host] unURLEscape];
		NSString *track = [[[url path] substringFromIndex:1] unURLEscape];
		TrackViewController *view = [[TrackViewController alloc] initWithTrack:track byArtist:artist];
		if([[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] topViewController] isKindOfClass:[PlaybackViewController class]]) {
			[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] popViewControllerAnimated:NO];
			[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
			//[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController].navigationBar setBarStyle:UIBarStyleDefault];
		}
		[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] pushViewController:view animated:YES];
		[view release];
		return;
	}
	
	if([[url scheme] isEqualToString:@"lastfm-tag"]) {
		TagViewController *tag = [[TagViewController alloc] initWithTag:[[url host] unURLEscape]];
		if([[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] topViewController] isKindOfClass:[PlaybackViewController class]]) {
			[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] popViewControllerAnimated:NO];
			[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
			//[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController].navigationBar setBarStyle:UIBarStyleDefault];
		}
		[[self findCurrentNavController:((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController] pushViewController:tag animated:YES];
		[tag release];
		return;
	}
	
	UIDevice* device = [UIDevice currentDevice];
	BOOL backgroundSupported = NO;
	if ([device respondsToSelector:@selector(isMultitaskingSupported)])
		backgroundSupported = device.multitaskingSupported;
	
	if([[LastFMRadio sharedInstance] state] != RADIO_IDLE && !backgroundSupported) {
		URLWarningDelegate *delegate = [[URLWarningDelegate alloc] initWithURL:url];
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"EXTERNAL_LINK_TITLE", @"External link title")
																										 message:NSLocalizedString(@"EXTERNAL_LINK", @"External link")
																										delegate:delegate 
																					 cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel") 
																					 otherButtonTitles:NSLocalizedString(@"Continue", @"Continue"), nil] autorelease];
		[alert show];
	} else {
		NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:url] delegate:self startImmediately:YES];
		__redirectURL = [url retain];
		[conn release];
	}
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
	if([response URL]) {
		NSLog(@"Redirected to: %@", [response URL]);
		[__redirectURL release];
		__redirectURL = [[response URL] retain];
	}
	return request;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSLog(@"Launching: %@", __redirectURL);
	[[UIApplication sharedApplication] openURL:__redirectURL];
}
@end
