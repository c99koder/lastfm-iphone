/* PlaybackViewController.m - Display currently-playing song details
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

#import "DetailsViewController.h"
#import "MobileLastFMApplicationDelegate.h"
#import "UITableViewCell+ProgressIndicator.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "UIViewController+NowPlayingButton.h"
#import "UIApplication+openURLWithWarning.h"
#import "NSString+MD5.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "Beacon.h"
#endif

@implementation SimilarArtistsViewController
- (void)viewDidLoad {
	[super viewDidLoad];
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
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
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
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
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
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

@implementation ArtistBioView
- (void)viewDidLoad {
	[super viewDidLoad];
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
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
#if !(TARGET_IPHONE_SIMULATOR)
	[[Beacon shared] startSubBeaconWithName:@"eventdetails" timeSession:YES];
#endif
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
#if !(TARGET_IPHONE_SIMULATOR)
	[[Beacon shared] endSubBeaconWithName:@"eventdetails"];
#endif
}
- (IBAction)mapsButtonPressed:(id)sender {
	NSMutableString *query =[[NSMutableString alloc] init];
	if([[event objectForKey:@"venue"] length]) {
		[query appendFormat:@"%@,", [event objectForKey:@"venue"]];
	}
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
#if !(TARGET_IPHONE_SIMULATOR)
	[[Beacon shared] startSubBeaconWithName:@"map" timeSession:NO];
	[[Beacon shared] endSubBeaconWithName:@"eventdetails"];
#endif
	[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:[NSString stringWithFormat:@"http://maps.google.com/?f=q&q=%@&ie=UTF8&om=1&iwloc=addr", [query URLEscaped]]]];
	[query release];
}
@end

@implementation EventsViewController
- (void)_trackDidChange:(NSNotification*)notification {
	//[NSThread detachNewThreadSelector:@selector(_fetchEvents:) toTarget:self withObject:[notification userInfo]];
}
- (int)isAttendingEvent:(NSString *)event_id {
	for(NSDictionary *event in _attendingEvents) {
		if([[event objectForKey:@"id"] isEqualToString:event_id]) {
			return [[event objectForKey:@"status"] intValue];
		}
	}
	return eventStatusNotAttending;
}
- (void)viewTypeToggled:(id)sender {
	switch([(UISegmentedControl *)sender selectedSegmentIndex]) {
		case 1:
			if(_username)
				_table.frame = CGRectMake(0,0,320,372);
			else
				_table.frame = CGRectMake(0,0,320,326);
			_shadow.frame = CGRectMake(0,372,320,0);
			[_data release];
			_data = nil;
			[_table reloadData];
			break;
		case 0:
			_table.frame = CGRectMake(0,372,320,0);
			_shadow.frame = CGRectMake(0,372,320,0);
			break;
	}
}
- (NSString *)stripTime:(NSString *)date {
	NSRange range = [date rangeOfString:@":"];
	
	if(range.location != NSNotFound) {
		return [date substringToIndex:range.location - 3];
	} else {
		return date;
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
		NSDate *date, *lastDate = [formatter dateFromString:[self stripTime:[[_events objectAtIndex:0] objectForKey:@"startDate"]]];
		
		for(NSDictionary *event in _events) {
			date = [formatter dateFromString:[self stripTime:[event objectForKey:@"startDate"]]];
			
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
		segment.selectedSegmentIndex = 0;
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
		_attendingEvents = [[NSMutableArray alloc] initWithArray:events];
		if(_events) {
			events = _events;
			_events = nil;
		} else {
			events = [[LastFMService sharedInstance] eventsForUser:_username];
		}
		
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
- (id)initWithUsername:(NSString *)user withEvents:(NSArray *)events {
	if(self = [super init]) {
		self.title = [NSString stringWithFormat:NSLocalizedString(@"%@'s Events", @"User events title"), user];
		_username = [user retain];
		_events = [events retain];
	}
	return self;
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
			[_attendingEvents addObject:event];
		}
		
		NSArray *events = [[LastFMService sharedInstance] eventsForArtist:[trackInfo objectForKey:@"creator"]];
		[self _processEvents:events];
		
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
		[e setAttendance:[self isAttendingEvent:[e.event objectForKey:@"id"]]];
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
	[formatter release];
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
	for(NSDictionary *event in _attendingEvents) {
		if([[event objectForKey:@"id"] isEqualToString:[e.event objectForKey:@"id"]]) {
			[_attendingEvents removeObject:event];
			break;
		}
	}
	if([e attendance] == eventStatusNotAttending) {
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
		[_attendingEvents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[e.event objectForKey:@"id"], @"id", 
																 [NSNumber numberWithInt:[e attendance]], @"status", nil]];
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

@implementation DetailsViewController

- (void)viewDidLoad {
  [super viewDidLoad];
	artistBio.view.frame = CGRectMake(0,0,320,369);
	tags.view.frame = CGRectMake(0,0,320,369);
	similarArtists.view.frame = CGRectMake(0,0,320,369);
	fans.view.frame = CGRectMake(0,0,320,369);
	events.view.frame = CGRectMake(0,0,320,369);
}

- (void)viewWillAppear:(BOOL)animated {
	tabBar.selectedItem = [tabBar.items objectAtIndex:0];
	[self tabBar:tabBar didSelectItem:tabBar.selectedItem];
	NSDictionary *trackInfo = [[LastFMRadio sharedInstance] trackInfo];
	[NSThread detachNewThreadSelector:@selector(_fetchBio:) toTarget:artistBio withObject:trackInfo];
	[NSThread detachNewThreadSelector:@selector(_fetchTags:) toTarget:tags withObject:trackInfo];
	[NSThread detachNewThreadSelector:@selector(_fetchSimilarArtists:) toTarget:similarArtists withObject:trackInfo];
	[NSThread detachNewThreadSelector:@selector(_fetchFans:) toTarget:fans withObject:trackInfo];
	[NSThread detachNewThreadSelector:@selector(_fetchEvents:) toTarget:events withObject:trackInfo];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

-(void)setTitleLabelView:(UILabel *)label {
	_titleLabel = label;
}
- (void)jumpToEventsTab {
	tabBar.selectedItem = [tabBar.items objectAtIndex: 3];
	[self tabBar:tabBar didSelectItem: tabBar.selectedItem];
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
}

- (void)dealloc {
    [super dealloc];
}
@end
