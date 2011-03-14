/* NowPlayingInfoViewController.m - Info about the currently-playing track
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

#import "LastFMService.h"
#import "ArtworkCell.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "NSString+URLEscaped.h"
#import "NowPlayingInfoViewController.h"
#import "MobileLastFMApplicationDelegate.h"
#import "UIApplication+openURLWithWarning.h"
#import "ShareActionSheet.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "FlurryAPI.h"
#endif

int tagSort(id tag1, id tag2, void *context);

@interface NowPlayingInfoStyleSheet : TTDefaultStyleSheet {
};
@end

@implementation NowPlayingInfoStyleSheet
-(UIColor *)textColor {
	return [UIColor grayColor];
}
-(UIColor *)linkTextColor {
	return [UIColor colorWithRed:(100.0/256.0) green:(172.0/256.0) blue:(245.0/256.0) alpha:1.0];
}
@end

@implementation NowPlayingInfoViewController
- (void)_loadInfo {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *trackData = [[LastFMService sharedInstance] metadataForTrack:[_trackInfo objectForKey:@"title"] byArtist:[_trackInfo objectForKey:@"creator"] inLanguage:@"en"];
	NSDictionary *artistData = [[LastFMService sharedInstance] metadataForArtist:[_trackInfo objectForKey:@"creator"] inLanguage:@"en"];
	NSArray *tags = [[LastFMService sharedInstance] topTagsForTrack:[_trackInfo objectForKey:@"title"] byArtist:[_trackInfo objectForKey:@"creator"]];
	NSArray *usertags = [[LastFMService sharedInstance] tagsForTrack:[_trackInfo objectForKey:@"title"] byArtist:[_trackInfo objectForKey:@"creator"]];
	NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];

	_artistImageURL = [[artistData objectForKey:@"image"] retain];
	
	_trackStatsView.html = [NSString stringWithFormat:@"%@ Scrobbles<br>(%@ Listeners)<br><b>%@ plays in your library</b>",
													[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[trackData objectForKey:@"playcount"] intValue]]],
													[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[trackData objectForKey:@"listeners"] intValue]]],
													[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[trackData objectForKey:@"userplaycount"] intValue]]]];
	
	_artistStatsView.html = [NSString stringWithFormat:@"%@ Scrobbles<br>(%@ Listeners)<br><b>%@ plays in your library</b>",
													[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[artistData objectForKey:@"playcount"] intValue]]],
													[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[artistData objectForKey:@"listeners"] intValue]]],
													[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[artistData objectForKey:@"userplaycount"] intValue]]]];
	
	NSString *taghtml = @"";

	if([tags count]) {
		taghtml = [taghtml stringByAppendingString:@"Popular: "];

		for(int i = 0; i < [tags count] && i < 5; i++) {
			if(i < [tags count]-1 && i < 4)
				taghtml = [taghtml stringByAppendingFormat:@"%@, ", [[[tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
			else
				taghtml = [taghtml stringByAppendingFormat:@"%@", [[[tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
		}
	}
	
	if([usertags count]) {
		taghtml = [taghtml stringByAppendingString:@"<br><b>Yours: "];

		for(int i = 0; i < [usertags count] && i < 5; i++) {
			if(i < [usertags count]-1 && i < 4)
				taghtml = [taghtml stringByAppendingFormat:@"%@, ", [[[usertags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
			else
				taghtml = [taghtml stringByAppendingFormat:@"%@", [[[usertags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
		}

		taghtml = [taghtml stringByAppendingString:@"</b>"];
	}
	
	_trackTagsView.html = taghtml;
	
	NSString *bio = [[artistData objectForKey:@"bio"] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"];
	//Fix Relative URL with a search replace hack:
	bio = [bio stringByReplacingOccurrencesOfString:@"href=\"/" withString:@"href=\"http://www.last.fm/"];
	
	//Handle some HTML entities, as Three20 can't parse them
	bio = [bio stringByReplacingOccurrencesOfString:@"&ndash;" withString:@"–"];
	bio = [bio stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
	_artistBioView.html=bio;
	_loaded = YES;
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
	[self performSelectorOnMainThread:@selector(loadContentForCells:) withObject:[self.tableView visibleCells] waitUntilDone:YES];
	[numberFormatter release];
	self.title = @"Now Playing Info";
	[pool release];
}
- (id)initWithTrackInfo:(NSDictionary *)trackInfo {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_trackInfo = [trackInfo retain];
		self.title = @"Now Playing Info";
		_trackStatsView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
		_trackStatsView.backgroundColor = [UIColor blackColor];
		_trackStatsView.font = [UIFont systemFontOfSize:14];
		_artistStatsView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
		_artistStatsView.backgroundColor = [UIColor blackColor];
		_artistStatsView.font = [UIFont systemFontOfSize:14];
		_trackTagsView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
		_trackTagsView.backgroundColor = [UIColor blackColor];
		_trackTagsView.font = [UIFont systemFontOfSize:14];
		_artistBioView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
		_artistBioView.backgroundColor = [UIColor blackColor];
		_artistBioView.font = [UIFont systemFontOfSize:14];
		UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 61, 31)];
		if([LastFMRadio sharedInstance].state == TRACK_PAUSED)
			[btn setBackgroundImage:[UIImage imageNamed:@"nowpaused_back.png"] forState:UIControlStateNormal];
		else
			[btn setBackgroundImage:[UIImage imageNamed:@"nowplaying_back.png"] forState:UIControlStateNormal];
		btn.adjustsImageWhenHighlighted = YES;
		[btn addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
		UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView: btn];
		self.navigationItem.leftBarButtonItem = item;
		self.toolbarItems = [NSArray arrayWithObjects:
												 [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"toolbar_refresh.png"] style:UIBarButtonItemStylePlain target:self action:@selector(refreshButtonPressed)] autorelease],
												 [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
												 [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"toolbar_buy.png"] style:UIBarButtonItemStylePlain target:self action:@selector(buyButtonPressed)] autorelease],
												 [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
												 [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"toolbar_share.png"] style:UIBarButtonItemStylePlain target:self action:@selector(shareButtonPressed)] autorelease],
												 [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease],
												 [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"toolbar_tag.png"] style:UIBarButtonItemStylePlain target:self action:@selector(tagButtonPressed)] autorelease],nil];
		((UIBarButtonItem *)[self.toolbarItems objectAtIndex:1]).enabled = NO;
		[item release];
		[btn release];
		_loaded = NO;
	}
	return self;
}
- (void)_trackDidChange:(NSNotification *)notification {
	self.title = @"Recently Played Info";
	((UIBarButtonItem *)[self.toolbarItems objectAtIndex:1]).enabled = YES;
}
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.navigationController setToolbarHidden:YES];
	self.navigationController.toolbar.barStyle = UIBarStyleDefault;
	[TTStyleSheet setGlobalStyleSheet:[[[TTDefaultStyleSheet alloc] init] autorelease]];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:kTrackDidChange object:nil];
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:NO];
	self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	[self.navigationController setToolbarHidden:NO];
	self.navigationController.toolbar.barStyle = UIBarStyleBlackOpaque;
	self.tableView.backgroundColor = [UIColor blackColor];
	[self.tableView reloadData];
	self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	[self loadContentForCells:[self.tableView visibleCells]];
	[NSThread detachNewThreadSelector:@selector(_loadInfo) toTarget:self withObject:nil];
	[TTStyleSheet setGlobalStyleSheet:[[[NowPlayingInfoStyleSheet alloc] init] autorelease]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_trackDidChange:) name:kTrackDidChange object:nil];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	switch([indexPath section]) {
		case 0:
			return 90;
		case 1:
			if(_loaded) {
				_trackStatsView.text.width = 210;
				return _trackStatsView.text.height;
			} else {
				return 90;
			}
		case 2:
			_artistStatsView.text.width = 210;
			return _artistStatsView.text.height;
		case 3:
			_trackTagsView.text.width = 210;
			return _trackTagsView.text.height;
		case 4:
			_artistBioView.text.width = 210;
			return _artistBioView.text.height;
		default:
			return 52;
	}
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if(!_loaded)
		return 2;
	else
		return 5;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"InfoCell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"InfoCell"] autorelease];
	}
	[cell showProgress:NO];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
	if([indexPath section] == 0) {
		ArtworkCell *profilecell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"ProfileCell"];
		if(profilecell == nil) {
			profilecell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:@"ProfileCell"] autorelease];
			profilecell.contentView.frame = CGRectMake(0,0,89,89);
			profilecell.backgroundView = [[[UIView alloc] init] autorelease];
			profilecell.selectionStyle = UITableViewCellSelectionStyleNone;
			[profilecell addReflection:@"reflectionmask.png"];
			profilecell.placeholder = @"noimage_artist.png";
			profilecell.shouldCacheArtwork = YES;
			profilecell.shouldFillHeight = YES;
			profilecell.title.font = [UIFont boldSystemFontOfSize:16];
			profilecell.title.textColor = [UIColor whiteColor];
			profilecell.title.backgroundColor = [UIColor blackColor];
			profilecell.subtitle.font = [UIFont boldSystemFontOfSize:16];
			profilecell.subtitle.textColor = [UIColor whiteColor];
			profilecell.subtitle.backgroundColor = [UIColor blackColor];
			profilecell.detailTextLabel.font = [UIFont systemFontOfSize:14];
			profilecell.detailTextLabel.textColor = [UIColor whiteColor];
			profilecell.detailTextLabel.backgroundColor = [UIColor blackColor];
			profilecell.accessoryType = UITableViewCellAccessoryNone;
		}
		profilecell.title.text = [_trackInfo objectForKey:@"creator"];
		profilecell.subtitle.text = [_trackInfo objectForKey:@"title"];
		profilecell.detailTextLabel.text = [_trackInfo objectForKey:@"album"];
			
		if(_loaded)
			profilecell.imageURL = _artistImageURL;

		return profilecell;
	}
	
	if(_loaded) {
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		UILabel *titleLabel = [[[UILabel alloc] initWithFrame:CGRectMake(0,0,self.view.frame.size.width - 220 - 20,14)] autorelease];
		titleLabel.font = [UIFont boldSystemFontOfSize: 14];
		titleLabel.textColor = [UIColor whiteColor];
		titleLabel.backgroundColor = [UIColor blackColor];
		titleLabel.textAlignment = UITextAlignmentRight;
		cell.detailTextLabel.backgroundColor = [UIColor blackColor];
		[[cell.contentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
		[cell.contentView addSubview: titleLabel];
		
		switch([indexPath section]) {
			case 1:
				titleLabel.text = @"Track Stats";
				_trackStatsView.frame = CGRectMake(self.view.frame.size.width - 210 - 20,0,_trackStatsView.text.width,_trackStatsView.text.height);
				[cell.contentView addSubview: _trackStatsView];
				break;
			case 2:
				titleLabel.text = @"Artist Stats";
				_artistStatsView.frame = CGRectMake(self.view.frame.size.width - 210 - 20,0,_artistStatsView.text.width,_artistStatsView.text.height);
				[cell.contentView addSubview: _artistStatsView];
				break;
			case 3:
				titleLabel.text = @"Track Tags";
				_trackTagsView.frame = CGRectMake(self.view.frame.size.width - 210 - 20,0,_trackTagsView.text.width,_trackTagsView.text.height);
				[cell.contentView addSubview: _trackTagsView];
				break;
			case 4:
				titleLabel.text = @"Artist Bio";
				_artistBioView.frame = CGRectMake(self.view.frame.size.width - 210 - 20,0,_artistBioView.text.width,_artistBioView.text.height);
				[cell.contentView addSubview: _artistBioView];
				break;
		}
	} else {
		UITableViewCell *loadingcell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LoadingCell"] autorelease];
		loadingcell.backgroundView = [[[UIView alloc] init] autorelease];
		loadingcell.backgroundColor = [UIColor blackColor];
		loadingcell.textLabel.text = @"\n\n\nLoading";
		loadingcell.textLabel.numberOfLines = 0;
		loadingcell.textLabel.textAlignment = UITextAlignmentCenter;
		loadingcell.textLabel.textColor = [UIColor whiteColor];
		UIActivityIndicatorView *progress = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		[progress startAnimating];
		CGRect frame = progress.frame;
		frame.origin.y = 20;
		frame.origin.x = 130;
		progress.frame = frame;
		[loadingcell.contentView addSubview: progress];
		[progress release];
		return loadingcell;
	}
	
  return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
}
-(void)tagEditorDidCancel {
	[self.navigationController dismissModalViewControllerAnimated:YES];
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
- (void)tagButtonPressed {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAPI logEvent:@"tag" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"track", @"type", nil, nil]];
#endif
	NSArray *topTags = [[[LastFMService sharedInstance] topTagsForTrack:[_trackInfo objectForKey:@"title"] byArtist:[_trackInfo objectForKey:@"creator"]] sortedArrayUsingFunction:tagSort context:nil];
	NSArray *userTags = [[[LastFMService sharedInstance] tagsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] sortedArrayUsingFunction:tagSort context:nil];
	TagEditorViewController *t = [[TagEditorViewController alloc] initWithTopTags:topTags userTags:userTags];
	t.delegate = self;
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
	[self presentModalViewController:t animated:YES];
	[t setTags: [[LastFMService sharedInstance] tagsForTrack:[_trackInfo objectForKey:@"title"] byArtist:[_trackInfo objectForKey:@"creator"]]];
	[t release];
}
- (void)buyButtonPressed {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAPI logEvent:@"buy" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"track", @"type", nil, nil]];
#endif
	NSString *ITMSURL = [NSString stringWithFormat:@"http://phobos.apple.com/WebObjects/MZSearch.woa/wa/search?term=%@ %@&s=143444&partnerId=2003&affToken=www.last.fm", 
											 [_trackInfo objectForKey:@"creator"],
											 [_trackInfo objectForKey:@"title"]];
	NSString *URL;
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"country"] isEqualToString:@"United States"])
		URL = [NSString stringWithFormat:@"http://click.linksynergy.com/fs-bin/stat?id=bKEBG4*hrDs&offerid=78941&type=3&subid=0&tmpid=1826&RD_PARM1=%@", [[ITMSURL URLEscaped] stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"]];
	else
		URL = [NSString stringWithFormat:@"http://clk.tradedoubler.com/click?p=23761&a=1474288&url=%@&tduid=lastfm&partnerId=2003", [[ITMSURL URLEscaped] stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"]];
	
	[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:URL]];
}
- (void)shareButtonPressed {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAPI logEvent:@"share" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"track", @"type", nil, nil]];
#endif
	ShareActionSheet *sheet = [[ShareActionSheet alloc]initWithTrack:[_trackInfo objectForKey:@"title"] byArtist:[_trackInfo objectForKey:@"creator"]];
	sheet.viewController = self;
	[sheet showFromTabBar:self.tabBarController.tabBar];
	[sheet release];
}
-(void)refreshButtonPressed {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAPI logEvent:@"nowplayinginfo-refresh"];
#endif
	_loaded = NO;
	[_trackInfo release];
	_trackInfo = [[[LastFMRadio sharedInstance] trackInfo] retain];
	[NSThread detachNewThreadSelector:@selector(_loadInfo) toTarget:self withObject:nil];
	((UIBarButtonItem *)[self.toolbarItems objectAtIndex:1]).enabled = NO;
	[self.tableView reloadData];
}
- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
	[super didReceiveMemoryWarning];
	
	// Relinquish ownership any cached data, images, etc. that aren't in use.
}
- (void)viewDidUnload {
	// Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
	// For example: self.myOutlet = nil;
}
- (void)dealloc {
	[_trackInfo release];
	[_artistImageURL release];
	[_trackStatsView release];
	[_artistStatsView release];
	[_trackTagsView release];
	[_artistBioView release];
  [super dealloc];
}
@end

