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

@implementation PlaybackViewController
- (void)showLoadingView {
	_loadingView.alpha = 1;
}
- (void)hideLoadingView {
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.5];
	_loadingView.alpha = 0;
	[UIView commitAnimations];
}
- (BOOL)canBecomeFirstResponder {
	return YES;
}
- (void)viewDidLoad {
	[super viewDidLoad];
	self.hidesBottomBarWhenPushed = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
	
	CGRect frame = volumeView.frame;
	frame.origin.y += 6;
	frame.size.height += 10;
	
#if !(TARGET_IPHONE_SIMULATOR)
	MPVolumeView *v = [[MPVolumeView alloc] initWithFrame:frame];
	[self.view insertSubview: v aboveSubview: volumeView];
	[volumeView removeFromSuperview];
	[volumeView release];
	volumeView = v;
	[volumeView sizeToFit];
	[v release];
#endif
	_lock = [[NSLock alloc] init];
	_reflectedArtworkView.transform = CGAffineTransformMake(1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f);
	_noArtworkView = [[UIImageView alloc] initWithFrame:_artworkView.bounds];
	_noArtworkView.image = [UIImage imageNamed:@"noartplaceholder.png"];
	_noArtworkView.opaque = NO;
	[_artworkView addSubview: _noArtworkView];
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
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)backButtonPressed:(id)sender {
	[self.navigationController popViewControllerAnimated:YES];
}
-(void)onTourButtonPressed:(id)sender {
#if !(TARGET_IPHONE_SIMULATOR)
	[[Beacon shared] startSubBeaconWithName:@"on-tour-strap" timeSession:NO];
#endif
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
		[_timer invalidate];
		_timer = nil;
		return;
	}
	if(([[LastFMRadio sharedInstance] state] == TRACK_BUFFERING || [[LastFMRadio sharedInstance] state] == RADIO_TUNING) && _loadingView.alpha < 1) {
		_loadingView.alpha = 1;
		loveBtn.alpha = 0.5;
		banBtn.alpha = 0.5;
		infoBtn.alpha = 0.5;
		stopBtn.alpha = 0.5;
		skipBtn.alpha = 0.5;
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
		loveBtn.alpha = 1;
		banBtn.alpha = 1;
		infoBtn.alpha = 1;
		stopBtn.alpha = 1;
		skipBtn.alpha = 1;
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
	if([[[LastFMRadio sharedInstance] stationURL] hasPrefix:@"lastfm://artist/"] || [[[LastFMRadio sharedInstance] stationURL] hasPrefix:@"lastfm://globaltags/"]) {
		self.navigationItem.rightBarButtonItem = nil;
	} else {
		UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(filterButtonPressed:)];
		self.navigationItem.rightBarButtonItem = item;
		[item release];
	}

	[[self.navigationItem.titleView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	
	NSRange range = [[[LastFMRadio sharedInstance] stationURL] rangeOfString:@"/tag/"];
	if(range.location != NSNotFound) {
		NSString *tag = [[[[LastFMRadio sharedInstance] stationURL] substringFromIndex:range.location + 5] unURLEscape];
		_titleLabel.frame = CGRectMake(0,0,200,14);
		_titleLabel.font = [UIFont systemFontOfSize:14];
		[self.navigationItem.titleView addSubview: _titleLabel];
		UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectMake(0,14,200,14)];
		subtitle.text = [NSString stringWithFormat:@"Playing just '%@'", tag];
		subtitle.font = [UIFont systemFontOfSize:14];
		subtitle.textColor = [UIColor grayColor];
		subtitle.backgroundColor = [UIColor clearColor];
		subtitle.textAlignment = UITextAlignmentCenter;
		[self.navigationItem.titleView addSubview: subtitle];
		[subtitle release];
	} else {
		_titleLabel.frame = CGRectMake(0,0,200,28);
		_titleLabel.font = [UIFont boldSystemFontOfSize:21];
		[self.navigationItem.titleView addSubview: _titleLabel];
	}
	[NSThread detachNewThreadSelector:@selector(_updateBadge:) toTarget:self withObject:trackInfo];
	[NSThread detachNewThreadSelector:@selector(_fetchArtwork:) toTarget:self withObject:trackInfo];
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
- (void)_trackDidChange:(NSNotification *)notification {
	_titleLabel.text = [[[LastFMRadio sharedInstance] station] capitalizedString];
	if([[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"loved"] isEqualToString:@"1"])
		loveBtn.selected = YES;
	else
		loveBtn.selected = NO;
	NSDictionary *trackInfo = [notification userInfo];
	[self _displayTrackInfo:trackInfo];
	NSLog(@"Free trial tracks remaining: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"trial_playsleft"]);
}
@end
