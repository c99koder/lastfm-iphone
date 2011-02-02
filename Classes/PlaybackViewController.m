/* PlaybackViewController.m - Display currently-playing song info
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

#import <MediaPlayer/MediaPlayer.h>
#import "PlaybackViewController.h"
#import "MobileLastFMApplicationDelegate.h"
#import "ProfileViewController.h"
#import "NowPlayingInfoViewController.h"
#import "UITableViewCell+ProgressIndicator.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "UIViewController+NowPlayingButton.h"
#import "UIApplication+openURLWithWarning.h"
#import "NSString+MD5.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "Beacon.h"
#endif

int tagSort(id tag1, id tag2, void *context) {
	if([[tag1 objectForKey:@"count"] intValue] < [[tag2 objectForKey:@"count"] intValue])
		return NSOrderedDescending;
	else if([[tag1 objectForKey:@"count"] intValue] > [[tag2 objectForKey:@"count"] intValue])
		return NSOrderedAscending;
	else
		return NSOrderedSame;
}

@implementation PlaybackSubview
- (void)showLoadingView {
	_loadingView.alpha = 1;
}
- (void)hideLoadingView {
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.5];
	_loadingView.alpha = 0;
	[UIView commitAnimations];
}
@end

@implementation TrackPlaybackViewController
@synthesize artwork;

- (void)becomeActive {
	NSLog(@"Resuming timer and subscribing to track changes");
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
	if(!(_timer && [_timer isValid])) 
		_timer = [NSTimer scheduledTimerWithTimeInterval:0.5
																						target:self
																					selector:@selector(_updateProgress:)
																					userInfo:nil
																					 repeats:YES];
	
	[self _displayTrackInfo:[[LastFMRadio sharedInstance] trackInfo]];
}

- (void)resignActive {
	NSLog(@"Stopping timer and ignoring track changes");
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kTrackDidChange object:nil];
	[_timer invalidate];
	_timer = nil;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	_lock = [[NSLock alloc] init];
	_reflectedArtworkView.transform = CGAffineTransformMake(1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f);
	_noArtworkView = [[UIImageView alloc] initWithFrame:_artworkView.bounds];
	_noArtworkView.image = [UIImage imageNamed:@"noartplaceholder.png"];
	_noArtworkView.opaque = NO;
	[_artworkView addSubview: _noArtworkView];
}
- (NSString *)formatTime:(int)seconds {
	if(seconds <= 0)
		return @"00:00";
	int h = seconds / 3600;
	int m = (seconds%3600) / 60;
	int s = seconds%60;
	if(h)
		return [NSString stringWithFormat:@"%02i:%02i:%02i", h, m, s];
	else
		return [NSString stringWithFormat:@"%02i:%02i", m, s];
}
- (void)_updateProgress:(NSTimer *)timer {
	if(!_timer) {
		[timer invalidate];
		return;
	}
	if([[LastFMRadio sharedInstance] state] != RADIO_IDLE) {
		float duration = [[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"duration"] floatValue]/1000.0f;
		float elapsed = [[LastFMRadio sharedInstance] trackPosition];

		_progress.progress = elapsed / duration;
		_elapsed.text = [self formatTime:elapsed];
		_remaining.text = [NSString stringWithFormat:@"-%@",[self formatTime:duration-elapsed]];
		_bufferPercentage.text = [NSString stringWithFormat:@"%i%%", (int)([[LastFMRadio sharedInstance] bufferProgress] * 100.0f)];
	} else {
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) stopButtonPressed:nil];	
	}
	if(([[LastFMRadio sharedInstance] state] == TRACK_BUFFERING || [[LastFMRadio sharedInstance] state] == RADIO_TUNING) && _loadingView.alpha < 1) {
		_loadingView.alpha = 1;
#if !(TARGET_IPHONE_SIMULATOR)
		[[Beacon shared] startSubBeaconWithName:@"buffering" timeSession:YES];
#endif
	}
	if([[LastFMRadio sharedInstance] state] == TRACK_BUFFERING && _loadingView.alpha == 1 && _bufferPercentage.alpha < 1) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:10];
		_bufferPercentage.alpha = 1;
		[UIView commitAnimations];
	}
	if(([[LastFMRadio sharedInstance] state] != TRACK_BUFFERING && [[LastFMRadio sharedInstance] state] != RADIO_TUNING) && _loadingView.alpha == 1) {
		_bufferPercentage.alpha = 0;
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.5];
		_loadingView.alpha = 0;
		[UIView commitAnimations];
#if !(TARGET_IPHONE_SIMULATOR)
		[[Beacon shared] endSubBeaconWithName:@"buffering"];
#endif
	}
}
- (void)_fetchArtwork:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[trackInfo retain];
	[_lock lock];
	NSDictionary *albumData = [[LastFMService sharedInstance] metadataForAlbum:[trackInfo objectForKey:@"album"] byArtist:[trackInfo objectForKey:@"creator"] inLanguage:[[[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"] objectAtIndex:0]];
	NSString *artworkURL = nil;
	UIImage *artworkImage;
	
	if([[albumData objectForKey:@"image"] length]) {
		artworkURL = [NSString stringWithString:[albumData objectForKey:@"image"]];
	} else if([[trackInfo objectForKey:@"image"] length]) {
			artworkURL = [NSString stringWithString:[trackInfo objectForKey:@"image"]];
	}

	if(!artworkURL || [artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_med.gif"] || [artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_large.gif"]) {
		NSDictionary *artistData = [[LastFMService sharedInstance] metadataForArtist:[trackInfo objectForKey:@"creator"] inLanguage:[[[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"] objectAtIndex:0]];
		if([artistData objectForKey:@"image"])
			artworkURL = [NSString stringWithString:[artistData objectForKey:@"image"]];
	}
	
	if(artworkURL && [artworkURL rangeOfString:@"amazon.com"].location != NSNotFound) {
		artworkURL = [artworkURL stringByReplacingOccurrencesOfString:@"MZZZ" withString:@"LZZZ"];
	}
	
	NSLog(@"Loading artwork: %@\n", artworkURL);
	if(artworkURL && ![artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_med.gif"] && ![artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_large.gif"]) {
		NSData *imageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString: artworkURL]];
		artworkImage = [[UIImage alloc] initWithData:imageData];
		[imageData release];
	} else {
		artworkImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"noartplaceholder" ofType:@"png"]];
	}

	if([[trackInfo objectForKey:@"title"] isEqualToString:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"title"]] &&
		 [[trackInfo objectForKey:@"creator"] isEqualToString:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"creator"]]) {
		_artworkView.image = artworkImage;
		_reflectedArtworkView.image = artworkImage;
		[artwork release];
		artwork = artworkImage;
		[UIView beginAnimations:nil context:nil];
		_noArtworkView.alpha = 0;
		[UIView commitAnimations];
	} else {
		[artworkImage release];
	}
	[_lock unlock];
	[trackInfo release];
	[pool release];
}
- (void)_updateBadge:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[trackInfo retain];
	
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"showontour"] isEqualToString:@"YES"]) {
		NSArray *events = [[LastFMService sharedInstance] eventsForArtist:[trackInfo objectForKey:@"creator"]];
		if([events count]) {
			if(_badge) {
				[UIView beginAnimations:nil context:nil];
				_badge.alpha = 1;
				[UIView commitAnimations];
			}
		} else {
			if(_badge) {
				[UIView beginAnimations:nil context:nil];
				_badge.alpha = 0;
				[UIView commitAnimations];
			}
		}
	}
	[trackInfo release];
	[pool release];
}	
- (void)_displayTrackInfo:(NSDictionary *)trackInfo {
	_showedMetadata = NO;
	_artistAndTrackTitle.text = [NSString stringWithFormat:@"%@ – %@", [trackInfo objectForKey:@"creator"], [trackInfo objectForKey:@"title"]];
	_elapsed.text = @"0:00";
	_remaining.text = [NSString stringWithFormat:@"-%@",[self formatTime:([[trackInfo objectForKey:@"duration"] floatValue] / 1000.0f)]];
	_progress.progress = 0;
	[artwork release];
	artwork = [[UIImage imageNamed:@"noartplaceholder.png"] retain];
	[UIView beginAnimations:nil context:nil];
	_noArtworkView.alpha = 1;
	_reflectedArtworkView.image = artwork;
	_badge.alpha = 0;
	[UIView commitAnimations];
	[self _updateProgress:nil];
	
	[NSThread detachNewThreadSelector:@selector(_updateBadge:) toTarget:self withObject:trackInfo];
	[NSThread detachNewThreadSelector:@selector(_fetchArtwork:) toTarget:self withObject:trackInfo];
}
- (void)_trackDidChange:(NSNotification *)notification {
	NSDictionary *trackInfo = [notification userInfo];
	[self _displayTrackInfo:trackInfo];
	NSLog(@"Free trial tracks remaining: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"trial_playsleft"]);
}
-(void)artworkButtonPressed:(id)sender {
	[UIView beginAnimations:nil context:nil];
	if(_fullscreenMetadataView.alpha == 1) {
		_fullscreenMetadataView.alpha = 0;
	} else {
		_fullscreenMetadataView.alpha = 1;
	}
	[UIView commitAnimations];
}
-(void)filterButtonPressed:(id)sender {
	[_filter reloadAllComponents];
	[UIView beginAnimations:nil context:nil];
	_filterView.frame = CGRectMake(0,156,320,260);
	[UIView commitAnimations];
}
-(void)_tuneNewStation:(NSDictionary *)filter {
	if(![[LastFMRadio sharedInstance] selectStation:[filter objectForKey:@"url"]]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate reportError:[LastFMService sharedInstance].error];
	} else {
		if([filter objectForKey:@"name"]) {
			UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Station Re-Tuned" message:
														 [NSString stringWithFormat:@"After this track, you'll only hear '%@' music on this station.",[filter objectForKey:@"name"]]
																											delegate:[UIApplication sharedApplication].delegate cancelButtonTitle:NSLocalizedString(@"OK", @"OK") otherButtonTitles:@"Don't show this message again", nil] autorelease];
			[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
			}
	}
}
-(void)dismissFilterView:(id)sender {
	[UIView beginAnimations:nil context:nil];
	_filterView.frame = CGRectMake(0,480,320,254);
	[UIView commitAnimations];
	if([_filter selectedRowInComponent:0] == 0) {
		//TODO: Special handling needed for the "ALL" option
	} else if(![[[LastFMRadio sharedInstance] stationURL] isEqualToString:[[[[LastFMRadio sharedInstance] suggestions] objectAtIndex:[_filter selectedRowInComponent:0]-1] objectForKey:@"url"]]) {
		NSLog(@"New URL: %@", [[[[LastFMRadio sharedInstance] suggestions] objectAtIndex:[_filter selectedRowInComponent:0]-1] objectForKey:@"url"]);
		[self performSelector:@selector(_tuneNewStation:) withObject:[[[LastFMRadio sharedInstance] suggestions] objectAtIndex:[_filter selectedRowInComponent:0]-1] afterDelay:0.1];
	}
}
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)thePickerView {
	return 1;
}
- (NSInteger)pickerView:(UIPickerView *)thePickerView numberOfRowsInComponent:(NSInteger)component {
	return [[[LastFMRadio sharedInstance] suggestions] count] + 1;
}
- (NSString *)pickerView:(UIPickerView *)thePickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
	if(row == 0)
		return @"Include all tags";
	else
		return [[[[LastFMRadio sharedInstance] suggestions] objectAtIndex:(row-1)] objectForKey:@"name"];
}
@end

@implementation PlaybackViewController
- (BOOL)canBecomeFirstResponder {
	return YES;
}
- (void)viewDidLoad {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
	trackView.view.frame = CGRectMake(0,0,320,416);
	[contentView addSubview:trackView.view];
	[contentView sendSubviewToBack:trackView.view];
	
	CGRect frame = volumeView.frame;
	frame.origin.y -= 2;
	frame.size.height += 10;
	
#if !(TARGET_IPHONE_SIMULATOR)
	MPVolumeView *v = [[MPVolumeView alloc] initWithFrame:frame];
	[trackView.view insertSubview: v aboveSubview: volumeView];
	[volumeView removeFromSuperview];
	[volumeView release];
	volumeView = v;
	[volumeView sizeToFit];
	[v release];
#endif
	self.hidesBottomBarWhenPushed = YES;
}
- (void)_systemVolumeChanged:(NSNotification *)notification {
	float volume = [[[notification userInfo] objectForKey:@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
	for(UIView *v in [volumeView subviews]) {
		if([v isKindOfClass:[UISlider class]]) {
			if(((UISlider *)v).value != volume)
				((UISlider *)v).value = volume;
		}
	}
}
- (BOOL)releaseDetailsView {
	if(artistViewController) {
		[artistViewController release];
		artistViewController = nil;
		return YES;
	} else {
		return NO;
	}
}
- (void)hideDetailsView {
	if(artistViewController != nil && [artistViewController.view superview])
		[self detailsButtonPressed:self];
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	_titleLabel.text = [[[LastFMRadio sharedInstance] station] capitalizedString];
	[[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
	[self becomeFirstResponder];
	[self becomeActive];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[self.navigationController.navigationBar setBarStyle:UIBarStyleBlack];
	[self.navigationController setToolbarHidden:YES];
}
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[UIApplication sharedApplication] endReceivingRemoteControlEvents];
	[self resignFirstResponder];
	[self resignActive];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	[self.navigationController.navigationBar setBarStyle:UIBarStyleDefault];
}
- (void)remoteControlReceivedWithEvent:(UIEvent*)theEvent {

	if (theEvent.type == UIEventTypeRemoteControl) {
		switch(theEvent.subtype) {
			case UIEventSubtypeRemoteControlPlay:
				[self stopButtonPressed:nil];
				break;
			case UIEventSubtypeRemoteControlPause:
				[self stopButtonPressed:nil];
				break;
			case UIEventSubtypeRemoteControlTogglePlayPause:
			case UIEventSubtypeRemoteControlStop:
				[self stopButtonPressed:nil];
				break;
			case UIEventSubtypeRemoteControlNextTrack:
				[self skipButtonPressed:nil];
				break;
			case UIEventSubtypeRemoteControlBeginSeekingBackward:
				[self loveButtonPressed:loveBtn];
				break;
			case UIEventSubtypeRemoteControlBeginSeekingForward:
				[self banButtonPressed:banBtn];
				break;
			default:
				return;
		}
	}
}
- (void)_trackDidChange:(NSNotification *)notification {
	//if([[detailView subviews] count])
	//	[self detailsButtonPressed:nil];
	_titleLabel.text = [[[LastFMRadio sharedInstance] station] capitalizedString];
	if([[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"loved"] isEqualToString:@"1"])
		loveBtn.selected = YES;//loveBtn.image = [UIImage imageNamed:@"control_01_on.png"];
	else
		loveBtn.selected = NO;//loveBtn.image = [UIImage imageNamed:@"control_01_off.png"];
	banBtn.alpha = 1;
	if([[[LastFMRadio sharedInstance] stationURL] hasPrefix:@"lastfm://artist/"] || [[[LastFMRadio sharedInstance] stationURL] hasPrefix:@"lastfm://globaltags/"]) {
		self.navigationItem.rightBarButtonItem = nil;
	} else {
		UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:trackView action:@selector(filterButtonPressed:)];
		self.navigationItem.rightBarButtonItem = item;
		[item release];
	}	
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)backButtonPressed:(id)sender {
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hidePlaybackView];
}
- (void)detailsButtonPressed:(id)sender {
	if(artistViewController != nil && [artistViewController.view superview]) {
		detailsBtn.frame = CGRectMake(0,0,30,30);
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.75];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:detailsBtnContainer cache:YES];
		[detailsBtn setBackgroundImage:[UIImage imageNamed:@"info_button.png"] forState:UIControlStateNormal];
		[detailsBtn superview].backgroundColor = [UIColor clearColor];
		[UIView commitAnimations];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.75];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:contentView cache:YES];
		[[contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
		[contentView addSubview: trackView.view];
		[UIView commitAnimations];
		_titleLabel.text = [[[LastFMRadio sharedInstance] station] capitalizedString];
#if !(TARGET_IPHONE_SIMULATOR)
		[[Beacon shared] endSubBeaconWithName:@"details"];
#endif
		[artistViewController release];
		artistViewController = nil;
	} else {
		artistViewController = [[ArtistViewController alloc] initWithArtist:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"creator"]];
		[artistViewController paintItBlack];
		[artistViewController loadView];
		[artistViewController viewDidLoad];
		[artistViewController viewWillAppear:YES];
		artistViewController.view.frame = CGRectMake(0,0,contentView.frame.size.width, contentView.frame.size.height);
		detailsBtn.frame = CGRectMake(1,1,28,28);
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.75];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:detailsBtnContainer cache:YES];
		[detailsBtn setBackgroundImage:trackView.artwork forState:UIControlStateNormal];
		[detailsBtn superview].backgroundColor = [UIColor blackColor];
		[UIView commitAnimations];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.75];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:contentView cache:YES];
		[[contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
		[contentView addSubview: artistViewController.view];
		[UIView commitAnimations];
#if !(TARGET_IPHONE_SIMULATOR)
		[[Beacon shared] startSubBeaconWithName:@"details" timeSession:YES];
#endif
	}
}
-(void)onTourButtonPressed:(id)sender {
	[self detailsButtonPressed:sender];
	[artistViewController jumpToEventsPage];
#if !(TARGET_IPHONE_SIMULATOR)
	[[Beacon shared] startSubBeaconWithName:@"on-tour-strap" timeSession:NO];
#endif
}
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	[self becomeFirstResponder];
	[self dismissModalViewControllerAnimated:YES];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
}
- (void)shareToAddressBook {
	if(NSClassFromString(@"MFMailComposeViewController") != nil && [MFMailComposeViewController canSendMail]) {
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
		MFMailComposeViewController *mail = [[MFMailComposeViewController alloc] init];
		NSDictionary *trackInfo = [((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) trackInfo];
		[mail setMailComposeDelegate:self];
		[mail setSubject:[NSString stringWithFormat:@"Last.fm: %@ shared %@",[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"], [trackInfo objectForKey:@"title"]]];
		[mail setMessageBody:[NSString stringWithFormat:@"Hi there,<br/>\
<br/>\
%@ at Last.fm wants to share this with you:<br/>\
<br/>\
<a href='http://www.last.fm/music/%@/_/%@'>%@</a><br/>\
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
													[[trackInfo objectForKey:@"creator"] URLEscaped],
													[[trackInfo objectForKey:@"title"] URLEscaped],
													[trackInfo objectForKey:@"title"]
													] isHTML:YES];
		[self presentModalViewController:mail animated:YES];
		[mail release];
	} else {
		ABPeoplePickerNavigationController *peoplePicker = [[ABPeoplePickerNavigationController alloc] init];
		peoplePicker.displayedProperties = [NSArray arrayWithObjects:[NSNumber numberWithInteger:kABPersonEmailProperty], nil];
		peoplePicker.peoplePickerDelegate = self;
		[self.navigationController presentModalViewController:peoplePicker animated:YES];
		[peoplePicker release];
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	}
}
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person {
	return YES;
}
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
	NSDictionary *trackInfo = [((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) trackInfo];
	ABMultiValueRef value = ABRecordCopyValue(person, property);
	NSString *email = (NSString *)ABMultiValueCopyValueAtIndex(value, ABMultiValueGetIndexForIdentifier(value, identifier));
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController dismissModalViewControllerAnimated:YES];
	
	[[LastFMService sharedInstance] recommendTrack:[trackInfo objectForKey:@"title"]
																				byArtist:[trackInfo objectForKey:@"creator"]
																	toEmailAddress:email];
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
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController dismissModalViewControllerAnimated:YES];
}
- (void)shareToFriend {
	FriendsViewController *friends = [[FriendsViewController alloc] initWithUsername:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	if(friends) {
		friends.delegate = self;
		friends.title = NSLocalizedString(@"Choose A Friend", @"Friend selector title");
		UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:friends];
		[friends release];
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController presentModalViewController:nav animated:YES];
		[nav release];
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	}
}
- (void)friendsViewController:(FriendsViewController *)friends didSelectFriend:(NSString *)username {
	NSDictionary *trackInfo = [((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) trackInfo];
	[[LastFMService sharedInstance] recommendTrack:[trackInfo objectForKey:@"title"]
																				byArtist:[trackInfo objectForKey:@"creator"]
																	toEmailAddress:username];
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	else
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"SHARE_SUCCESSFUL", @"Share successful") withTitle:NSLocalizedString(@"SHARE_SUCCESSFUL_TITLE", @"Share successful title")];
	
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController dismissModalViewControllerAnimated:YES];
}
- (void)friendsViewControllerDidCancel:(FriendsViewController *)friends {
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController dismissModalViewControllerAnimated:YES];
}
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSDictionary *trackInfo = [((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) trackInfo];

	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Share", @"Share button")]) {
		UIActionSheet *sheet;
		if(NSClassFromString(@"MFMailComposeViewController") != nil && [NSClassFromString(@"MFMailComposeViewController") canSendMail]) {
			sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Who would you like to share this track with?", @"Share sheet title")
																												 delegate:self
																								cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
																					 destructiveButtonTitle:nil
																								otherButtonTitles:@"E-mail Address", NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
		} else {
			sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Who would you like to share this track with?", @"Share sheet title")
																					delegate:self
																 cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
														destructiveButtonTitle:nil
																 otherButtonTitles:NSLocalizedString(@"Contacts", @"Share to Address Book"), NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
		}
		[sheet showInView:self.view];
		[sheet release];	
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Tag", @"Tag button")]) {
		NSArray *topTags = [[[LastFMService sharedInstance] topTagsForTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]] sortedArrayUsingFunction:tagSort context:nil];
		NSArray *userTags = [[[LastFMService sharedInstance] tagsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] sortedArrayUsingFunction:tagSort context:nil];
		TagEditorViewController *t = [[TagEditorViewController alloc] initWithTopTags:topTags userTags:userTags];
		t.delegate = self;
		[self presentModalViewController:t animated:YES];
		[t setTags: [[LastFMService sharedInstance] tagsForTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]]];
		[t release];
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Buy on iTunes", @"Buy on iTunes button")]) {
#if !(TARGET_IPHONE_SIMULATOR)
		[[Beacon shared] startSubBeaconWithName:@"nowplaying-buy" timeSession:NO];
#endif
		NSString *ITMSURL = [NSString stringWithFormat:@"http://phobos.apple.com/WebObjects/MZSearch.woa/wa/search?term=%@ %@&s=143444&partnerId=2003&affToken=www.last.fm", 
												 [trackInfo objectForKey:@"creator"],
												 [trackInfo objectForKey:@"title"]];
		NSString *URL;
		if([[[NSUserDefaults standardUserDefaults] objectForKey:@"country"] isEqualToString:@"United States"])
			URL = [NSString stringWithFormat:@"http://click.linksynergy.com/fs-bin/stat?id=bKEBG4*hrDs&offerid=78941&type=3&subid=0&tmpid=1826&RD_PARM1=%@", [[ITMSURL URLEscaped] stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"]];
		else
			URL = [NSString stringWithFormat:@"http://clk.tradedoubler.com/click?p=23761&a=1474288&url=%@&tduid=lastfm&partnerId=2003", [[ITMSURL URLEscaped] stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"]];
		
		[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:URL]];
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Contacts", @"Share to Address Book")] ||
		[[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"E-mail Address"]) {
		[self shareToAddressBook];
	}

	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend")]) {
		[self shareToFriend];
	}
}
- (void)actionButtonPressed:(id)sender {
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
																										 delegate:self
																						cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
																			 destructiveButtonTitle:nil
																						otherButtonTitles:NSLocalizedString(@"Share", @"Share button"),
																															NSLocalizedString(@"Tag", @"Tag button"),
																															NSLocalizedString(@"Buy on iTunes", @"Buy on iTunes button"),
																															nil];
	sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
	[sheet showInView:self.view];
	[sheet release];
}
-(void)tagEditorDidCancel {
	[self dismissModalViewControllerAnimated:YES];
}
- (void)tagEditorAddTags:(NSArray *)tags {
	NSDictionary *trackInfo = [[LastFMRadio sharedInstance] trackInfo];
	[[LastFMService sharedInstance] addTags:tags toTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]];
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	[self dismissModalViewControllerAnimated:YES];
}
- (void)tagEditorRemoveTags:(NSArray *)tags {
	NSDictionary *trackInfo = [[LastFMRadio sharedInstance] trackInfo];
	for(NSString *tag in tags) {
		[[LastFMService sharedInstance] removeTag:tag fromTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]];
		if([LastFMService sharedInstance].error)
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	}
}
-(void)loveButtonPressed:(id)sender {
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) loveButtonPressed:sender];	
}
-(void)banButtonPressed:(id)sender {
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) banButtonPressed:sender];	
}
-(void)stopButtonPressed:(id)sender {
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) stopButtonPressed:sender];	
}
-(void)skipButtonPressed:(id)sender {
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) skipButtonPressed:sender];	
}
-(void)infoButtonPressed:(id)sender {
	NowPlayingInfoViewController *info = [[NowPlayingInfoViewController alloc] initWithTrackInfo:[[LastFMRadio sharedInstance] trackInfo]];
	[self.navigationController pushViewController:info animated:YES];
	[info release];
}
- (void)dealloc {
	[super dealloc];
	if(artistViewController) {
		[artistViewController release];
		artistViewController = nil;
	}
}
- (void)becomeActive {
	[trackView becomeActive];
}
- (void)resignActive {
	[trackView resignActive];
}
@end
