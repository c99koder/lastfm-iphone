/* TrackViewController.m - Display a track
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

#import "TrackViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import "ButtonsCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "UIApplication+openURLWithWarning.h"
#import "ShareActionSheet.h"
#import "UIColor+LastFMColors.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "FlurryAnalytics.h"
#endif

@implementation TrackViewController
- (id)initWithTrack:(NSString *)track byArtist:(NSString *)artist {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_artist = [artist retain];
		_track = [track retain];
		_loved = NO;
		_addedToLibrary = NO;
		self.title = track;
	}
	return self;
}
- (void)buy:(id)sender {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"buy" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"track", @"type", nil, nil]];
#endif
	NSString *ITMSURL = [NSString stringWithFormat:@"http://phobos.apple.com/WebObjects/MZSearch.woa/wa/search?term=%@ %@&s=143444&partnerId=2003&affToken=www.last.fm", 
						 _artist,
						 _track];
	NSString *URL;
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"country"] isEqualToString:@"United States"])
		URL = [NSString stringWithFormat:@"http://click.linksynergy.com/fs-bin/stat?id=bKEBG4*hrDs&offerid=78941&type=3&subid=0&tmpid=1826&RD_PARM1=%@", [[ITMSURL URLEscaped] stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"]];
	else
		URL = [NSString stringWithFormat:@"http://clk.tradedoubler.com/click?p=23761&a=1474288&url=%@&tduid=lastfm&partnerId=2003", [[ITMSURL URLEscaped] stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"]];
    
	[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString: URL]];
}
- (void)love:(id)sender {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"love" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"track", @"type", nil, nil]];
#endif
	[[LastFMService sharedInstance] loveTrack:_track byArtist:_artist];
	if([LastFMService sharedInstance].error) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
	} else {
		_loved = YES;
		((UIButton*)sender).enabled = NO;
	}	
}
- (void)addToLibrary:(id)sender {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"addToLibrary" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"track", @"type", nil, nil]];
#endif
	[[LastFMService sharedInstance] addTrackToLibrary:_track byArtist:_artist];
	if([LastFMService sharedInstance].error) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
	} else {
		_addedToLibrary = YES;
		((UIButton*)sender).enabled = NO;
	}
}
- (void)addTag:(id)sender {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"tag" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"track", @"type", nil, nil]];
#endif
	NSArray *topTags = [[[LastFMService sharedInstance] topTagsForTrack:_track byArtist:_artist] sortedArrayUsingFunction:tagSort context:nil];
	NSArray *userTags = [[[LastFMService sharedInstance] tagsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] sortedArrayUsingFunction:tagSort context:nil];
	TagEditorViewController *t = [[TagEditorViewController alloc] initWithTopTags:topTags userTags:userTags];
	t.delegate = self;
	[self presentModalViewController:t animated:YES];
	[t setTags: [[LastFMService sharedInstance] tagsForTrack:_track byArtist:_artist]];
	[t release];
}
- (void)share:(id)sender {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"share" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"track", @"type", nil, nil]];
#endif
	ShareActionSheet* action = [[ShareActionSheet alloc] initWithTrack:_track byArtist:_artist];
	action.viewController = self.tabBarController;
	[action showFromTabBar: self.tabBarController.tabBar];
	[action release];
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self rebuildMenu];
}
- (void)viewDidLoad {
	//self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	//self.tableView.sectionHeaderHeight = 0;
	//self.tableView.sectionFooterHeight = 0;
	self.tableView.backgroundColor = [UIColor lfmTableBackgroundColor];
	self.tableView.scrollsToTop = NO;
	_bioView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
	_tagsView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
	_metadata = [[[LastFMService sharedInstance] metadataForTrack:_track byArtist:_artist inLanguage:@"en"] retain];
	_tags = [[[LastFMService sharedInstance] topTagsForTrack:_track byArtist:_artist] retain];
}
- (void)viewDidUnload {
	[_tagsView release];
	_tagsView = nil;
	[_bioView release];
	_bioView = nil;
	[_tagsView release];
	_tagsView = nil;
	[_metadata release];
	_metadata = nil;
	[_tags release];
	_tags = nil;
	[_data release];
	_data = nil;
}
- (void)rebuildMenu {
	NSString *bio = [[_metadata objectForKey:@"wiki"] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"];
	//Fix Relative URL with a search replace hack:
	bio = [bio stringByReplacingOccurrencesOfString:@"href=\"/" withString:@"href=\"http://www.last.fm/"];
	
	//Handle some HTML entities, as Three20 can't parse them
	bio = [bio stringByReplacingOccurrencesOfString:@"&ndash;" withString:@"–"];
	bio = [bio stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
	NSString *html = [NSString stringWithFormat:@"%@ <a href=\"http://www.last.fm/music/%@/_/%@/+wiki\">Read More »</a>", bio, [_artist URLEscaped], [_track URLEscaped]];
	_bioView.html = html;
	
	if(_data) {
		[_data release];
		_data = nil;
	}
	
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	
	[sections addObject:@"heading"];
	
	if( [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_expired"] isEqualToString:@"0"])
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"",
																													 [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"Play %@ Radio", _artist], [NSString stringWithFormat:@"lastfm://artist/%@/similarartists", [_artist URLEscaped]], nil]
																																																								 forKeys:[NSArray arrayWithObjects:@"title", @"url", nil]], nil]
																													 , nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
	[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"",
															 [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"View Artist profile", _artist], [NSString stringWithFormat:@"lastfm-artist://%@", [_artist URLEscaped]], nil]
																												   forKeys:[NSArray arrayWithObjects:@"title", @"url", nil]], nil]
															 , nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
	
	if ( [_tags count] > 0 ) {
		[sections addObject:@"tags"];
		NSString *taghtml = @"";
		
		for(int i = 0; i < [_tags count] && i < 10; i++) {
			if(i < [_tags count]-1 && i < 9)
				taghtml = [taghtml stringByAppendingFormat:@"<a href='lastfm-tag://%@'>%@</a>, ", [[[_tags objectAtIndex: i] objectForKey:@"name"] URLEscaped], [[[_tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
			else
				taghtml = [taghtml stringByAppendingFormat:@"<a href='lastfm-tag://%@'>%@</a>", [[[_tags objectAtIndex: i] objectForKey:@"name"] URLEscaped], [[[_tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
		}
		
		_tagsView.html = taghtml;
		_tagsView.font = [UIFont systemFontOfSize:[UIFont labelFontSize]];
	}

	if([[_metadata objectForKey:@"wiki"] length])
		[sections addObject:@"bio"];

	[sections addObject:@"buy"];
	[sections addObject:@"buttons"];
	_data = sections;
	
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [_data count];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]])
		return [[[_data objectAtIndex:section] objectForKey:@"stations"] count];
	else
		return 1;
}
/*- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
 if([self tableView:tableView numberOfRowsInSection:section] > 1)
 return 10;
 else
 return 0;
 }*/
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]]) {
		return [((NSDictionary *)[_data objectAtIndex:section]) objectForKey:@"title"];
	}	else if([[_data objectAtIndex:section] isKindOfClass:[NSString class]] && [[_data objectAtIndex:section] isEqualToString:@"bio"]) {
		return @"About This Track";
	}	else if([[_data objectAtIndex:section] isKindOfClass:[NSString class]] && [[_data objectAtIndex:section] isEqualToString:@"tags"]) {
		return @"Popular Tags";
	} else {
		return nil;
	}
}
/*- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
 return [[[UIView alloc] init] autorelease];
 }*/
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([indexPath section] == 0)
		return 86;
	else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"bio"]) {
		_bioView.text.width = self.view.frame.size.width - 32;
		return _bioView.text.height + 16;
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"tags"]) {
		_tagsView.text.width = self.view.frame.size.width - 32;
		return _tagsView.text.height + 16;
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"buttons"]) {
		return 90;
	} else
		return 52;
}
-(void)tagEditorDidCancel {
	[self dismissModalViewControllerAnimated:YES];
}
- (void)tagEditorAddTags:(NSArray *)tags {
	[[LastFMService sharedInstance] addTags:tags toTrack:_track byArtist:_artist];
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	[self dismissModalViewControllerAnimated:YES];
}
- (void)tagEditorRemoveTags:(NSArray *)tags {
	for(NSString *tag in tags) {
		[[LastFMService sharedInstance] removeTag:tag fromTrack:_track byArtist:_artist];
		if([LastFMService sharedInstance].error)
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	}
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSString *station = [[[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] objectAtIndex:[indexPath row]] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
		[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:station]];
	}
	[self.tableView reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
	
	//don't show spinner in button cell or the info cell
	if([newIndexPath section] == 0 ||
	   ([[_data objectAtIndex:[newIndexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[newIndexPath section]] isEqualToString:@"buttons"])) 
		return;
	
	if( [[_data objectAtIndex:[newIndexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[newIndexPath section]] isEqualToString: @"buy"] ) {
		[self buy:nil];
		return;
	}
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.1];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *loadingCell = [tableView dequeueReusableCellWithIdentifier:@"LoadingCell"];
	if(!loadingCell) {
		loadingCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LoadingCell"] autorelease];
		loadingCell.textLabel.text = @"Loading";
	}
	ArtworkCell *cell = nil;
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[stations objectAtIndex:[indexPath row]] objectForKey:@"title"]];
		if (cell == nil) {
			cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[[stations objectAtIndex:[indexPath row]] objectForKey:@"title"]] autorelease];
		}
	}
	if(cell == nil)
		cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ArtworkCell"] autorelease];
	
	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if([indexPath section] == 1 && ([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_expired"] isEqualToString:@"0"])) {
		UITableViewCell *stationCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"StationCell"] autorelease];
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		stationCell.textLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		stationCell.imageView.image = [UIImage imageNamed:@"radiostarter.png"];
		return stationCell;
	}
	
	if([indexPath section] == 0) {
		ArtworkCell *profilecell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"ProfileCell"];
		if(profilecell == nil) {
			profilecell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ProfileCell"] autorelease];
			profilecell.contentView.frame = CGRectMake(0,0,111,111);
			profilecell.selectionStyle = UITableViewCellSelectionStyleNone;
			profilecell.shouldFillHeight = YES;
			profilecell.placeholder = @"noimage_album_large.png";
			profilecell.imageURL = [_metadata objectForKey:@"image"];
			profilecell.shouldCacheArtwork = YES;
			profilecell.backgroundView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
			profilecell.backgroundColor = [UIColor clearColor];
			profilecell.title.text = _artist;
			profilecell.title.backgroundColor = [UIColor clearColor];
			profilecell.subtitle.backgroundColor = [UIColor clearColor];
			profilecell.subtitle.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
			profilecell.subtitle.textColor = [UIColor blackColor];
			[profilecell addBorderWithColor: [UIColor colorWithRed:0.67f green:0.67f blue:0.67f alpha:1.0f]];
			
			NSString *duration = @"";
			int seconds = [[_metadata objectForKey:@"duration"] floatValue] / 1000.0f;
			if(seconds <= 0) {
				duration = @"00:00";
			} else {
				int h = seconds / 3600;
				int m = (seconds%3600) / 60;
				int s = seconds%60;
				if(h)
					duration = [NSString stringWithFormat:@"%02i:%02i:%02i", h, m, s];
				else
					duration = [NSString stringWithFormat:@"%02i:%02i", m, s];
			}
			
			NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
			[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
			NSString *plays = [NSString stringWithFormat:@"%@ plays in your library",[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[_metadata objectForKey:@"userplaycount"] intValue]]]];
			profilecell.subtitle.lineBreakMode = UILineBreakModeWordWrap;
			profilecell.subtitle.numberOfLines = 0;
			profilecell.subtitle.text = [NSString stringWithFormat:@"%@ (%@)\n\n%@", _track, duration, plays];
			[numberFormatter release];
		}
		[profilecell showProgress: NO];
		profilecell.accessoryType = UITableViewCellAccessoryNone;
		return profilecell;
	}
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell.title.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"]) {
			cell.subtitle.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"];
			cell.subtitle.lineBreakMode = UILineBreakModeWordWrap;
			cell.subtitle.numberOfLines = 0;
		}
		cell.shouldCacheArtwork = YES;
		if([[[stations objectAtIndex:[indexPath row]] objectForKey:@"image"] length]) {
			cell.imageURL = [[stations objectAtIndex:[indexPath row]] objectForKey:@"image"];
		} else {
			cell.noArtwork = YES;
		}
		cell.shouldFillHeight = YES;
		if([indexPath row] == 0)
			cell.shouldRoundTop = YES;
		else
			cell.shouldRoundTop = NO;
		if([indexPath row] == [self tableView:tableView numberOfRowsInSection:[indexPath section]]-1)
			cell.shouldRoundBottom = YES;
		else
			cell.shouldRoundBottom = NO;
	} else 	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"tags"]) {
		UITableViewCell *tagcell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"TagCell"];
		if(tagcell == nil) {
			tagcell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TagCell"] autorelease];
			tagcell.selectionStyle = UITableViewCellSelectionStyleNone;
			_tagsView.frame = CGRectMake(8,8,self.view.frame.size.width - 32, _tagsView.text.height);
			_tagsView.textColor = [UIColor blackColor];
			_tagsView.backgroundColor = [UIColor clearColor];
			
			[tagcell.contentView addSubview:_tagsView];
		}
		return tagcell;
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"bio"]) {
		UITableViewCell *biocell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"BioCell"];
		if(biocell == nil) {
			biocell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"BioCell"] autorelease];
			biocell.selectionStyle = UITableViewCellSelectionStyleNone;
			_bioView.frame = CGRectMake(8,8,self.view.frame.size.width - 32, _bioView.text.height);
			_bioView.backgroundColor = [UIColor clearColor];
			_bioView.textColor = [UIColor blackColor];
			[biocell.contentView addSubview:_bioView];
		}
		return biocell;
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"buy"]) {
		UITableViewCell *buycell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"BuyCell"];
		if( buycell == nil ) {
			buycell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"BuyCell"] autorelease];
			buycell.textLabel.text = @"Buy on iTunes";
			buycell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		return buycell;
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"buttons"]) {
		ButtonsCell *buttonscell = (ButtonsCell *)[tableView dequeueReusableCellWithIdentifier:@"ButtonsCell"];
		if(buttonscell == nil) {
			UIButton* love = [UIButton buttonWithType:UIButtonTypeRoundedRect];
			love.titleLabel.font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
			[love setTitle: @"Love" forState:UIControlStateNormal];
			[love setTitle: @"Loved" forState:UIControlStateDisabled];
			[love setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
			[love addTarget:self action:@selector(love:) forControlEvents:UIControlEventTouchUpInside];
			if( _loved ) {
				love.enabled = NO;
			}
			
			UIButton* addToLibrary = [UIButton buttonWithType:UIButtonTypeRoundedRect];
			addToLibrary.titleLabel.font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
			[addToLibrary setTitle: @"Add to Library" forState:UIControlStateNormal];
			[addToLibrary setTitle: @"Added to Library" forState:UIControlStateDisabled];
			[addToLibrary setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
			[addToLibrary addTarget:self action:@selector(addToLibrary:) forControlEvents:UIControlEventTouchUpInside];
			if( [[_metadata objectForKey:@"userplaycount"] intValue] > 0 ) {
				addToLibrary.enabled = NO;
			}
			
			UIButton* addTags = [UIButton buttonWithType:UIButtonTypeRoundedRect];
			addTags.titleLabel.font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
			[addTags setTitle: @"Add Tags" forState:UIControlStateNormal];
			[addTags addTarget:self action:@selector(addTag:) forControlEvents:UIControlEventTouchUpInside];
			
			UIButton* share = [UIButton buttonWithType:UIButtonTypeRoundedRect];
			share.titleLabel.font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
			[share setTitle: @"Share" forState:UIControlStateNormal];
			[share addTarget:self action:@selector(share:) forControlEvents:UIControlEventTouchUpInside];
			
			buttonscell = [[[ButtonsCell alloc] initWithReuseIdentifier:@"ButtonsCell" buttons:love, addToLibrary, addTags, share, nil] autorelease];
		}
		return buttonscell;	
	}

	if(cell.accessoryType == UITableViewCellAccessoryNone) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_tagsView release];
	[_tags release];
	[_artist release];
	[_track release];
	[_metadata release];
	[_bioView release];
	[_data release];
}
@end
