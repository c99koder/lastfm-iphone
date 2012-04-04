/* ShareActionSheet.m - Display an share action sheet
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

#import <Twitter/Twitter.h>
#import "ShareActionSheet.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+URLEscaped.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "FlurryAnalytics.h"
#endif
#import "SHKTwitter.h"
#import "SHKFacebook.h"

@implementation ShareActionSheet

@synthesize viewController;

- (ShareActionSheet*)initSuperWithTitle:(NSString*)title {
	if(NSClassFromString(@"MFMailComposeViewController") != nil && [NSClassFromString(@"MFMailComposeViewController") canSendMail]) {
		self = [super initWithTitle:title
											delegate:self
								   cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
							  destructiveButtonTitle:nil
								   otherButtonTitles:@"Twitter", @"Facebook", @"E-mail Address", NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
	} else {
		self = [super initWithTitle:title
											delegate:self
								   cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
							  destructiveButtonTitle:nil
								   otherButtonTitles:@"Twitter", @"Facebook", NSLocalizedString(@"Contacts", @"Share to Address Book"), NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
	}
	return self;
}
- (id)initWithTrack:(NSString*)track byArtist:(NSString*)artist {
	self = [self initSuperWithTitle:NSLocalizedString(@"How would you like to share this track?", @"Share track sheet title")];
	if ( self ) {
		_track = [track retain];
		_artist = [artist retain];
		_album = nil;
		_event = nil;
	}
	return self;
}

- (id)initWithArtist:(NSString*)artist {
	self = [self initSuperWithTitle:NSLocalizedString(@"How would you like to share this artist?", @"Share artist sheet title") ];
	if ( self ) {
		_track = nil;
		_album = nil;
		_artist = [artist retain];
		_event = nil;
	}
	return self;
}

- (id)initWithAlbum:(NSString*)album byArtist:(NSString *)artist {
	self = [self initSuperWithTitle:NSLocalizedString(@"How would you like to share this album?", @"Share album sheet title") ];
	if ( self ) {
		_track = nil;
		_album = [album retain];
		_artist = [artist retain];
		_event = nil;
	}
	return self;
}

- (id)initWithEvent:(NSDictionary*)event {
	self = [self initSuperWithTitle:NSLocalizedString(@"How would you like to share this event?", @"Share event sheet title")];
	if ( self ) {
		_track = nil;
		_album = nil;
		_artist = nil;
		_event = [event retain];
	}
	return self;
}

-(void)viewWillAppear:(BOOL)animated {
	barStyle = [UIApplication sharedApplication].statusBarStyle;
}

- (SHKItem *)shareKitItem {
	NSURL *url;
	NSString *title;
	
	if(_event != nil) {
		url = [NSURL URLWithString:[NSString stringWithFormat:@"http://www.last.fm/event/%@", [_event objectForKey:@"id"]]];
		title = [_event objectForKey:@"title"];
	} else {
		NSString *link = @"http://www.last.fm/music";
		link = [NSString stringWithFormat:@"%@/%@", link,[_artist URLEscaped]];
		if(_album)
			link = [NSString stringWithFormat:@"%@/%@", link,[_album URLEscaped]];
		else if(_track)
			link = [NSString stringWithFormat:@"%@/%@", link,@"_"];
		
		if(_track) {
			link = [NSString stringWithFormat:@"%@/%@", link,[_track URLEscaped]];
			title = [NSString stringWithFormat:@"%@ - %@", _artist, _track];
		} else if(_album) {
			title = [NSString stringWithFormat:@"%@ - %@", _artist, _album];
		} else {
			title = _artist;
		}
		url = [NSURL URLWithString:link];
	}
	
	return [SHKItem URL:url title:title];
}
- (void)shareToAddressBook {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"share-email"];
#endif
	if(NSClassFromString(@"MFMailComposeViewController") != nil && [MFMailComposeViewController canSendMail]) {
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
		MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
		[mail setMailComposeDelegate:self];
		
		NSString* sharedItem;
		if ( _event ) sharedItem = [_event objectForKey:@"title"];
		else if ( _track ) sharedItem = _track;
		else if ( _album ) sharedItem = _album;
		else sharedItem = _track;
		
		[mail setSubject:[NSString stringWithFormat:@"Last.fm: %@ shared %@",[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"], sharedItem]];
		NSString* sharedLink;
		if( _event ) {
			sharedLink = [NSString stringWithFormat:@"<a href='http://www.last.fm/event/%@'>%@</a>", 
										[_event objectForKey:@"id"], [_event objectForKey:@"title"]];
		} else if( _track ) {
			sharedLink = [NSString stringWithFormat:@"<a href='http://www.last.fm/music/%@/_/%@'>%@</a>", 
													[_artist URLEscaped], [_track URLEscaped], _track];
		} else if ( _album ) {
			sharedLink = [NSString stringWithFormat:@"<a href='http://www.last.fm/music/%@/%@'>%@</a>", 
						  [_artist URLEscaped], [_album URLEscaped], _album];
		} else {
			sharedLink = [NSString stringWithFormat:@"<a href='http://www.last.fm/music/%@'>%@</a>", 
						  [_artist URLEscaped], _artist];
		}
		if(_event) {
			[mail setMessageBody:[NSString stringWithFormat:@"<p>Hi there,</p>\
														<p>%@ at Last.fm thinks you might be interested in going to %@!</p>\
														<p>Click the link for more information about this event.</p>\
														<p>Don't have a Last.fm account?<br/>\
														Last.fm helps you find new music, effortlessly keeping a record of what you listen to from almost any player.</p>\
														</p><a href='http://www.last.fm/join'>Join Last.fm for free</a> and create a music profile.</p>\
														<p>- The Last.fm Team</p>",
														[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"],
														sharedLink
														] isHTML:YES];
		} else {
			[mail setMessageBody:[NSString stringWithFormat:@"<p>Hi there,</p>\
									<p>%@ has shared %@ with you on Last.fm!</p>\
									<p>Click the link for more information about this music.</p>\
									<p>Don't have a Last.fm account?<br/>\
									Last.fm helps you find new music, effortlessly keeping a record of what you listen to from almost any player.</p>\
									</p><a href='http://www.last.fm/join'>Join Last.fm for free</a> and create a music profile.</p>\
									<p>- The Last.fm Team</p>",
									[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"],
									sharedLink
									] isHTML:YES];
		}
		[self retain];
		[viewController presentModalViewController:mail animated:YES];
		[mail release];
	} else {
		ABPeoplePickerNavigationController *peoplePicker = [[ABPeoplePickerNavigationController alloc] init];
		peoplePicker.displayedProperties = [NSArray arrayWithObjects:[NSNumber numberWithInteger:kABPersonEmailProperty], nil];
		peoplePicker.peoplePickerDelegate = self;
		[viewController presentModalViewController:peoplePicker animated:YES];
		[peoplePicker release];
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	}
}
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person {
	return YES;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
    NSString *type;
	ABMultiValueRef value = ABRecordCopyValue(person, property);
	NSString *email = (NSString *)ABMultiValueCopyValueAtIndex(value, ABMultiValueGetIndexForIdentifier(value, identifier));
	[viewController dismissModalViewControllerAnimated:YES];
	
	if( _event ) {
		[[LastFMService sharedInstance] recommendEvent:[[_event objectForKey:@"id"] intValue]
                                        toEmailAddress:email];
        type = @"event";
	} else if( _track ) {
		[[LastFMService sharedInstance] recommendTrack:_track
											  byArtist:_artist
										toEmailAddress:email];
        type = @"track";
	} else if ( _album ) {
		[[LastFMService sharedInstance] recommendAlbum:_album
											  byArtist:_artist
										toEmailAddress:email];			
        type = @"album";
	} else {
		[[LastFMService sharedInstance] recommendArtist:_artist
										 toEmailAddress:email ];
        type = @"artist";
	}
	[email release];
	CFRelease(value);
	
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	else
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:[NSString stringWithFormat:@"This %@ was successfully shared.", type] withTitle:[NSString stringWithFormat:@"%@ Shared", [type capitalizedString]]];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	return NO;
}
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
	[viewController dismissModalViewControllerAnimated:YES];
}
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	[self release];
	[viewController becomeFirstResponder];
	[viewController dismissModalViewControllerAnimated:YES];
}
- (void)shareToFriend {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"share-friend"];
#endif
	FriendsViewController *friends = [[FriendsViewController alloc] initWithUsername:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	if(friends) {
		friends.delegate = self;
		friends.title = NSLocalizedString(@"Choose A Friend", @"Friend selector title");
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:friends];
		[friends release];
		[viewController presentModalViewController:nav animated:YES];
		[nav release];
		[[UIApplication sharedApplication] setStatusBarStyle:barStyle animated:YES];
	}
}
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"Twitter"]) {
#if !(TARGET_IPHONE_SIMULATOR)
		[FlurryAnalytics logEvent:@"share-twitter"];
#endif
        SHKItem *item = [self shareKitItem];
        if(_track) {
            item.text = @"Check out this track on #lastfm:";
        } else if(_album) {
            item.text = @"Check out this album on #lastfm:";
        } else if(_artist) {
            item.text = @"Check out this artist on #lastfm:";
        } else if(_event) {
            item.text = @"Check out this event on #lastfm:";
        }
        if(NSClassFromString(@"TWTweetComposeViewController")) {
            // Set up the built-in twitter composition view controller.
            TWTweetComposeViewController *tweetViewController = [[[TWTweetComposeViewController alloc] init] autorelease];
            
            // Set the initial tweet text. See the framework for additional properties that can be set.
            [tweetViewController setInitialText:[NSString stringWithFormat:@"%@ %@", item.text, [item.URL absoluteString]]];
            
            // Create the completion handler block.
            [tweetViewController setCompletionHandler:^(TWTweetComposeViewControllerResult result) {
                // Dismiss the tweet composition view controller.
                [viewController dismissModalViewControllerAnimated:YES];
            }];
            
            // Present the tweet composition view controller modally.
            [viewController presentModalViewController:tweetViewController animated:YES];

        } else {
            [SHKTwitter shareItem:item];
        }
	}
    
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"Facebook"]) {
#if !(TARGET_IPHONE_SIMULATOR)
		[FlurryAnalytics logEvent:@"share-facebook"];
#endif
		SHKItem *item = [self shareKitItem];
		if(_track) {
			item.text = @"{*actor*} shared a track on Last.fm";
		} else if(_album) {
			item.text = @"{*actor*} shared an album on Last.fm";
		} else if(_artist) {
			item.text = @"{*actor*} shared an artist on Last.fm";
		} else if(_event) {
			item.text = @"{*actor*} shared an event on Last.fm";
		}
		[SHKFacebook shareItem:item];
	}
    
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Contacts", @"Share to Address Book")] ||
	   [[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"E-mail Address"]) {
		[self shareToAddressBook];
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend")]) {
		[self shareToFriend];
	}
}
- (void)friendsViewController:(FriendsViewController *)friends didSelectFriend:(NSString *)username {
    NSString *type;
	if( _event ) {
		[[LastFMService sharedInstance] recommendEvent:[[_event objectForKey:@"id"] intValue]
																		toEmailAddress:username];
        type = @"event";
	} else if( _track ) {
		[[LastFMService sharedInstance] recommendTrack:_track
											  byArtist:_artist
										toEmailAddress:username];
        type = @"track";
	} else if ( _album ) {
		[[LastFMService sharedInstance] recommendAlbum:_album
											  byArtist:_artist
										toEmailAddress:username];
        type = @"album";
	} else {
		[[LastFMService sharedInstance] recommendArtist:_artist
										 toEmailAddress:username];		
        type = @"artist";
	}
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	else
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:[NSString stringWithFormat:@"This %@ was successfully shared.", type] withTitle:[NSString stringWithFormat:@"%@ Shared", [type capitalizedString]]];
	
	[[UIApplication sharedApplication] setStatusBarStyle:barStyle animated:YES];
	[viewController dismissModalViewControllerAnimated:YES];
}
- (void)friendsViewControllerDidCancel:(FriendsViewController *)friends {
	[[UIApplication sharedApplication] setStatusBarStyle:barStyle animated:YES];
	[viewController dismissModalViewControllerAnimated:YES];
}

- (void)dealloc {
    [super dealloc];
	[_artist release];
	[_track release];
	[_album release];
}


@end
