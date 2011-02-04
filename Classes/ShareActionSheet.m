//
//  ShareActionSheet.m
//  MobileLastFM
//
//  Created by Jono Cole on 04/02/2011.
//  Copyright 2011 Last.fm. All rights reserved.
//

#import "ShareActionSheet.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+URLEscaped.h"


@implementation ShareActionSheet

@synthesize viewController;

- (ShareActionSheet*)initSuperWithTitle:(NSString*)title {
	if(NSClassFromString(@"MFMailComposeViewController") != nil && [NSClassFromString(@"MFMailComposeViewController") canSendMail]) {
		self = [super initWithTitle:title
											delegate:self
								   cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
							  destructiveButtonTitle:nil
								   otherButtonTitles:@"E-mail Address", NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
	} else {
		self = [super initWithTitle:title
											delegate:self
								   cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
							  destructiveButtonTitle:nil
								   otherButtonTitles:NSLocalizedString(@"Contacts", @"Share to Address Book"), NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
	}
	return self;
}
- (id)initWithTrack:(NSString*)track forArtist:(NSString*)artist {
	self = [self initSuperWithTitle:NSLocalizedString(@"Who would you like to share this track with?", @"Share track sheet title")];
	if ( self ) {
		_track = [track retain];
		_artist = [artist retain];
	}
	return self;
}

- (id)initWithArtist:(NSString*)artist {
	self = [self initSuperWithTitle:NSLocalizedString(@"Who would you like to share this artist with?", @"Share artist sheet title") ];
	if ( self ) {
		_track = nil;
		_artist = [artist retain];
	}
	return self;
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Contacts", @"Share to Address Book")] ||
	   [[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"E-mail Address"]) {
		[self shareToAddressBook];
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend")]) {
		[self shareToFriend];
	}
}

- (void)shareToAddressBook {
	if(NSClassFromString(@"MFMailComposeViewController") != nil && [MFMailComposeViewController canSendMail]) {
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
		MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
		[mail setMailComposeDelegate:self];
		[mail setSubject:[NSString stringWithFormat:@"Last.fm: %@ shared %@",[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"], _track ? _track : _artist]];
		NSString* sharedItem;
		if( _track ) {
			sharedItem = [NSString stringWithFormat:@"<a href='http://www.last.fm/music/%@/_/%@'>%@</a>", 
													[_artist URLEscaped], [_track URLEscaped], _track];
		} else {
			sharedItem = [NSString stringWithFormat:@"<a href='http://www.last.fm/music/%@'>%@</a>", 
						  [_artist URLEscaped], _artist];
		}
		[mail setMessageBody:[NSString stringWithFormat:@"Hi there,<br/>\
							  <br/>\
							  %@ at Last.fm wants to share this with you:<br/>\
							  <br/>\
							  %@<br/>\
							  <br/>\
							  If you like this, add it to your Library. <br/>\
							  This will make it easier to find, and will tell your Last.fm profile a bit more<br/>\
							  about your music taste. This improves your recommendations and your Last.fm Radio.<br/>\
							  <br/>\
							  The more good music you add to your Last.fm Profile, the better it becomes :)<br/>\
							  <br/>\
							  Best Regards,<br/>\
							  The Last.fm Team<br/>\
							  --<br/>\
							  Visit Last.fm for personal radio, tons of recommended music, and free downloads.<br/>\
							  Create your own music profile at <a href='http://www.last.fm'>Last.fm</a><br/>",
							  [[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"],
							  sharedItem
							  ] isHTML:YES];
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
	ABMultiValueRef value = ABRecordCopyValue(person, property);
	NSString *email = (NSString *)ABMultiValueCopyValueAtIndex(value, ABMultiValueGetIndexForIdentifier(value, identifier));
	[viewController dismissModalViewControllerAnimated:YES];
	
	if( _track ) {
		[[LastFMService sharedInstance] recommendTrack:_track
											  byArtist:_artist
										toEmailAddress:email];
	} else {
		[[LastFMService sharedInstance] recommendArtist:_artist
										 toEmailAddress:email ];
	}
	[email release];
	CFRelease(value);
	
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	else
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"SHARE_SUCCESSFUL", @"Share successful") withTitle:NSLocalizedString(@"SHARE_SUCCESSFUL_TITLE", @"Share successful title")];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	return NO;
}
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[viewController dismissModalViewControllerAnimated:YES];
}
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	[self release];
	[viewController becomeFirstResponder];
	[viewController dismissModalViewControllerAnimated:YES];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
}
- (void)shareToFriend {
	FriendsViewController *friends = [[FriendsViewController alloc] initWithUsername:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	if(friends) {
		friends.delegate = self;
		friends.title = NSLocalizedString(@"Choose A Friend", @"Friend selector title");
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:friends];
		[friends release];
		[viewController presentModalViewController:nav animated:YES];
		[nav release];
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	}
}

- (void)friendsViewController:(FriendsViewController *)friends didSelectFriend:(NSString *)username {
	if( _track ) {
		[[LastFMService sharedInstance] recommendTrack:_track
											  byArtist:_artist
										toEmailAddress:username];
	} else {
		[[LastFMService sharedInstance] recommendArtist:_artist
										 toEmailAddress:username];		
	}
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	else
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"SHARE_SUCCESSFUL", @"Share successful") withTitle:NSLocalizedString(@"SHARE_SUCCESSFUL_TITLE", @"Share successful title")];
	
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[viewController dismissModalViewControllerAnimated:YES];
}
- (void)friendsViewControllerDidCancel:(FriendsViewController *)friends {
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[viewController dismissModalViewControllerAnimated:YES];
}

- (void)dealloc {
    [super dealloc];
	[_artist release];
	[_track release];
}


@end
