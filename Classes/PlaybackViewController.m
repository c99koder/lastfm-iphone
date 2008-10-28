/* PlaybackViewController.m - Display currently-playing song info
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

#import <MediaPlayer/MediaPlayer.h>
#import "PlaybackViewController.h"
#import "MobileLastFMApplicationDelegate.h"
#import "ProfileViewController.h"
#import "UITableViewCell+ProgressIndicator.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "UIViewController+NowPlayingButton.h"
#import "UIApplication+openURLWithWarning.h"
#import "NSString+MD5.h"

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

@implementation SimilarArtistsViewController
- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
	_lock = [[NSLock alloc] init];
	_cells = [[NSMutableArray alloc] initWithCapacity:25];
}
- (void)viewWillAppear:(BOOL)animated {
	[_table scrollRectToVisible:[_table frame] animated:NO];
	[self loadContentForCells:[_table visibleCells]];
}
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchSimilarArtists:) toTarget:self withObject:[notification userInfo]];
}
- (void)_updateCells:(NSArray *)data {
	[_data release];
	[_cells removeAllObjects];
	_data = [[data subarrayWithRange:NSMakeRange(0,([data count]>25)?25:[data count])] retain];
	for(NSDictionary *artist in _data) {
		ArtworkCell *cell = [[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:nil];
		cell.title.text = [artist objectForKey:@"name"];
		cell.barWidth = [[artist objectForKey:@"match"] floatValue] / 100.0f;
		cell.imageURL = [artist objectForKey:@"image"];
		[cell addStreamIcon];
		[_cells addObject:cell];
		[cell release];
	}
	[_table reloadData];
	[_table scrollRectToVisible:[_table frame] animated:YES];
}
- (void)_fetchSimilarArtists:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[trackInfo retain];
	[_lock lock];
	if([[trackInfo objectForKey:@"title"] isEqualToString:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"title"]] &&
		 [[trackInfo objectForKey:@"creator"] isEqualToString:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"creator"]]) {
		[self performSelectorOnMainThread:@selector(showLoadingView) withObject:nil waitUntilDone:YES];
		[self performSelectorOnMainThread:@selector(_updateCells:) withObject:[[LastFMService sharedInstance] artistsSimilarTo:[trackInfo objectForKey:@"creator"]] waitUntilDone:YES];
		[self performSelectorOnMainThread:@selector(hideLoadingView) withObject:nil waitUntilDone:YES];
	}
	[_lock unlock];
	[trackInfo release];
	[pool release];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 48;
}
-(void)_playRadio:(NSTimer *)timer {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:[timer userInfo] animated:NO];
	}
	[_table reloadData];
}
-(void)playRadioStation:(NSString *)url {
	//Hack to make the loading throbber appear before we block
	[NSTimer scheduledTimerWithTimeInterval:0.1
																	 target:self
																 selector:@selector(_playRadio:)
																 userInfo:url
																	repeats:NO];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[self playRadioStation:[NSString stringWithFormat:@"lastfm://artist/%@", [[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"name"] URLEscaped]]];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [_cells objectAtIndex:[indexPath row]];
}
- (void)dealloc {
	[_data release];
	[super dealloc];
}
@end

int tagSort(id tag1, id tag2, void *context) {
	if([[tag1 objectForKey:@"count"] intValue] < [[tag2 objectForKey:@"count"] intValue])
		return NSOrderedDescending;
	else if([[tag1 objectForKey:@"count"] intValue] > [[tag2 objectForKey:@"count"] intValue])
		return NSOrderedAscending;
	else
		return NSOrderedSame;
}

@implementation TagsViewController
- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
	_lock = [[NSLock alloc] init];
}
- (void)viewWillAppear:(BOOL)animated {
	[_table scrollRectToVisible:[_table frame] animated:NO];
}
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchTags:) toTarget:self withObject:[notification userInfo]];
}
- (void)_fetchTags:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[trackInfo retain];
	[_lock lock];
	if([[trackInfo objectForKey:@"title"] isEqualToString:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"title"]] &&
		 [[trackInfo objectForKey:@"creator"] isEqualToString:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"creator"]]) {
		[self performSelectorOnMainThread:@selector(showLoadingView) withObject:nil waitUntilDone:YES];
		[_data release];
		_data = [[[LastFMService sharedInstance] topTagsForTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]] sortedArrayUsingFunction:tagSort context:nil];
		_data = [[_data subarrayWithRange:NSMakeRange(0,([_data count]>10)?10:[_data count])] retain];
		[_table reloadData];
		[_table scrollRectToVisible:[_table frame] animated:YES];
		[self performSelectorOnMainThread:@selector(hideLoadingView) withObject:nil waitUntilDone:YES];
	}
	[_lock unlock];
	[trackInfo release];
	[pool release];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count]?[_data count]:1;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 48;
}
-(void)_playRadio:(NSTimer *)timer {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:[timer userInfo] animated:NO];
	}
	[_table reloadData];
}
-(void)playRadioStation:(NSString *)url {
	//Hack to make the loading throbber appear before we block
	[NSTimer scheduledTimerWithTimeInterval:0.1
																	 target:self
																 selector:@selector(_playRadio:)
																 userInfo:url
																	repeats:NO];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	if([_data count]) {
		[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
		[self playRadioStation:[NSString stringWithFormat:@"lastfm://globaltags/%@", [[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"name"] URLEscaped]]];
	}
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:nil] autorelease];
	if([_data count]) {
		UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(8,0,256,48)];
		l.textColor = [UIColor blackColor];
		l.backgroundColor = [UIColor clearColor];
		l.font = [UIFont boldSystemFontOfSize:20];
		l.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"name"];
		[cell.contentView addSubview: l];
		[l release];
		float width = [[[_data objectAtIndex:[indexPath row]] objectForKey:@"count"] floatValue] / [[[_data objectAtIndex:0] objectForKey:@"count"] floatValue];
		UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0,0,width * [cell frame].size.width,48)];
		bar.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.4];
		UIView *backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
		[backgroundView addSubview: bar];
		cell.backgroundView = backgroundView;
		[bar release];
		[backgroundView release];
		UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
		cell.accessoryView = img;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		[img release];
	} else {
		cell.text = @"No Tags";
	}
	return cell;
}
- (void)dealloc {
	[_data release];
	[super dealloc];
}
@end

@implementation FansViewController
- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
	_lock = [[NSLock alloc] init];
	_cells = [[NSMutableArray alloc] init];
}
- (void)viewWillAppear:(BOOL)animated {
	[_table scrollRectToVisible:[_table frame] animated:NO];
	[self loadContentForCells:[_table visibleCells]];
}
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchFans:) toTarget:self withObject:[notification userInfo]];
}
- (void)_updateCells:(NSArray *)data {
	[_data release];
	[_cells removeAllObjects];
	_data = [[data subarrayWithRange:NSMakeRange(0,([data count]>10)?10:[data count])] retain];
	for(NSDictionary *fan in _data) {
		ArtworkCell *cell = [[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:nil];
		cell.title.text = [fan objectForKey:@"username"];
		cell.imageURL = [fan objectForKey:@"image"];
		[_cells addObject:cell];
		[cell release];
	}
	[_table reloadData];
	[_table scrollRectToVisible:[_table frame] animated:YES];
}
- (void)_fetchFans:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[trackInfo retain];
	[_lock lock];
	if([[trackInfo objectForKey:@"title"] isEqualToString:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"title"]] &&
		 [[trackInfo objectForKey:@"creator"] isEqualToString:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"creator"]]) {
		[self performSelectorOnMainThread:@selector(showLoadingView) withObject:nil waitUntilDone:YES];
		[self performSelectorOnMainThread:@selector(_updateCells:) withObject:[[LastFMService sharedInstance] fansOfTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]] waitUntilDone:YES];
		[self performSelectorOnMainThread:@selector(hideLoadingView) withObject:nil waitUntilDone:YES];
	}
	[_lock unlock];
	[trackInfo release];
	[pool release];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 48;
}
-(void)_showProfile:(NSTimer *)timer {
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController popViewControllerAnimated:NO];
	UITabBarController *tabBarController = [((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) profileViewForUser:[timer userInfo]];
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:tabBarController animated:YES];
	[tabBarController release];
	[_table reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[NSTimer scheduledTimerWithTimeInterval:0.1
																	 target:self
																 selector:@selector(_showProfile:)
																 userInfo:[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"username"]
																	repeats:NO];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [_cells objectAtIndex:[indexPath row]];
	[cell showProgress:NO];
	return cell;
}
- (void)dealloc {
	[_data release];
	[super dealloc];
}
@end

@implementation TrackViewController
@synthesize artwork;

- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
	[NSTimer scheduledTimerWithTimeInterval:0.5
																	 target:self
																 selector:@selector(_updateProgress:)
																 userInfo:nil
																	repeats:YES];
	_reflectedArtworkView.transform = CGAffineTransformMake(1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f);
	_lock = [[NSLock alloc] init];
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
- (void)_showMetadata {
	_trackTitle.textAlignment = UITextAlignmentLeft;
	_artist.textAlignment = UITextAlignmentLeft;
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.6];
	_trackTitle.alpha = 1;
	_artist.alpha = 1;
	_artist.frame = CGRectMake(30,96,280,18);
	_trackTitle.frame = CGRectMake(30,117,280,18);
	[UIView commitAnimations];
	[self performSelector:@selector(_hideMetadata) withObject:nil afterDelay:4];
}
- (void)_hideMetadata {
	if(_artworkView.frame.size.width == 320) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.6];
		_trackTitle.alpha = 0;
		_artist.alpha = 0;
		_artist.frame = CGRectMake(30,196,280,18);
		_trackTitle.frame = CGRectMake(30,217,280,18);
		_fullscreenMetadataView.alpha = 0;
		[UIView commitAnimations];
	}
}
- (void)_showGradient {
	_showedMetadata = YES;
	_trackTitle.alpha = 0;
	_artist.alpha = 0;
	_artist.frame = CGRectMake(30,196,280,18);
	_trackTitle.frame = CGRectMake(30,217,280,18);
	_fullscreenMetadataView.frame = CGRectMake(0,161,320,159);
	_fullscreenMetadataView.alpha = 0;
	_fullscreenMetadataView.image = [UIImage imageNamed:@"metadatagradient.png"];
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:1.0];
	_fullscreenMetadataView.alpha = 1;
	[UIView commitAnimations];
	[self performSelector:@selector(_showMetadata) withObject:nil afterDelay:0.5];
}
- (void)_updateProgress:(NSTimer *)timer {
	if([[LastFMRadio sharedInstance] state] != RADIO_IDLE) {
		float duration = [[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"duration"] floatValue]/1000.0f;
		float elapsed = [[LastFMRadio sharedInstance] trackPosition];

		_progress.progress = elapsed / duration;
		_elapsed.text = [self formatTime:elapsed];
		_remaining.text = [NSString stringWithFormat:@"-%@",[self formatTime:duration-elapsed]];
		_bufferPercentage.text = [NSString stringWithFormat:@"%i%%", (int)([[LastFMRadio sharedInstance] bufferProgress] * 100.0f)];
	}
	if([[LastFMRadio sharedInstance] state] == TRACK_BUFFERING && _loadingView.alpha < 1) {
		_loadingView.alpha = 1;
	}
	if([[LastFMRadio sharedInstance] state] == TRACK_BUFFERING && _loadingView.alpha == 1 && _bufferPercentage.alpha < 1) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:10];
		_bufferPercentage.alpha = 1;
		[UIView commitAnimations];
		if(_artworkView.frame.size.width == 320 && !_showedMetadata) {
			[self _showGradient];
		}
	}
	if([[LastFMRadio sharedInstance] state] != TRACK_BUFFERING && _loadingView.alpha == 1) {
		_bufferPercentage.alpha = 0;
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.5];
		_loadingView.alpha = 0;
		[UIView commitAnimations];
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
	
	if([artworkURL rangeOfString:@"amazon.com"].location != NSNotFound) {
		artworkURL = [artworkURL stringByReplacingOccurrencesOfString:@"MZZZ" withString:@"LZZZ"];
	}
	
	NSLog(@"Loading artwork: %@\n", artworkURL);
	if(artworkURL && ![artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_med.gif"] && ![artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_large.gif"]) {
		NSData *imageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString: artworkURL]];
		artworkImage = [[UIImage alloc] initWithData:imageData];
		[imageData release];
	} else {
		artworkURL = [NSString stringWithFormat:@"file:///%@/noartplaceholder.png", [[NSBundle mainBundle] bundlePath]];
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
	}
	[_lock unlock];
	[trackInfo release];
	[pool release];
}
- (void)_trackDidChange:(NSNotification *)notification {
	NSDictionary *trackInfo = [notification userInfo];
	
	_showedMetadata = NO;
	_trackTitle.text = [trackInfo objectForKey:@"title"];
	_artist.text = [trackInfo objectForKey:@"creator"];
	_elapsed.text = @"0:00";
	_remaining.text = [NSString stringWithFormat:@"-%@",[self formatTime:([[trackInfo objectForKey:@"duration"] floatValue] / 1000.0f)]];
	_progress.progress = 0;
	[artwork release];
	artwork = [[UIImage imageNamed:@"noartplaceholder.png"] retain];
	_reflectedArtworkView.image = artwork;
	[UIView beginAnimations:nil context:nil];
	_noArtworkView.alpha = 1;
	_badge.alpha = 0;
	[UIView commitAnimations];
	_artist.frame = CGRectMake(20,13,280,18);
	[self _updateProgress:nil];

	[NSThread detachNewThreadSelector:@selector(_fetchArtwork:) toTarget:self withObject:[notification userInfo]];
}
-(IBAction)artworkButtonPressed:(id)sender {
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.2];
	if(_artworkView.frame.size.width == 320) {
		_trackTitle.textAlignment = UITextAlignmentCenter;
		_artist.textAlignment = UITextAlignmentCenter;
		_artist.frame = CGRectMake(20,13,280,18);
		_trackTitle.frame = CGRectMake(20,30,280,18);
		_reflectionGradientView.frame = CGRectMake(0,236,320,180);
		_reflectedArtworkView.frame = CGRectMake(47,236,226,226);
		_artworkView.frame = CGRectMake(47,10,226,226);
		_noArtworkView.frame = CGRectMake(0,0,226,226);
		_fullscreenMetadataView.frame = CGRectMake(0,236,320,87);
		_fullscreenMetadataView.alpha = 1;
		_fullscreenMetadataView.image = nil;
		_trackTitle.alpha = 1;
		_artist.alpha = 1;
		_progress.alpha = 1;
		_elapsed.alpha = 1;
		_remaining.alpha = 1;
	} else {
		_reflectionGradientView.frame = CGRectMake(0,320,320,320);
		_reflectedArtworkView.frame = CGRectMake(0,320,320,320);
		_artworkView.frame = CGRectMake(0,0,320,320);
		_noArtworkView.frame = CGRectMake(0,0,320,320);
		_fullscreenMetadataView.frame = CGRectMake(0,256,320,87);
		_fullscreenMetadataView.alpha = 0;
		_trackTitle.alpha = 0;
		_artist.alpha = 0;
		_elapsed.alpha = 0;
		_remaining.alpha = 0;
		_progress.alpha = 0;
		_artworkView.image = artwork;
		//[self performSelector:@selector(_showMetadata) withObject:nil afterDelay:0.6];
	}
	[UIView commitAnimations];
}
@end

@implementation ArtistBioView
- (void)viewDidLoad {
	[super viewDidLoad];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
	_lock = [[NSLock alloc] init];
}
- (void)viewWillAppear:(BOOL)animated {
	[self refresh];
}
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchBio:) toTarget:self withObject:[notification userInfo]];
}
- (void)_fetchBio:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[trackInfo retain];
	[_lock lock];
	if([[trackInfo objectForKey:@"title"] isEqualToString:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"title"]] &&
		 [[trackInfo objectForKey:@"creator"] isEqualToString:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"creator"]]) {
		[self performSelectorOnMainThread:@selector(showLoadingView) withObject:nil waitUntilDone:YES];
		[_bio release];
		NSDictionary *artistinfo = [[LastFMService sharedInstance] metadataForArtist:[trackInfo objectForKey:@"creator"] inLanguage:[[[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"] objectAtIndex:0]];
		
		NSString *bio = [artistinfo objectForKey:@"bio"];
		if(![bio length]) {
			bio = [[[LastFMService sharedInstance] metadataForArtist:[trackInfo objectForKey:@"creator"] inLanguage:@"en"] objectForKey:@"bio"];
		}
		if(![bio length]) {
			bio = NSLocalizedString(@"No artist description available.", @"Wiki text empty");
		} else {
			NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
			[formatter setNumberStyle:NSNumberFormatterDecimalStyle];
			[_img release];
			_img = [[[artistinfo objectForKey:@"image"] stringByReplacingOccurrencesOfString:@"/126/" withString:@"/126s/"] retain];
			[_listeners release];
			_listeners = [[NSString stringWithFormat:@"%@ listeners",[formatter stringFromNumber:[NSNumber numberWithInt:[[artistinfo objectForKey:@"listeners"] intValue]]]] retain];
			[_playcount release];
			_playcount = [[NSString stringWithFormat:@"%@ plays",[formatter stringFromNumber:[NSNumber numberWithInt:[[artistinfo objectForKey:@"playcount"] intValue]]]] retain];
			[formatter release];
		}

		_bio = [[bio stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"] retain];
		[self performSelectorOnMainThread:@selector(refresh) withObject:nil waitUntilDone:YES];
		[self performSelectorOnMainThread:@selector(hideLoadingView) withObject:nil waitUntilDone:YES];
	}
	[_lock unlock];
	[trackInfo release];
	[pool release];
}
- (void)refresh {
	NSString *html = [NSString stringWithFormat:@"<html><head><style>a { color: #34A3EC; }</style></head>\
										<body style=\"margin:0; padding:0; color:black; background: white; font-family: Helvetica; font-size: 11pt;\">\
										<div style=\"padding:17px; margin:0; top:0px; left:0px; width:286; position:absolute;\">\
										<img src=\"%@\" style=\"margin-top: 4px; float: left; margin-right: 0px; margin-bottom: 14px; width:64px; height:64px; border:1px solid gray; padding: 1px;\"/>\
										<div style=\"float:right; width: 207px; padding:0px; margin:0px; margin-top:1px; margin-left:3px;\"><span style=\"font-size: 15pt; font-weight:bold; padding:0px; margin:0px;\">%@</span><br/>\
										<span style=\"color:gray; font-weight: normal; font-size: 10pt;\">%@<br/>%@</span></div>\
										<br style=\"clear:both;\"/>%@</div></body></html>", _img, [[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"creator"], _listeners, _playcount, _bio];
	self.navigationItem.title = [[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"creator"];
	[_webView loadHTMLString:html baseURL:nil];
}
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL *loadURL = [[request URL] retain];
	if(([[loadURL scheme] isEqualToString: @"http"] || [[loadURL scheme] isEqualToString: @"https"]) && (navigationType == UIWebViewNavigationTypeLinkClicked)) {
		[[UIApplication sharedApplication] openURLWithWarning:[loadURL autorelease]];
		return NO;
	}
	[loadURL release];
	return YES;
}
@end

@implementation EventCell
- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)identifier {
	if (self = [super initWithFrame:frame reuseIdentifier:identifier]) {
		_eventTitle = [[UILabel alloc] init];
		_eventTitle.textColor = [UIColor blackColor];
		_eventTitle.highlightedTextColor = [UIColor whiteColor];
		_eventTitle.backgroundColor = [UIColor whiteColor];
		_eventTitle.font = [UIFont boldSystemFontOfSize:14];
		_eventTitle.opaque = YES;
		[self.contentView addSubview:_eventTitle];
		
		_artists = [[UILabel alloc] init];
		_artists.textColor = [UIColor grayColor];
		_artists.highlightedTextColor = [UIColor whiteColor];
		_artists.backgroundColor = [UIColor whiteColor];
		_artists.font = [UIFont systemFontOfSize:14];
		_artists.opaque = YES;
		[self.contentView addSubview:_artists];
		
		_venue = [[UILabel alloc] init];
		_venue.textColor = [UIColor grayColor];
		_venue.highlightedTextColor = [UIColor whiteColor];
		_venue.backgroundColor = [UIColor whiteColor];
		_venue.font = [UIFont systemFontOfSize:14];
		_venue.opaque = YES;
		[self.contentView addSubview:_venue];

		_location = [[UILabel alloc] init];
		_location.textColor = [UIColor grayColor];
		_location.highlightedTextColor = [UIColor whiteColor];
		_location.backgroundColor = [UIColor whiteColor];
		_location.font = [UIFont systemFontOfSize:14];
		_location.opaque = YES;
		[self.contentView addSubview:_location];
	}
	return self;
}
- (void)setEvent:(NSDictionary *)event {
	_eventTitle.text = [event objectForKey:@"title"];
	NSMutableString *artists = [[NSMutableString alloc] initWithString:[event objectForKey:@"headliner"]];
	if([[event objectForKey:@"artists"] isKindOfClass:[NSArray class]] && [[event objectForKey:@"artists"] count] > 0) {
		for(NSString *artist in [event objectForKey:@"artists"]) {
			if(![artist isEqualToString:[event objectForKey:@"headliner"]])
				[artists appendFormat:@", %@", artist];
		}
	}
	_artists.text = artists;
	[artists release];
	_venue.text = [event objectForKey:@"venue"];
	_location.text = [NSString stringWithFormat:@"%@, %@", [event objectForKey:@"city"], NSLocalizedString([event objectForKey:@"country"], @"Country name")];
	_eventTitle.backgroundColor = [UIColor whiteColor];
	_artists.backgroundColor = [UIColor whiteColor];
	_venue.backgroundColor = [UIColor whiteColor];
	_location.backgroundColor = [UIColor whiteColor];
}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	[super setSelected:selected animated:animated];
	_eventTitle.highlighted = selected;
	_artists.highlighted = selected;
	_venue.highlighted = selected;
	_location.highlighted = selected;
	if(selected) {
		_eventTitle.backgroundColor = [UIColor clearColor];
		_artists.backgroundColor = [UIColor clearColor];
		_venue.backgroundColor = [UIColor clearColor];
		_location.backgroundColor = [UIColor clearColor];
	}
}
- (void)layoutSubviews {
	[super layoutSubviews];
	
	CGRect frame = [self.contentView bounds];
	if(frame.size.height > 42) {
		[self addSubview:_eventTitle];
		[self addSubview:_artists];
		_venue.font = [UIFont systemFontOfSize:14];
		_venue.textColor = [UIColor grayColor];
		frame.origin.x += 8;
		frame.origin.y += 4;
		frame.size.width -= 16;
		
		frame.size.height = 16;
		[_eventTitle setFrame: frame];
		
		frame.origin.y += 16;
		[_artists setFrame: frame];
		
		frame.origin.y += 16;
		[_venue setFrame: frame];
		
		frame.origin.y += 16;
		[_location setFrame: frame];
	} else {
		[_eventTitle removeFromSuperview];
		[_artists removeFromSuperview];
		_venue.font = [UIFont boldSystemFontOfSize:14];
		_venue.textColor = [UIColor blackColor];

		frame.origin.x += 8;
		frame.origin.y += 4;
		frame.size.width -= 16;
		
		frame.size.height = 16;
		[_venue setFrame: frame];
		
		frame.origin.y += 16;
		[_location setFrame: frame];
	}
}
-(void)dealloc {
	[_eventTitle release];
	[_artists release];
	[_venue release];
	[_location release];
	[super dealloc];
}
@end

@implementation EventDetailViewController
@synthesize event, delegate;
-(void)_updateEvent:(NSDictionary *)update {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[[LastFMService sharedInstance] attendEvent:[[update objectForKey:@"id"] intValue] status:attendance];
	if([LastFMService sharedInstance].error) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
	}
	[pool release];
}
-(void)_fetchImage:(NSString *)url {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSData *imageData;
	if(shouldUseCache(CACHE_FILE([url md5sum]), 1*HOURS)) {
		imageData = [[NSData alloc] initWithContentsOfFile:CACHE_FILE([url md5sum])];
	} else {
		imageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString:url]];
		[imageData writeToFile:CACHE_FILE([url md5sum]) atomically: YES];
	}
	UIImage *image = [[UIImage alloc] initWithData:imageData];
	_image.image = image;
	[image release];
	[imageData release];
	[pool release];
}
- (void)viewDidLoad {
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"EEE, dd MMM yyyy"];
	NSDate *date = [formatter dateFromString:[event objectForKey:@"startDate"]];
	[formatter setLocale:[NSLocale currentLocale]];
	
	[formatter setDateFormat:@"MMM"];
	_month.text = [formatter stringFromDate:date];
	
	[formatter setDateFormat:@"d"];
	_day.text = [formatter stringFromDate:date];
	
	[formatter release];
	
	_eventTitle.text = [event objectForKey:@"title"];
	NSMutableString *artists = [[NSMutableString alloc] initWithString:[event objectForKey:@"headliner"]];
	if([[event objectForKey:@"artists"] isKindOfClass:[NSArray class]] && [[event objectForKey:@"artists"] count] > 0) {
		for(NSString *artist in [event objectForKey:@"artists"]) {
			if(![artist isEqualToString:[event objectForKey:@"headliner"]])
				[artists appendFormat:@", %@", artist];
		}
	}
	_artists.text = artists;
	[artists release];
	_venue.text = [event objectForKey:@"venue"];
	NSMutableString *address = [[NSMutableString alloc] init];
	if([[event objectForKey:@"street"] length]) {
		[address appendFormat:@"%@\n", [event objectForKey:@"street"]];
	}
	if([[event objectForKey:@"city"] length]) {
		[address appendFormat:@"%@ ", [event objectForKey:@"city"]];
	}
	if([[event objectForKey:@"postalcode"] length]) {
		[address appendFormat:@"%@", [event objectForKey:@"postalcode"]];
	}
	if([[event objectForKey:@"country"] length]) {
		[address appendFormat:@"\n%@", [event objectForKey:@"country"]];
	}
	_address.text = address;
	[address release];
	[NSThread detachNewThreadSelector:@selector(_fetchImage:) toTarget:self withObject:[event objectForKey:@"image"]];
}
- (IBAction)willAttendButtonPressed:(id)sender {
	self.attendance = eventStatusAttending;
}
- (IBAction)mightAttendButtonPressed:(id)sender {
	self.attendance = eventStatusMaybeAttending;
}
- (IBAction)notAttendButtonPressed:(id)sender {
	self.attendance = eventStatusNotAttending;
}
- (int)attendance {
	return attendance;
}
- (void)setAttendance:(int)status {
	attendance = status;
	_willAttendBtn.selected = NO;
	_mightAttendBtn.selected = NO;
	_notAttendBtn.selected = NO;
	
	switch(attendance) {
		case eventStatusNotAttending:
			_notAttendBtn.selected = YES;
			break;
		case eventStatusMaybeAttending:
			_mightAttendBtn.selected = YES;
			break;
		case eventStatusAttending:
			_willAttendBtn.selected = YES;
			break;
	}
}
- (IBAction)doneButtonPressed:(id)sender {
	[NSThread detachNewThreadSelector:@selector(_updateEvent:)
													 toTarget:self
												 withObject:[NSDictionary dictionaryWithObjectsAndKeys:[event objectForKey:@"id"], @"id", nil]];
	[delegate doneButtonPressed:self];
}
- (IBAction)mapsButtonPressed:(id)sender {
	NSMutableString *query =[[NSMutableString alloc] init];
	if([[event objectForKey:@"street"] length]) {
		[query appendFormat:@"%@,", [event objectForKey:@"street"]];
	}
	if([[event objectForKey:@"city"] length]) {
		[query appendFormat:@" %@,", [event objectForKey:@"city"]];
	}
	if([[event objectForKey:@"postalcode"] length]) {
		[query appendFormat:@" %@", [event objectForKey:@"postalcode"]];
	}
	if([[event objectForKey:@"country"] length]) {
		[query appendFormat:@" %@", [event objectForKey:@"country"]];
	}
	[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:[NSString stringWithFormat:@"http://maps.google.com/?f=q&q=%@&ie=UTF8&om=1&iwloc=addr", [query URLEscaped]]]];
}
@end

@implementation EventsViewController
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchEvents:) toTarget:self withObject:[notification userInfo]];
}
- (BOOL)isAttendingEvent:(NSString *)event_id {
	for(NSString *event in _attendingEvents) {
		if([event isEqualToString:event_id]) {
			return YES;
		}
	}
	return NO;
}
- (void)viewTypeToggled:(id)sender {
	switch([(UISegmentedControl *)sender selectedSegmentIndex]) {
		case 1:
			_table.frame = CGRectMake(0,372,320,0);
			_shadow.frame = CGRectMake(0,372,320,0);
			break;
		case 0:
			if(_username)
				_table.frame = CGRectMake(0,0,320,372);
			else
				_table.frame = CGRectMake(0,0,320,326);
			_shadow.frame = CGRectMake(0,372,320,0);
			[_data release];
			_data = nil;
			[_table reloadData];
			break;
	}
}
- (void)_processEvents:(NSArray *)events {
	int i=0,lasti=0;
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"EEE, dd MMM yyyy"];
	[_events release];
	[_eventDates release];
	[_eventDateOffsets release];
	[_eventDateCounts release];
	_events = [events retain];
	_eventDates = [[NSMutableArray alloc] init];
	_eventDateOffsets = [[NSMutableArray alloc] init];
	_eventDateCounts = [[NSMutableArray alloc] init];
	
	if([_events count]) {
		NSDate *date, *lastDate = [formatter dateFromString:[[_events objectAtIndex:0] objectForKey:@"startDate"]];
		
		for(NSDictionary *event in _events) {
			date = [formatter dateFromString:[event objectForKey:@"startDate"]];
			if(![lastDate isEqualToDate:date]) {
				[_eventDateOffsets addObject:[NSNumber numberWithInt:lasti]];
				[_eventDateCounts addObject:[NSNumber numberWithInt:i - lasti]];
				[_eventDates addObject:lastDate];
				lasti = i;
				lastDate = date;
			}
			i++;
		}
		[_eventDateOffsets addObject:[NSNumber numberWithInt:lasti]];
		[_eventDates addObject:lastDate];
		[_eventDateCounts addObject:[NSNumber numberWithInt:i - lasti]];
	}
	[_calendar performSelectorOnMainThread:@selector(setEventDates:) withObject:_eventDates waitUntilDone:YES];
	[_table reloadData];
	[formatter release];
}
- (void)viewDidLoad {
	_calendar = [[CalendarViewController alloc] initWithNibName:@"CalendarView" bundle:nil];
	_calendar.delegate = self;
	[self.view addSubview: _calendar.view];
	[self.view sendSubviewToBack: _calendar.view];
	if(_username) {
		segment = [[[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Calendar",@"List",nil]] autorelease];
		segment.frame = CGRectMake(0,0,207,30);
		segment.segmentedControlStyle = UISegmentedControlStyleBar;
		segment.selectedSegmentIndex = 1;
		[segment addTarget:self action:@selector(viewTypeToggled:) forControlEvents:UIControlEventValueChanged];
		UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0,372,320,44)];
		toolbar.barStyle = UIBarStyleBlackOpaque;
		toolbar.items = [NSArray arrayWithObjects: [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
										 [[[UIBarButtonItem alloc] initWithCustomView:segment] autorelease],
										 [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],nil];
		[self.view addSubview:toolbar];
		[toolbar release];
		_table = [[UITableView alloc] initWithFrame:CGRectMake(0,372,320,0)];
		_table.delegate = self;
		_table.dataSource = self;
		[self.view addSubview:_table];
		NSArray *events = [[LastFMService sharedInstance] eventsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
		_attendingEvents = [[NSMutableArray alloc] init];
		for(NSDictionary *event in events) {
			[_attendingEvents addObject:[event objectForKey:@"id"]];
		}
		events = [[LastFMService sharedInstance] eventsForUser:_username];

		if([LastFMService sharedInstance].error) {
			[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
			[self release];
		}
		[self _processEvents:events];
	} else {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
	}
	segment.tintColor = [UIColor grayColor];
	_lock = [[NSLock alloc] init];
}
- (id)initWithUsername:(NSString *)user {
	if(self = [super init]) {
		self.title = [NSString stringWithFormat:NSLocalizedString(@"%@'s Events", @"User events title"), user];
		_username = [user retain];
	}
	return self;
}
- (void)_updateBadge {
	if([_events count]) {
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
- (void)_fetchEvents:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[trackInfo retain];
	[_lock lock];
	if([[trackInfo objectForKey:@"title"] isEqualToString:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"title"]] &&
		 [[trackInfo objectForKey:@"creator"] isEqualToString:[[[LastFMRadio sharedInstance] trackInfo] objectForKey:@"creator"]]) {
		[self performSelectorOnMainThread:@selector(showLoadingView) withObject:nil waitUntilDone:YES];
		[_attendingEvents release];
		_attendingEvents = [[NSMutableArray alloc] init];
		NSArray *attendingEvents = [[LastFMService sharedInstance] eventsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
		for(NSDictionary *event in attendingEvents) {
			[_attendingEvents addObject:[event objectForKey:@"id"]];
		}
		
		NSArray *events = [[LastFMService sharedInstance] eventsForArtist:[trackInfo objectForKey:@"creator"]];
		[self _processEvents:events];
		
		if([[[NSUserDefaults standardUserDefaults] objectForKey:@"showontour"] isEqualToString:@"YES"])
			[self performSelectorOnMainThread:@selector(_updateBadge) withObject:nil waitUntilDone:YES];
		[self performSelectorOnMainThread:@selector(hideLoadingView) withObject:nil waitUntilDone:YES];
	}
	[_lock unlock];
	[trackInfo release];
	[pool release];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if(_data)
		return 1;
	else if([_events count])
		return [_eventDates count];
	else
		return 1;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if([_eventDates count]) {
		NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
		[formatter setDateStyle:NSDateFormatterLongStyle];
		NSString *output = [formatter stringFromDate:[_eventDates objectAtIndex:section]];
		[formatter release];
		return output;
	}
	else
		return nil;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(_data)
		return [_data count];
	else if([_events count])
		return [[_eventDateCounts objectAtIndex:section] intValue];
	else
		return 1;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(_data)
		return 42;
	else
		return 78;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	if([_events count]) {
		EventDetailViewController *e = [[EventDetailViewController alloc] initWithNibName:@"EventDetailsView" bundle:nil];
		if(_data)
			e.event = [_data objectAtIndex:[newIndexPath row]];
		else {
			int offset = [[_eventDateOffsets objectAtIndex:[newIndexPath section]] intValue];
			e.event = [_events objectAtIndex:[newIndexPath row]+offset];
		}
		e.delegate = self;
		if(_username)
			[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)).rootViewController presentModalViewController:e animated:YES];
		else
			[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)).playbackViewController presentModalViewController:e animated:YES];
		if([self isAttendingEvent:[e.event objectForKey:@"id"]]) {
			[e setAttendance:eventStatusAttending];
		} else {
			[e setAttendance:eventStatusNotAttending];
		}
		[e release];
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
	}
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (void)calendarViewController:(CalendarViewController *)c didSelectDate:(NSDate *)d {
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"EEE, dd MMM yyyy"];
	[_data release];
	_data = [[NSMutableArray alloc] init];
	
	for(NSDictionary *event in _events) {
		if([[event objectForKey:@"startDate"] hasPrefix:[formatter stringFromDate:d]])
			[_data addObject:event];
	}
	if(![_data count]) {
		[_data release];
		_data = nil;
	}
	
	if([_data count] > 1) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.2];
		if(_username) {
			_table.frame = CGRectMake(0,264,320,108);
			_shadow.frame = CGRectMake(0,264,320,18);
		} else {
			_table.frame = CGRectMake(0,218,320,108);
			_shadow.frame = CGRectMake(0,218,320,18);
		}
		[UIView commitAnimations];
	} else {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.2];
		_table.frame = CGRectMake(0,372,320,0);
		_shadow.frame = CGRectMake(0,372,320,0);
		[UIView commitAnimations];
		if([_data count])
			[self tableView:_table didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	}
	[_table reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([_events count]) {
		int offset = [[_eventDateOffsets objectAtIndex:[indexPath section]] intValue];
		EventCell *cell = (EventCell *)[tableView dequeueReusableCellWithIdentifier:@"eventcell"];
		if(!cell)
			cell = [[[EventCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"eventcell"] autorelease];
		if(_data)
			[cell setEvent:[_data objectAtIndex:[indexPath row]]];
		else
			[cell setEvent:[_events objectAtIndex:[indexPath row]+offset]];
		return cell;
	} else {
		UITableViewCell *cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero] autorelease];
		cell.text = @"No Upcoming Events";
		return cell;
	}
}
- (void)doneButtonPressed:(id)sender {
	EventDetailViewController *e = (EventDetailViewController *)sender;
	if([e attendance] == eventStatusNotAttending) {
		[_attendingEvents removeObject:[e.event objectForKey:@"id"]];
		if(_username) {
			NSMutableArray *events = [[NSMutableArray alloc] init];
			for(NSDictionary *event in _events) {
				if(![[event objectForKey:@"id"] isEqualToString:[e.event objectForKey:@"id"]])
					[events addObject:event];
			}
			[self _processEvents:events];
			[events release];
		}
	} else {
		[_attendingEvents addObject:[e.event objectForKey:@"id"]];
	}
	[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)).rootViewController dismissModalViewControllerAnimated:YES];
	if([_data count]) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.2];
		_calendar.view.frame = CGRectMake(0,0,320,372);
		_table.frame = CGRectMake(0,372,320,0);
		_shadow.frame = CGRectMake(0,372,320,0);
		[UIView commitAnimations];
	}
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
}
- (void)dealloc {
	[_events release];
	[_eventDates release];
	[super dealloc];
}
@end

@implementation PlaybackViewController
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
	[volumeView removeFromSuperview];
	volumeView = v;
	[volumeView sizeToFit];
	[trackView.view addSubview: volumeView];
#endif
	if([[SystemNowPlayingController sharedInstance] respondsToSelector:@selector(postNowPlayingInfoForSongWithPath:title:artist:album:isPlaying:hasImageData:additionalInfo:)])
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_systemVolumeChanged:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
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
- (void)hideDetailsView {
	if([[detailView subviews] count])
		[self detailsButtonPressed:self];
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	_titleLabel.text = [[[LastFMRadio sharedInstance] station] capitalizedString];
	
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue]) {
		artistBio.view.frame = CGRectMake(0,0,320,369);
		tags.view.frame = CGRectMake(0,0,320,369);
		similarArtists.view.frame = CGRectMake(0,0,320,369);
		fans.view.frame = CGRectMake(0,0,320,369);
		events.view.frame = CGRectMake(0,0,320,369);
		[ad release];
		ad = nil;
	} else {
		artistBio.view.frame = CGRectMake(0,0,320,321);
		tags.view.frame = CGRectMake(0,0,320,321);
		similarArtists.view.frame = CGRectMake(0,0,320,321);
		fans.view.frame = CGRectMake(0,0,320,321);
		events.view.frame = CGRectMake(0,4,320,321);
	}	
}
- (void)_trackDidChange:(NSNotification *)notification {
	if([[detailView subviews] count])
		[self detailsButtonPressed:nil];
	_titleLabel.text = [[[LastFMRadio sharedInstance] station] capitalizedString];
	loveBtn.alpha = 1;
	banBtn.alpha = 1;
	if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue]) {
		[ad removeFromSuperview];
		[ad release];
		ad = [[AdMobView requestAdWithDelegate:(MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate] retain];
		ad.frame = CGRectMake(0, 0, 320, 48);
	}
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)backButtonPressed:(id)sender {
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hidePlaybackView];
}
- (void)detailsButtonPressed:(id)sender {
	if([[detailView subviews] count]) {
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
		[[detailView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
		[contentView addSubview: trackView.view];
		[UIView commitAnimations];
		_titleLabel.text = [[[LastFMRadio sharedInstance] station] capitalizedString];
	} else {
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
		[contentView addSubview: detailsViewContainer];
		if(ad)
			detailsViewContainer.frame = CGRectMake(0,48,320,368);
		else
			detailsViewContainer.frame = CGRectMake(0,0,320,416);
		tabBar.selectedItem = [tabBar.items objectAtIndex:0];
		[self tabBar:tabBar didSelectItem:tabBar.selectedItem];
		[UIView commitAnimations];
	}
}
-(void)onTourButtonPressed:(id)sender {
	[self detailsButtonPressed:sender];
	tabBar.selectedItem = [tabBar.items objectAtIndex: 3];
	[self tabBar:tabBar didSelectItem:tabBar.selectedItem];
}
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
	[[detailView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	switch(item.tag) {
		case 0:
			[artistBio viewWillAppear:NO];
			[detailView addSubview:artistBio.view];
			_titleLabel.text = NSLocalizedString(@"Artist Bio", @"Artist Bio tab title");
			break;
		case 1:
			[tags viewWillAppear:NO];
			[detailView addSubview:tags.view];
			_titleLabel.text = NSLocalizedString(@"Tags", @"Tags tab title");
			break;
		case 2:
			[similarArtists viewWillAppear:NO];
			[detailView addSubview:similarArtists.view];
			_titleLabel.text = NSLocalizedString(@"Similar Artists", @"Similar Artists tab title");
			break;
		case 3:
			[events viewWillAppear:NO];
			[detailView addSubview:events.view];
			_titleLabel.text = NSLocalizedString(@"Events", @"Events tab title");
			break;
		case 4:
			[fans viewWillAppear:NO];
			[detailView addSubview:fans.view];
			_titleLabel.text = NSLocalizedString(@"Top Listeners", @"Top Listeners tab title");
			break;
	}
	if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue]) {
		[ad removeFromSuperview];
		[ad release];
		ad = [[AdMobView requestAdWithDelegate:(MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate] retain];
		ad.frame = CGRectMake(0, 0, 320, 48);
		[contentView addSubview: ad];
	}
}
- (void)shareToAddressBook {
	ABPeoplePickerNavigationController *peoplePicker = [[ABPeoplePickerNavigationController alloc] init];
	peoplePicker.displayedProperties = [NSArray arrayWithObjects:[NSNumber numberWithInteger:kABPersonEmailProperty], nil];
	peoplePicker.peoplePickerDelegate = self;
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController presentModalViewController:peoplePicker animated:YES];
	[peoplePicker release];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
}
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person {
	return YES;
}
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker shouldContinueAfterSelectingPerson:(ABRecordRef)person property:(ABPropertyID)property identifier:(ABMultiValueIdentifier)identifier {
	NSDictionary *trackInfo = [((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) trackInfo];
	NSString *email = (NSString *)ABMultiValueCopyValueAtIndex(ABRecordCopyValue(person, property), ABMultiValueGetIndexForIdentifier(ABRecordCopyValue(person, property), identifier));
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).playbackViewController dismissModalViewControllerAnimated:YES];
	
	[[LastFMService sharedInstance] recommendTrack:[trackInfo objectForKey:@"title"]
																				byArtist:[trackInfo objectForKey:@"creator"]
																	toEmailAddress:email];
	
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
-(void)playlistViewControllerDidCancel {
	[self dismissModalViewControllerAnimated:YES];
}
-(void)_addToPlaylist:(NSNumber *)playlist {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *trackInfo = [[[LastFMRadio sharedInstance] trackInfo] retain];
	[[LastFMService sharedInstance] addTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"] toPlaylist:[playlist intValue]];
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) performSelectorOnMainThread:@selector(reportError:) withObject:[LastFMService sharedInstance].error waitUntilDone:YES];
	[trackInfo release];
	[pool release];
}
-(void)playlistViewControllerDidSelectPlaylist:(int)playlist {
	[self dismissModalViewControllerAnimated:YES];
	[NSThread detachNewThreadSelector:@selector(_addToPlaylist:) toTarget:self withObject:[NSNumber numberWithInt:playlist]];
}
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	NSDictionary *trackInfo = [((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) trackInfo];

	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Share", @"Share button")]) {
		UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Who would you like to share this track with?", @"Share sheet title")
																											 delegate:self
																							cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
																				 destructiveButtonTitle:nil
																							otherButtonTitles:NSLocalizedString(@"Contacts", @"Share to Address Book"), NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
		[sheet showInView:self.view];
		[sheet release];	
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Tag", @"Tag button")]) {
		TagEditorViewController *t = [[TagEditorViewController alloc] initWithNibName:@"TagEditorView" bundle:nil];
		t.delegate = self;
		t.myTags = [[[LastFMService sharedInstance] tagsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] sortedArrayUsingFunction:tagSort context:nil];
		t.artistTopTags = [[[LastFMService sharedInstance] topTagsForArtist:[trackInfo objectForKey:@"creator"]] sortedArrayUsingFunction:tagSort context:nil];
		t.albumTopTags = [[[LastFMService sharedInstance] topTagsForAlbum:[trackInfo objectForKey:@"album"] byArtist:[trackInfo objectForKey:@"creator"]] sortedArrayUsingFunction:tagSort context:nil];
		t.trackTopTags = [[[LastFMService sharedInstance] topTagsForTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]] sortedArrayUsingFunction:tagSort context:nil];
		[t setArtistTags: [[LastFMService sharedInstance] tagsForArtist:[trackInfo objectForKey:@"creator"]]];
		[t setAlbumTags: [[LastFMService sharedInstance] tagsForAlbum:[trackInfo objectForKey:@"album"] byArtist:[trackInfo objectForKey:@"creator"]]];
		[t setTrackTags: [[LastFMService sharedInstance] tagsForTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]]];
		[self presentModalViewController:t animated:YES];
		[t release];
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Add to Playlist", @"Add to Playlist button")]) {
		PlaylistsViewController *p = [[PlaylistsViewController alloc] init];
		p.delegate = self;
		UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:p];
		[self presentModalViewController:n animated:YES];
		[p release];
		[n release];
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Buy on iTunes", @"Buy on iTunes button")]) {
		NSString *ITMSURL = [NSString stringWithFormat:@"http://phobos.apple.com/WebObjects/MZSearch.woa/wa/search?term=%@+%@&s=143444&partnerId=2003&affToken=www.last.fm", 
												 [trackInfo objectForKey:@"creator"],
												 [trackInfo objectForKey:@"title"]];
		NSString *URL;
		if([[[NSUserDefaults standardUserDefaults] objectForKey:@"country"] isEqualToString:@"United States"])
			URL = [NSString stringWithFormat:@"http://click.linksynergy.com/fs-bin/stat?id=bKEBG4*hrDs&offerid=78941&type=3&subid=0&tmpid=1826&RD_PARM1=%@", [[ITMSURL URLEscaped] stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"]];
		else
			URL = [NSString stringWithFormat:@"http://clk.tradedoubler.com/click?p=23761&epi=GB_site&a=1474288&url=%@", [[ITMSURL URLEscaped] stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"]];
		
		[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:URL]];
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Contacts", @"Share to Address Book")]) {
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
																															NSLocalizedString(@"Add to Playlist", @"Add to Playlist button"),
																															NSLocalizedString(@"Buy on iTunes", @"Buy on iTunes button"),
																															nil];
	sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
	[sheet showInView:self.view];
	[sheet release];
}
-(void)tagEditorDidCancel {
	[self dismissModalViewControllerAnimated:YES];
}
- (void)tagEditorAddArtistTags:(NSArray *)artistTags albumTags:(NSArray *)albumTags trackTags:(NSArray *)trackTags {
	NSDictionary *trackInfo = [[LastFMRadio sharedInstance] trackInfo];
	[[LastFMService sharedInstance] addTags:artistTags toArtist:[trackInfo objectForKey:@"creator"]];
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	[[LastFMService sharedInstance] addTags:albumTags toAlbum:[trackInfo objectForKey:@"album"] byArtist:[trackInfo objectForKey:@"creator"]];
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	[[LastFMService sharedInstance] addTags:trackTags toTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]];
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	[self dismissModalViewControllerAnimated:YES];
}
- (void)tagEditorRemoveArtistTags:(NSArray *)artistTags albumTags:(NSArray *)albumTags trackTags:(NSArray *)trackTags {
	NSDictionary *trackInfo = [[LastFMRadio sharedInstance] trackInfo];
	for(NSString *tag in artistTags) {
		[[LastFMService sharedInstance] removeTag:tag fromArtist:[trackInfo objectForKey:@"creator"]];
		if([LastFMService sharedInstance].error)
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	}
	for(NSString *tag in albumTags) {
		[[LastFMService sharedInstance] removeTag:tag fromAlbum:[trackInfo objectForKey:@"album"] byArtist:[trackInfo objectForKey:@"creator"]];
		if([LastFMService sharedInstance].error)
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	}
	for(NSString *tag in trackTags) {
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
- (void)dealloc {
	[super dealloc];
}
@end
