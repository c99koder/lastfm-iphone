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
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.5];
	_loadingView.alpha = 1;
	[UIView commitAnimations];
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
}
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchSimilarArtists:) toTarget:self withObject:[notification userInfo]];
}
- (void)_fetchSimilarArtists:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[trackInfo retain];
	[_lock lock];
	[self showLoadingView];
	[_data release];
	[_cells removeAllObjects];
	_data = [[LastFMService sharedInstance] artistsSimilarTo:[trackInfo objectForKey:@"creator"]];
	_data = [[_data subarrayWithRange:NSMakeRange(0,([_data count]>25)?25:[_data count])] retain];
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
	[self performSelectorOnMainThread:@selector(loadContentForCells:) withObject:[_table visibleCells] waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(hideLoadingView) withObject:nil waitUntilDone:YES];
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
	[self playRadioStation:[NSString stringWithFormat:@"lastfm://artist/%@/similarartists", [[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"name"] URLEscaped]]];
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
	[self showLoadingView];
	[_data release];
	_data = [[[LastFMService sharedInstance] topTagsForTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]] sortedArrayUsingFunction:tagSort context:nil];
	_data = [[_data subarrayWithRange:NSMakeRange(0,([_data count]>10)?10:[_data count])] retain];
	[_table reloadData];
	[_table scrollRectToVisible:[_table frame] animated:YES];
	[self performSelectorOnMainThread:@selector(hideLoadingView) withObject:nil waitUntilDone:YES];
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
	[self playRadioStation:[NSString stringWithFormat:@"lastfm://globaltags/%@", [[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"name"] URLEscaped]]];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:nil] autorelease];
	cell.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"name"];
	float width = [[[_data objectAtIndex:[indexPath row]] objectForKey:@"count"] floatValue] / [[[_data objectAtIndex:0] objectForKey:@"count"] floatValue];
	UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0,0,width * [cell frame].size.width,48)];
	bar.backgroundColor = [UIColor colorWithWhite:0.8 alpha:0.4];
	[cell.contentView addSubview:bar];
	[bar release];
	UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
	cell.accessoryView = img;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	[img release];
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
}
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchFans:) toTarget:self withObject:[notification userInfo]];
}
- (void)_fetchFans:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[trackInfo retain];
	[_lock lock];
	[self performSelectorOnMainThread:@selector(showLoadingView) withObject:nil waitUntilDone:YES];
	[_data release];
	[_cells removeAllObjects];
	_data = [[LastFMService sharedInstance] fansOfTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]];
	_data = [[_data subarrayWithRange:NSMakeRange(0,([_data count]>10)?10:[_data count])] retain];
	for(NSDictionary *fan in _data) {
		ArtworkCell *cell = [[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:nil];
		cell.title.text = [fan objectForKey:@"username"];
		cell.imageURL = [fan objectForKey:@"image"];
		[_cells addObject:cell];
		[cell release];
	}
	[_table reloadData];
	[_table scrollRectToVisible:[_table frame] animated:YES];
	[self performSelectorOnMainThread:@selector(loadContentForCells:) withObject:[_table visibleCells] waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(hideLoadingView) withObject:nil waitUntilDone:YES];
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
	ProfileViewController *profileViewController = [[ProfileViewController alloc] initWithUsername:[timer userInfo]];
	//[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).navController pushViewController:profileViewController animated:NO];
	[profileViewController release];
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hidePlaybackView];
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
	return [_cells objectAtIndex:[indexPath row]];
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
	
	NSLog(@"Loading artwork: %@\n", artworkURL);
	if(artworkURL && ![artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_med.gif"] && ![artworkURL isEqualToString:@"http://cdn.last.fm/depth/catalogue/noimage/cover_large.gif"]) {
		NSData *imageData = [[NSData alloc] initWithContentsOfURL:[NSURL URLWithString: artworkURL]];
		artworkImage = [[UIImage alloc] initWithData:imageData];
		[imageData release];
	} else {
		artworkURL = [NSString stringWithFormat:@"file:///%@/noartplaceholder.png", [[NSBundle mainBundle] bundlePath]];
		artworkImage = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"noartplaceholder" ofType:@"png"]];
	}

	_artworkView.image = artworkImage;
	_reflectedArtworkView.image = artworkImage;
	[artwork release];
	artwork = artworkImage;
	[trackInfo release];
	[pool release];
}
- (void)_trackDidChange:(NSNotification *)notification {
	NSDictionary *trackInfo = [notification userInfo];
	
	_trackTitle.text = [trackInfo objectForKey:@"title"];
	_artist.text = [trackInfo objectForKey:@"creator"];
	_elapsed.text = @"0:00";
	_remaining.text = [NSString stringWithFormat:@"-%@",[self formatTime:([[trackInfo objectForKey:@"duration"] floatValue] / 1000.0f)]];
	_progress.progress = 0;
	[artwork release];
	artwork = [[UIImage imageNamed:@"noartplaceholder.png"] retain];
	_artworkView.image = artwork;
	_reflectedArtworkView.image = artwork;
	[self _updateProgress:nil];

	[NSThread detachNewThreadSelector:@selector(_fetchArtwork:) toTarget:self withObject:[notification userInfo]];
}
-(IBAction)artworkButtonPressed:(id)sender {
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.2];
	if(_artworkView.frame.size.width == 320) {
		_reflectionGradientView.frame = CGRectMake(0,246,320,170);
		_reflectedArtworkView.frame = CGRectMake(47,246,226,226);
		_artworkView.frame = CGRectMake(47,20,226,226);
		_trackTitle.alpha = 1;
		_artist.alpha = 1;
		_progress.alpha = 1;
		_elapsed.alpha = 1;
		_remaining.alpha = 1;
	} else {
		_reflectionGradientView.frame = CGRectMake(0,320,320,320);
		_reflectedArtworkView.frame = CGRectMake(0,320,320,320);
		_artworkView.frame = CGRectMake(0,0,320,320);
		_trackTitle.alpha = 0;
		_artist.alpha = 0;
		_progress.alpha = 0;
		_elapsed.alpha = 0;
		_remaining.alpha = 0;
		_artworkView.image = artwork;
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
	[self performSelectorOnMainThread:@selector(showLoadingView) withObject:nil waitUntilDone:YES];
	[_bio release];
	NSString *bio = [[[LastFMService sharedInstance] metadataForArtist:[trackInfo objectForKey:@"creator"] inLanguage:[[[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"] objectAtIndex:0]] objectForKey:@"bio"];
	if(![bio length]) {
		bio = [[[LastFMService sharedInstance] metadataForArtist:[trackInfo objectForKey:@"creator"] inLanguage:@"en"] objectForKey:@"bio"];
	}
	if(![bio length]) {
		bio = NSLocalizedString(@"No artist description available.", @"Wiki text empty");
	}

	_bio = [[bio stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"] retain];
	[self performSelectorOnMainThread:@selector(refresh) withObject:nil waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(hideLoadingView) withObject:nil waitUntilDone:YES];
	[_lock unlock];
	[trackInfo release];
	[pool release];
}
- (void)refresh {
	NSString *html = [NSString stringWithFormat:@"<html>\
										<body style=\"margin:0; padding:0; color:black; background: white; font-family: 'Lucida Grande', Arial; line-height: 1.2em;\">\
										<div style=\"padding:12px; margin:0; top:0px; left:0px; width:260px; position:absolute;\">\
										%@</div></body></html>", _bio];
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
		_venue = [[UILabel alloc] init];
		_venue.textColor = [UIColor blackColor];
		_venue.highlightedTextColor = [UIColor whiteColor];
		_venue.backgroundColor = [UIColor clearColor];
		_venue.font = [UIFont boldSystemFontOfSize:14];
		[self.contentView addSubview:_venue];

		_location = [[UILabel alloc] init];
		_location.textColor = [UIColor blackColor];
		_location.highlightedTextColor = [UIColor whiteColor];
		_location.backgroundColor = [UIColor clearColor];
		_location.font = [UIFont systemFontOfSize:14];
		[self.contentView addSubview:_location];
	}
	return self;
}
- (void)setEvent:(NSDictionary *)event {
	_venue.text = [event objectForKey:@"venue"];
	_location.text = [NSString stringWithFormat:@"%@, %@", [event objectForKey:@"city"], NSLocalizedString([event objectForKey:@"country"], @"Country name")];
}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	[super setSelected:selected animated:animated];
	_venue.highlighted = selected;
	_location.highlighted = selected;
}
- (void)layoutSubviews {
	[super layoutSubviews];
	
	CGRect frame = [self.contentView bounds];
	frame.origin.x += 8;
	frame.origin.y += 4;
	frame.size.width -= 16;
	
	frame.size.height = 16;
	[_venue setFrame: frame];
	
	frame.origin.y += 16;
	[_location setFrame: frame];
}
-(void)dealloc {
	[_venue release];
	[_location release];
	[super dealloc];
}
@end

@implementation EventsListViewController
- (void)loadView {
	[super loadView];
	if(_username)
		[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	self.view = _table;
}
- (void)viewDidLoad {
	[super viewDidLoad];
	if(!_username)
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
	_lock = [[NSLock alloc] init];
}
- (void)viewWillAppear:(BOOL)animated {
	[_table scrollRectToVisible:[_table frame] animated:NO];
	if(_username)
		[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
}
- (void)_trackDidChange:(NSNotification*)notification {
	[NSThread detachNewThreadSelector:@selector(_fetchEvents:) toTarget:self withObject:[notification userInfo]];
}
- (void)_processEvents:(NSArray *)events {
	int i,lasti = 0;
	[_events release];
	[_eventDates release];

	_events = [events retain];
	_eventDates = [[NSMutableArray alloc] init];
	
	if([_events count]) {
		NSString *date, *lastDate = [self formatDate:[[_events objectAtIndex:0] objectForKey:@"startDate"]];
		
		for(i=0; i<[_events count]; i++) {
			NSDictionary *event = [_events objectAtIndex:i];
			date = [self formatDate:[event objectForKey:@"startDate"]];
			if(![lastDate isEqualToString:date]) {
				[_eventDates addObject:[NSDictionary dictionaryWithObjectsAndKeys:lastDate,@"date",[NSNumber numberWithInt:i-lasti],@"count",[NSNumber numberWithInt:lasti],@"index",nil]];
				lasti = i;
				lastDate = date;
			}
		}
		[_eventDates addObject:[NSDictionary dictionaryWithObjectsAndKeys:lastDate,@"date",[NSNumber numberWithInt:i-lasti],@"count",[NSNumber numberWithInt:lasti],@"index",nil]];
		self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%i", [_events count]];
	} else {
		self.tabBarItem.badgeValue = nil;
	}
	[_table reloadData];
	[_table scrollRectToVisible:[_table frame] animated:YES];
}
- (BOOL)isAttendingEvent:(NSString *)event_id {
	for(NSString *event in _attendingEvents) {
		if([event isEqualToString:event_id]) {
			return YES;
		}
	}
	return NO;
}
- (id)initWithUsername:(NSString *)user {
	if(self = [super init]) {
		self.title = [NSString stringWithFormat:@"%@'s Events", user];
		_username = [user retain];
		_table = [[UITableView alloc] initWithFrame:CGRectMake(0,0,320,460)];
		_table.delegate = self;
		_table.dataSource = self;
		NSArray *events = [[LastFMService sharedInstance] eventsForUser:user];
		if([LastFMService sharedInstance].error) {
			[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
			[self release];
			return nil;
		}
		[self _processEvents:events];
		events = [[LastFMService sharedInstance] eventsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
		_attendingEvents = [[NSMutableArray alloc] init];
		for(NSDictionary *event in events) {
			[_attendingEvents addObject:[event objectForKey:@"id"]];
		}
	}
	return self;
}
- (void)_fetchEvents:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[trackInfo retain];
	[_lock lock];
	[self performSelectorOnMainThread:@selector(showLoadingView) withObject:nil waitUntilDone:YES];
	[_attendingEvents release];
	_attendingEvents = [[NSMutableArray alloc] init];
	NSArray *attendingEvents = [[LastFMService sharedInstance] eventsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	for(NSDictionary *event in attendingEvents) {
		[_attendingEvents addObject:[event objectForKey:@"id"]];
	}
	[self performSelectorOnMainThread:@selector(_processEvents:) withObject:[[LastFMService sharedInstance] eventsForArtist:[trackInfo objectForKey:@"creator"]] waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(hideLoadingView) withObject:nil waitUntilDone:YES];
	[_lock unlock];
	[trackInfo release];
	[pool release];
}
- (NSString *)formatDate:(NSString *)input {
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"EEE, dd MMM yyyy"];
	NSDate *date = [formatter dateFromString:input];
	[formatter setLocale:[NSLocale currentLocale]];
	[formatter setDateStyle:NSDateFormatterShortStyle];

	NSString *output = [formatter stringFromDate:date];
	[formatter release];
	return output;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if([_eventDates count])
		return [_eventDates count];
	else
		return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if([_eventDates count])
		return [[[_eventDates objectAtIndex:section] objectForKey:@"count"] intValue];
	else
		return 1;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if([_eventDates count])
		return [[_eventDates objectAtIndex:section] objectForKey:@"date"];
	else
		return nil;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 78;
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
	[self.navigationController dismissModalViewControllerAnimated:YES];
	if(!_username)
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	int offset = 0;
	if([_eventDates count]) {
		offset = [[[_eventDates objectAtIndex:[newIndexPath section]] objectForKey:@"index"] intValue];
	}
	EventDetailViewController *e = [[EventDetailViewController alloc] initWithNibName:@"EventDetailsView" bundle:nil];
	e.event = [_events objectAtIndex:offset + [newIndexPath row]];
	//e.delegate = self;
	[self.navigationController presentModalViewController:e animated:YES];
	if([self isAttendingEvent:[e.event objectForKey:@"id"]]) {
		[e setAttendance:eventStatusAttending];
	} else {
		[e setAttendance:eventStatusNotAttending];
	}
	[e release];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([_eventDates count]) {
		int offset = [[[_eventDates objectAtIndex:[indexPath section]] objectForKey:@"index"] intValue];
		EventCell *cell = (EventCell *)[tableView dequeueReusableCellWithIdentifier:@"eventcell"];
		if(!cell)
			cell = [[[EventCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"eventcell"] autorelease];
		[cell setEvent:[_events objectAtIndex:offset+[indexPath row]]];
		return cell;
	} else {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"NoEventsCell"];
		if(!cell) {
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"NoEventsCell"] autorelease];
			UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0,0,320,70)];
			label.text = NSLocalizedString(@"No upcoming events", @"No events available");
			label.textAlignment = UITextAlignmentCenter;
			[cell.contentView addSubview: label];
			[label release];
		}
		return cell;
	}
}
- (void)dealloc {
	[_events release];
	[_eventDates release];
	[_attendingEvents release];
	[_username release];
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
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
	return 1;
}
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
	return 3;
}
- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
	switch(row) {
		case 0:
			return @"Not attending";
		case 1:
			return @"I might attend";
		case 2:
			return @"I will attend";
		default:
			return @"";
	}
}
@end

@implementation EventsViewController
- (void)viewDidLoad {
	_calendar = [[CalendarViewController alloc] initWithNibName:@"CalendarView" bundle:nil];
	_calendar.delegate = self;
	[self.view addSubview: _calendar.view];
	[self.view sendSubviewToBack: _calendar.view];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
	if(_badge) {
		_badge.image = [[UIImage imageNamed:@"events_red_circle.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	}
	_lock = [[NSLock alloc] init];
}
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
- (void)_fetchEvents:(NSDictionary *)trackInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[trackInfo retain];
	[_lock lock];
	[formatter setDateFormat:@"EEE, dd MMM yyyy"];
	[self performSelectorOnMainThread:@selector(showLoadingView) withObject:nil waitUntilDone:YES];
	[_events release];
	[_eventDates release];
	[_attendingEvents release];
	_attendingEvents = [[NSMutableArray alloc] init];
	NSArray *attendingEvents = [[LastFMService sharedInstance] eventsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	for(NSDictionary *event in attendingEvents) {
		[_attendingEvents addObject:[event objectForKey:@"id"]];
	}
	
	NSArray *events = [[LastFMService sharedInstance] eventsForArtist:[trackInfo objectForKey:@"creator"]];
	_events = [events retain];
	_eventDates = [[NSMutableArray alloc] init];
	
	if([_events count]) {
		NSDate *date, *lastDate = [formatter dateFromString:[[_events objectAtIndex:0] objectForKey:@"startDate"]];
		
		for(NSDictionary *event in _events) {
			date = [formatter dateFromString:[event objectForKey:@"startDate"]];
			if(![lastDate isEqualToDate:date]) {
				[_eventDates addObject:date];
				lastDate = date;
			}
		}
		[_eventDates addObject:lastDate];
		if(_badge) {
			_badge.alpha = 1;
			[[_badge subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
			CGRect frame = _badge.frame;
			frame.size.width = [[NSString stringWithFormat:@"%i", [_events count]] sizeWithFont:[UIFont boldSystemFontOfSize:12]].width + 20;
			_badge.frame = frame;
			UILabel *l = [[UILabel alloc] init];
			l.frame = CGRectMake(0,-2,frame.size.width,frame.size.height);
			l.text = [NSString stringWithFormat:@"%i", [_events count]];
			l.font = [UIFont boldSystemFontOfSize: 12];
			l.textAlignment = UITextAlignmentCenter;
			l.textColor = [UIColor whiteColor];
			l.backgroundColor = [UIColor clearColor];
			[_badge addSubview: l];
			[l release];
		}
	} else {
		if(_badge)
			_badge.alpha = 0;
	}
	[_calendar performSelectorOnMainThread:@selector(setEventDates:) withObject:_eventDates waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(hideLoadingView) withObject:nil waitUntilDone:YES];
	[_lock unlock];
	[trackInfo release];
	[pool release];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(_data)
		return [_data count];
	else
		return 0;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 42;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	EventDetailViewController *e = [[EventDetailViewController alloc] initWithNibName:@"EventDetailsView" bundle:nil];
	e.event = [_data objectAtIndex:[newIndexPath row]];
	e.delegate = self;
	[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)).tabBarController presentModalViewController:e animated:YES];
	if([self isAttendingEvent:[e.event objectForKey:@"id"]]) {
		[e setAttendance:eventStatusAttending];
	} else {
		[e setAttendance:eventStatusNotAttending];
	}
	[e release];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
}
- (void)calendarViewController:(CalendarViewController *)c didSelectDate:(NSDate *)d {
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"EEE, dd MMM yyyy"];
	[_data release];
	_data = [[NSMutableArray alloc] init];
	
	for(NSDictionary *event in _events) {
		if([[event objectForKey:@"startDate"] isEqualToString:[formatter stringFromDate:d]])
			[_data addObject:event];
	}
	if(![_data count]) {
		[_data release];
		_data = nil;
	}
	if([_data count] > 1) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.2];
		_calendar.view.frame = CGRectMake(0,0,320,328);
		_table.frame = CGRectMake(0,284,320,88);
		_shadow.frame = CGRectMake(0,284,320,18);
		[UIView commitAnimations];
	} else {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.2];
		_calendar.view.frame = CGRectMake(0,0,320,372);
		_table.frame = CGRectMake(0,372,320,0);
		_shadow.frame = CGRectMake(0,372,320,0);
		[UIView commitAnimations];
		if([_data count])
			[self tableView:_table didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	}
	[_table reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	EventCell *cell = (EventCell *)[tableView dequeueReusableCellWithIdentifier:@"eventcell"];
	if(!cell)
		cell = [[[EventCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"eventcell"] autorelease];
	[cell setEvent:[_data objectAtIndex:[indexPath row]]];
	return cell;
}
- (void)doneButtonPressed:(id)sender {
	EventDetailViewController *e = (EventDetailViewController *)sender;
	if([e attendance] == eventStatusNotAttending) {
		[_attendingEvents removeObject:[e.event objectForKey:@"id"]];
		/*if(_username) {
			NSMutableArray *events = [[NSMutableArray alloc] init];
			for(NSDictionary *event in _events) {
				if(![[event objectForKey:@"id"] isEqualToString:[e.event objectForKey:@"id"]])
					[events addObject:event];
			}
			[self _processEvents:events];
			[events release];
		}*/
	} else {
		[_attendingEvents addObject:[e.event objectForKey:@"id"]];
	}
	[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)).tabBarController dismissModalViewControllerAnimated:YES];
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
	
	artistBio.view.frame = CGRectMake(0,0,320,369);
	tags.view.frame = CGRectMake(0,0,320,369);
	similarArtists.view.frame = CGRectMake(0,0,320,369);
	fans.view.frame = CGRectMake(0,0,320,369);
	events.view.frame = CGRectMake(0,0,320,369);
	
	MPVolumeView *v = [[MPVolumeView alloc] initWithFrame:volumeView.frame];
	[volumeView removeFromSuperview];
	volumeView = v;
	[volumeView sizeToFit];
	[trackView.view addSubview: volumeView];
	self.hidesBottomBarWhenPushed = YES;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	_titleLabel.text = [[[LastFMRadio sharedInstance] station] capitalizedString];
}
- (void)_trackDidChange:(NSNotification *)notification {
	if([[detailView subviews] count])
		[self detailsButtonPressed:nil];
	_titleLabel.text = [[[LastFMRadio sharedInstance] station] capitalizedString];
	loveBtn.alpha = 1;
	banBtn.alpha = 1;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)backButtonPressed:(id)sender {
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hidePlaybackView];
}
- (void)detailsButtonPressed:(id)sender {
	if([[detailView subviews] count]) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.75];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:detailsBtnContainer cache:YES];
		[detailsBtn setBackgroundImage:[UIImage imageNamed:@"info_button.png"] forState:UIControlStateNormal];
		detailsBtn.frame = CGRectMake(0,0,30,30);
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
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.75];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:detailsBtnContainer cache:YES];
		[detailsBtn setBackgroundImage:trackView.artwork forState:UIControlStateNormal];
		detailsBtn.frame = CGRectMake(1,1,28,28);
		[detailsBtn superview].backgroundColor = [UIColor blackColor];
		[UIView commitAnimations];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.75];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:contentView cache:YES];
		[[contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
		[contentView addSubview: detailsViewContainer];
		detailsViewContainer.frame = CGRectMake(0,0,320,416);
		tabBar.selectedItem = [tabBar.items objectAtIndex:0];
		[self tabBar:tabBar didSelectItem:tabBar.selectedItem];
		//detailType.selectedSegmentIndex = 0;
		//[self detailTypeChanged:nil];
		[UIView commitAnimations];
	}
}
- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
	[[detailView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];

	/*[detailType setImage:[UIImage imageNamed:@"bio.png"] forSegmentAtIndex:0];
	[detailType setImage:[UIImage imageNamed:@"tags.png"] forSegmentAtIndex:1];
	[detailType setImage:[UIImage imageNamed:@"similar_artists.png"] forSegmentAtIndex:2];
	[detailType setImage:[UIImage imageNamed:@"events.png"] forSegmentAtIndex:3];
	[detailType setImage:[UIImage imageNamed:@"top_listeners.png"] forSegmentAtIndex:4];*/
	
	
	
	switch(item.tag) {
		case 0:
			[detailView addSubview:artistBio.view];
			_titleLabel.text = @"Artist Bio";
			//[detailType setImage:[UIImage imageNamed:@"bio_selected.png"] forSegmentAtIndex:0];
			break;
		case 1:
			[detailView addSubview:tags.view];
			_titleLabel.text = @"Tags";
			//[detailType setImage:[UIImage imageNamed:@"tags_selected.png"] forSegmentAtIndex:1];
			break;
		case 2:
			[detailView addSubview:similarArtists.view];
			_titleLabel.text = @"Similar Artists";
			//[detailType setImage:[UIImage imageNamed:@"similar_artists_selected.png"] forSegmentAtIndex:2];
			break;
		case 3:
			[detailView addSubview:events.view];
			_titleLabel.text = @"Events";
			//[detailType setImage:[UIImage imageNamed:@"events_selected.png"] forSegmentAtIndex:3];
			break;
		case 4:
			[detailView addSubview:fans.view];
			_titleLabel.text = @"Top Listeners";
			break;
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
		friends.title = @"Choose A Friend";
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

	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"Share"]) {
		UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Who would you like to share this track with?", @"Share sheet title")
																											 delegate:self
																							cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
																				 destructiveButtonTitle:nil
																							otherButtonTitles:NSLocalizedString(@"Contacts", @"Share to Address Book"), NSLocalizedString(@"Last.fm Friends", @"Share to Last.fm friend"), nil];
		[sheet showInView:self.view];
		[sheet release];	
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"Tag"]) {
		TagEditorViewController *t = [[TagEditorViewController alloc] initWithNibName:@"TagEditorView" bundle:nil];
		t.delegate = self;
		t.myTags = [[[LastFMService sharedInstance] tagsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] sortedArrayUsingFunction:tagSort context:nil];
		t.topTags = [[[LastFMService sharedInstance] topTagsForTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"]] sortedArrayUsingFunction:tagSort context:nil];
		[self presentModalViewController:t animated:YES];
		[t release];
	}
	
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"Buy on iTunes"])
		[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:[NSString stringWithFormat:@"itms://ax.phobos.apple.com.edgesuite.net/WebObjects/MZSearch.woa/wa/search?term=%@+%@", 
																																								[[trackInfo objectForKey:@"creator"] URLEscaped],
																																								[[trackInfo objectForKey:@"title"] URLEscaped]
																																								]]];
	
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
																						otherButtonTitles:@"Tag",
													@"Add to Playlist",
													@"Share",
													@"Buy on iTunes",
													nil];
	sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
	[sheet showInView:self.view];
	[sheet release];
}
-(void)tagEditorDidCancel {
	[self dismissModalViewControllerAnimated:YES];
}
-(void)tagEditorCommitTags:(NSArray *)t {
	[self dismissModalViewControllerAnimated:YES];
	NSDictionary *trackInfo = [[LastFMRadio sharedInstance] trackInfo];
	[[LastFMService sharedInstance] tagTrack:[trackInfo objectForKey:@"title"] byArtist:[trackInfo objectForKey:@"creator"] withTags:t];
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
