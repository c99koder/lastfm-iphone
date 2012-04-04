/* ArtistViewController.m - Display an artist
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

#import "ArtistViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import "ButtonsCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "UIApplication+openURLWithWarning.h"
#import "EventsTabViewController.h"
#import "EventDetailsViewController.h"
#import "ShareActionSheet.h"
#import "TagEditorViewController.h"
#import "UIColor+LastFMColors.h"
#import <Three20UI/TTPickerViewCell.h>
#if !(TARGET_IPHONE_SIMULATOR)
#import "FlurryAnalytics.h"
#endif

@implementation ArtistViewController
- (void)paintItBlack {
	_paintItBlack = YES;
}
- (void)_loadEventsTab {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_events = [[[LastFMService sharedInstance] eventsForArtist:_artist] retain];
	_eventsTabLoaded = YES;
	[self performSelectorOnMainThread:@selector(rebuildMenu) withObject:nil waitUntilDone:YES];
	[pool release];
}
- (void)_loadInfoTab {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_tags = [[[LastFMService sharedInstance] topTagsForArtist:_artist] retain];
	_metadata = [[[LastFMService sharedInstance] metadataForArtist:_artist inLanguage:@"en"] retain];
	_albums = [[[LastFMService sharedInstance] topAlbumsForArtist:_artist] retain];
	_tracks = [[[LastFMService sharedInstance] topTracksForArtist:_artist] retain];
	_infoTabLoaded = YES;
	[self performSelectorOnMainThread:@selector(rebuildMenu) withObject:nil waitUntilDone:YES];
	[pool release];
}
- (void)_loadSimilarTab {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_similarArtists = [[[LastFMService sharedInstance] artistsSimilarTo:_artist] retain];
	_similarTabLoaded = YES;
	[self performSelectorOnMainThread:@selector(rebuildMenu) withObject:nil waitUntilDone:YES];
	[pool release];
}
- (id)initWithArtist:(NSString *)artist {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_artist = [artist retain];
		_infoTabLoaded = NO;
		_similarTabLoaded = NO;
		_eventsTabLoaded = NO;
		self.title = artist;
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if(_paintItBlack) {
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:NO];
		self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
		UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 61, 31)];
		[btn setBackgroundImage:[UIImage imageNamed:@"nowplaying_back.png"] forState:UIControlStateNormal];
		btn.adjustsImageWhenHighlighted = YES;
		[btn addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
		UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView: btn];
		self.navigationItem.leftBarButtonItem = item;
		[btn release];
		[item release];
		self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	} else {
		[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	}
	[self rebuildMenu];
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
- (void)viewDidLoad {
	if(_paintItBlack) {
		self.tableView.backgroundColor = [UIColor blackColor];
	} else {
		self.tableView.backgroundColor = [UIColor lfmTableBackgroundColor];
		_toggle = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Info", @"Events", @"Similar Artists", nil]];
		_toggle.segmentedControlStyle = UISegmentedControlStyleBar;
		_toggle.selectedSegmentIndex = 0;
		_toggle.frame = CGRectMake(6,6,self.view.frame.size.width - 12, _toggle.frame.size.height);
		[_toggle addTarget:self
								action:@selector(rebuildMenu)
			forControlEvents:UIControlEventValueChanged];
		
		UINavigationBar *toggleContainer = [[UINavigationBar alloc] initWithFrame:CGRectMake(0,0,self.view.frame.size.width,_toggle.frame.size.height + 12)];
		[toggleContainer addSubview: _toggle];
		self.tableView.tableHeaderView = toggleContainer;
		[toggleContainer release];
	}
	self.tableView.scrollsToTop = NO;
	
	_bioView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
	_tagsView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
	[NSThread detachNewThreadSelector:@selector(_loadInfoTab) toTarget:self withObject:nil];
	[NSThread detachNewThreadSelector:@selector(_loadSimilarTab) toTarget:self withObject:nil];
	[NSThread detachNewThreadSelector:@selector(_loadEventsTab) toTarget:self withObject:nil];
}
- (void)viewDidUnload {
	[super viewDidUnload];
	[_tagsView release];
	_tagsView = nil;
	[_tracks release];
	_tracks = nil;
	[_albums release];
	_albums = nil;
	[_events release];
	_events = nil;
	[_tags release];
	_tags = nil;
	[_metadata release];
	_metadata = nil;
	[_toggle release];
	_toggle = nil;
	[_similarArtists release];
	_similarArtists = nil;
	[_bioView release];
	_bioView = nil;
	[_data release];
	_data = nil;
	_infoTabLoaded = NO;
	_eventsTabLoaded = NO;
	_similarTabLoaded = NO;
}
- (void)rebuildMenu {
	NSString *bio = [[_metadata objectForKey:@"summary"] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"];

	//Fix Relative URL with a search replace hack:
	bio = [bio stringByReplacingOccurrencesOfString:@"href=\"/" withString:@"href=\"http://www.last.fm/"];
	
	//Handle some HTML entities, as Three20 can't parse them
	bio = [bio stringByReplacingOccurrencesOfString:@"&ndash;" withString:@"–"];
	bio = [bio stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
	NSString *html = [NSString stringWithFormat:@"%@ <a href=\"http://www.last.fm/music/%@/+wiki\">Read More »</a>", bio, [_artist URLEscaped]];
	_bioView.html = html;
	
	if(_data) {
		[_data release];
        _data = nil;
    }
	
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	NSMutableArray *stations;

	if(_toggle.selectedSegmentIndex == 0) {
		if(!_infoTabLoaded) {
			[sections addObject:@"Loading"];
		} else {
			[sections addObject:@"profile"];
			
			if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_expired"] isEqualToString:@"0"])
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"",
																															 [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%@ Radio", _artist], [NSString stringWithFormat:@"lastfm://artist/%@/similarartists", [_artist URLEscaped]], nil]
																																																										 forKeys:[NSArray arrayWithObjects:@"title", @"url", nil]], nil]
																															 , nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];

			if ( [_tags count ] > 0 ) {
				[sections addObject:@"tags"];
				NSString *taghtml = @"";
				
				for(int i = 0; i < [_tags count] && i < 10; i++) {
					if(_paintItBlack) {
						if(i < [_tags count]-1 && i < 9)
							taghtml = [taghtml stringByAppendingFormat:@"%@, ", [[[_tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
						else
							taghtml = [taghtml stringByAppendingFormat:@"%@", [[[_tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
					} else {
						if(i < [_tags count]-1 && i < 9)
							taghtml = [taghtml stringByAppendingFormat:@"<a href='lastfm-tag://%@'>%@</a>, ", [[[_tags objectAtIndex: i] objectForKey:@"name"] URLEscaped], [[[_tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
						else
							taghtml = [taghtml stringByAppendingFormat:@"<a href='lastfm-tag://%@'>%@</a>", [[[_tags objectAtIndex: i] objectForKey:@"name"] URLEscaped], [[[_tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
					}
				}
				
				_tagsView.html = taghtml;
				_tagsView.font = [UIFont systemFontOfSize:[UIFont labelFontSize]];
			}
			
			if([[_metadata objectForKey:@"summary"] length])
				[sections addObject:@"bio"];
			
			if([_tracks count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_tracks count] && x < 5; x++) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_tracks objectAtIndex:x] objectForKey:@"name"],
																																	 [NSString stringWithFormat:@"lastfm-track://%@/%@", [_artist URLEscaped], [[[_tracks objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
				}
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Top Tracks", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			}
			
			if([_albums count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_albums count] && x < 5; x++) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_albums objectAtIndex:x] objectForKey:@"name"], [[_albums objectAtIndex:x] objectForKey:@"image"], @"noimage_album.png",
																																	 [NSString stringWithFormat:@"lastfm-album://%@/%@", [_artist URLEscaped], [[[_albums objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"placeholder", @"url",nil]]];
				}
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Top Albums", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			}
			
			[sections addObject:@"buttons"];
		}
	} else if(_toggle.selectedSegmentIndex == 2) {
		if(!_similarTabLoaded) {
			[sections addObject:@"Loading"];
		} else {
			if([_similarArtists count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_similarArtists count] && x < 20; x++) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_similarArtists objectAtIndex:x] objectForKey:@"name"], [[_similarArtists objectAtIndex:x] objectForKey:@"image"], @"noimage_artist.png",
																																	 [NSString stringWithFormat:@"lastfm-artist://%@", [[[_similarArtists objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"placeholder", @"url",nil]]];
				}
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			}
		}
	}
	_data = sections;
	
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
#define SectionHeaderHeight 40


- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if ([[self tableView:tableView titleForHeaderInSection:section] length]) {
		return SectionHeaderHeight;
	}
	else {
		// If no section header title, no section header needed
		return 0;
	}
}


- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *sectionTitle = [self tableView:tableView titleForHeaderInSection:section];
	if (![sectionTitle length]) {
		return nil;
	}
	
	// Create label with section title
	UILabel *label = [[[UILabel alloc] init] autorelease];
	label.frame = CGRectMake(20, 6, 300, 30);
	label.backgroundColor = [UIColor clearColor];
	if(_paintItBlack) {
		label.textColor = [UIColor whiteColor];
	} else {
		label.textColor = [UIColor colorWithRed:(76.0f / 255.0f) green:(86.0f / 255.0f) blue:(108.0f / 255.0f) alpha:1.0];
		label.shadowColor = [UIColor whiteColor];
		label.shadowOffset = CGSizeMake(0.0, 1.0);
	}
	label.font = [UIFont boldSystemFontOfSize:16];
	label.text = sectionTitle;
	
	// Create header view and add label as a subview
	UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, SectionHeaderHeight)];
	[view autorelease];
	[view addSubview:label];
	
	return view;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if(_toggle.selectedSegmentIndex == 1 || _paintItBlack)
		return 1;
	else
		return [_data count];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(_toggle.selectedSegmentIndex == 1 || _paintItBlack)
		return (_eventsTabLoaded&&[_events count])?[_events count]:1;
	else if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]])
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
	if(_toggle.selectedSegmentIndex == 1 || _paintItBlack)
		return [NSString stringWithFormat:@"Upcoming performances", _artist];
	else if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]])
		return [((NSDictionary *)[_data objectAtIndex:section]) objectForKey:@"title"];
	else if([[_data objectAtIndex:section] isKindOfClass:[NSString class]] && [[_data objectAtIndex:section] isEqualToString:@"tags"])
		return @"Popular Tags";
	else if([[_data objectAtIndex:section] isKindOfClass:[NSString class]] && [[_data objectAtIndex:section] isEqualToString:@"bio"])
		return @"Biography";
	else
		return nil;
}
/*- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
 return [[[UIView alloc] init] autorelease];
 }*/
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(_toggle.selectedSegmentIndex == 0 && [indexPath section] == 0 && !_paintItBlack)
		return 86;
	else if((_toggle.selectedSegmentIndex == 1 || _paintItBlack) && [_events count]) {
		return 64;
	} else if(_toggle.selectedSegmentIndex == 0 && [[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"bio"]) {
		_bioView.text.width = self.view.frame.size.width - 32;
		return _bioView.text.height + 16;
	} else if(_toggle.selectedSegmentIndex == 0 && [[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"buttons"]) {
		return 90;
	} else if(_toggle.selectedSegmentIndex == 0 && [[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"tags"]) {
		_tagsView.text.width = self.view.frame.size.width - 32;
		return _tagsView.text.height + 16;
	} else {
		return 52;
	}
}
-(void)doneButtonPressed:(id)sender {
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController dismissModalViewControllerAnimated:YES];
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	if(_toggle.selectedSegmentIndex == 1 || _paintItBlack) {
		if([_events count]) {
			EventDetailsViewController *details = [[EventDetailsViewController alloc] initWithEvent:[_events objectAtIndex:[indexPath row]]];
			if([[self.navigationController topViewController] isKindOfClass:[PlaybackViewController class]]) {
				[self.navigationController popViewControllerAnimated:NO];
				[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
				[self.navigationController.navigationBar setBarStyle:UIBarStyleDefault];
			}
			if(_paintItBlack) {
				[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
				details.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonPressed:)] autorelease];
				UINavigationController *n = [[UINavigationController alloc] initWithRootViewController:details];
				[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController presentModalViewController:n animated:YES];
				[n release];
			} else {
				[self.navigationController pushViewController:details animated:YES];
			}
			[details release];
		}
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSString *station = [[[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] objectAtIndex:[indexPath row]] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
		if(!_paintItBlack || [station hasPrefix:@"lastfm://"])
			[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:station]];
	}
	[self.tableView reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
	if([newIndexPath row] > 0) {
		[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	}
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.1];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *loadingCell = [tableView dequeueReusableCellWithIdentifier:@"LoadingCell"];
	if(!loadingCell) {
		loadingCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LoadingCell"] autorelease];
		loadingCell.backgroundView = [[[UIView alloc] init] autorelease];
		loadingCell.backgroundColor = [UIColor clearColor];
		loadingCell.textLabel.text = @"\n\n\nLoading";
		loadingCell.textLabel.numberOfLines = 0;
		loadingCell.textLabel.textAlignment = UITextAlignmentCenter;
		loadingCell.textLabel.textColor = [UIColor blackColor];
		UIActivityIndicatorView *progress = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		[progress startAnimating];
		CGRect frame = progress.frame;
		frame.origin.y = 20;
		frame.origin.x = 130;
		progress.frame = frame;
		[loadingCell.contentView addSubview: progress];
		[progress release];
	}
	ArtworkCell *cell = nil;
	
	if([_data count] && [[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
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
	
	if(_toggle.selectedSegmentIndex == 0 && !_infoTabLoaded && !_paintItBlack) {
		return loadingCell;
	}
	
	if((_toggle.selectedSegmentIndex == 1 || _paintItBlack) && !_eventsTabLoaded) {
		return loadingCell;
	}

	if(_toggle.selectedSegmentIndex == 2 && !_similarTabLoaded && !_paintItBlack) {
		return loadingCell;
	}
	
	if([indexPath section] == 1 && _toggle.selectedSegmentIndex == 0 && 
		 ([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_expired"] isEqualToString:@"0"])) {
		UITableViewCell *stationCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"StationCell"] autorelease];
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		stationCell.textLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		stationCell.imageView.image = [UIImage imageNamed:@"radiostarter.png"];
		return stationCell;
	}
	
	if(_toggle.selectedSegmentIndex == 1 || _paintItBlack) {
		if([_events count]) {
			MiniEventCell *eventCell = (MiniEventCell *)[tableView dequeueReusableCellWithIdentifier:@"minieventcell"];
			if (eventCell == nil) {
				eventCell = [[[MiniEventCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"minieventcell"] autorelease];
			}
			
			NSDictionary *event = [_events objectAtIndex:[indexPath row]];
			eventCell.title.text = [event objectForKey:@"headliner"];
			eventCell.location.text = [NSString stringWithFormat:@"%@\n%@, %@", [event objectForKey:@"venue"], [event objectForKey:@"city"], [event objectForKey:@"country"]];
			eventCell.location.lineBreakMode = UILineBreakModeWordWrap;
			eventCell.location.numberOfLines = 0;
			NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
			[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"]; //"Fri, 21 Jan 2011 21:00:00"
			NSDate *date = [formatter dateFromString:[event objectForKey:@"startDate"]];
			[formatter setLocale:[NSLocale currentLocale]];
			
			[formatter setDateFormat:@"MMM"];
			eventCell.month.text = [formatter stringFromDate:date];
			
			[formatter setDateFormat:@"d"];
			eventCell.day.text = [formatter stringFromDate:date];
			
			[formatter release];
			eventCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			
			[eventCell showProgress:NO];
			
			return eventCell;
		} else {
			UITableViewCell *emptyCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LoadingCell"] autorelease];
			emptyCell.selectionStyle = UITableViewCellSelectionStyleNone;
			emptyCell.backgroundView = [[[UIView alloc] init] autorelease];
			emptyCell.backgroundColor = [UIColor clearColor];
			emptyCell.textLabel.text = @"No Upcoming Events";
			emptyCell.textLabel.backgroundColor = [UIColor clearColor];
			emptyCell.textLabel.textAlignment = UITextAlignmentCenter;
			return emptyCell;
		}
	}

	if([indexPath section] == 0 && _toggle.selectedSegmentIndex == 0) {
		ArtworkCell *profilecell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"ProfileCell"];
		if(profilecell == nil) {
			profilecell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ProfileCell"] autorelease];
			profilecell.contentView.bounds = CGRectMake(0,0,85,85);
			profilecell.selectionStyle = UITableViewCellSelectionStyleNone;
			profilecell.placeholder = @"noimage_artist_large.png";
			profilecell.imageURL = [_metadata objectForKey:@"image"];
			profilecell.shouldCacheArtwork = YES;
			profilecell.shouldFillHeight = YES;
			profilecell.title.text = _artist;
			profilecell.accessoryType = UITableViewCellAccessoryNone;
			profilecell.backgroundView = [[[UIView alloc]initWithFrame:CGRectZero] autorelease];
			profilecell.title.backgroundColor = [UIColor clearColor];
			profilecell.subtitle.backgroundColor = [UIColor clearColor];
			profilecell.subtitle.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
			profilecell.subtitle.textColor = [UIColor blackColor];
			[profilecell addBorderWithColor: [UIColor colorWithRed:0.67f green:0.67f blue:0.67f alpha:1.0f]];
			
			NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
			[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
			profilecell.subtitle.lineBreakMode = UILineBreakModeWordWrap;
			profilecell.subtitle.numberOfLines = 0;
			profilecell.subtitle.text = [NSString stringWithFormat:@"Listeners: %@\nTotal scrobbles: %@\nYour scrobbles: %@",
																	 [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[_metadata objectForKey:@"listeners"] intValue]]],
																	 [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[_metadata objectForKey:@"playcount"] intValue]]],
																	 [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[_metadata objectForKey:@"userplaycount"] intValue]]]
																	 ];
			[numberFormatter release];
		}		
		return profilecell;
	}
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"tags"] && _toggle.selectedSegmentIndex == 0) {
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
	}
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"bio"] && _toggle.selectedSegmentIndex == 0) {
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
	}
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"buttons"] && _toggle.selectedSegmentIndex == 0) {
		ButtonsCell *buttonscell = (ButtonsCell *)[tableView dequeueReusableCellWithIdentifier:@"ButtonsCell"];
		if(buttonscell == nil) {
			UIButton* addToLibrary = [UIButton buttonWithType:UIButtonTypeRoundedRect];
			addToLibrary.titleLabel.font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
			[addToLibrary setTitle: @"Add to Library" forState:UIControlStateNormal];
			[addToLibrary setTitle: @"Added to Library" forState:UIControlStateDisabled];
			[addToLibrary setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
			[addToLibrary addTarget:self action:@selector(addToLibrary:) forControlEvents:UIControlEventTouchUpInside];
			if( [[_metadata objectForKey:@"userplaycount"] intValue] > 0 ) {
				addToLibrary.enabled = NO;
			}
			
			UIButton* share = [UIButton buttonWithType:UIButtonTypeRoundedRect];
			share.titleLabel.font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
			[share setTitle: @"Share" forState:UIControlStateNormal];
			[share addTarget:self action:@selector(share:) forControlEvents:UIControlEventTouchUpInside];
			
			UIButton* addTags = [UIButton buttonWithType:UIButtonTypeRoundedRect];
			addTags.titleLabel.font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
			[addTags setTitle: @"Add Tags" forState:UIControlStateNormal];
			[addTags addTarget:self action:@selector(addTags:) forControlEvents:UIControlEventTouchUpInside];
			
			buttonscell = [[[ButtonsCell alloc] initWithReuseIdentifier:@"ButtonsCell" buttons:addToLibrary, share, addTags, nil] autorelease];
		}
		return buttonscell;
	}

	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell.title.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"]) {
			cell.subtitle.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"];
		}
		cell.shouldCacheArtwork = YES;
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"placeholder"] != nil) {
			cell.placeholder = [[stations objectAtIndex:[indexPath row]] objectForKey:@"placeholder"];
		}
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"image"] != nil) {
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
	}		
	if(cell.accessoryType == UITableViewCellAccessoryNone && !_paintItBlack) {
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
	_tagsView = nil;
	[_tracks release];
	_tracks = nil;
	[_albums release];
	_albums = nil;
	[_events release];
	_events = nil;
	[_tags release];
	_tags = nil;
	[_artist release];
	_artist = nil;
	[_metadata release];
	_metadata = nil;
	[_toggle release];
	_toggle = nil;
	[_similarArtists release];
	_similarArtists = nil;
	[_bioView release];
	_bioView = nil;
	[_data release];
	_data = nil;
}
- (void)addToLibrary:(id)sender {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"addToLibrary" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"artist", @"type", nil, nil]];
#endif
	[[LastFMService sharedInstance] addArtistToLibrary: _artist];
	if([LastFMService sharedInstance].error) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
	}
	((UIButton*)sender).enabled = NO;
}
- (void)share:(id)sender {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"share" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"artist", @"type", nil, nil]];
#endif
	ShareActionSheet* action = [[ShareActionSheet alloc] initWithArtist:_artist];
	action.viewController = self.tabBarController;
	[action showFromTabBar: self.tabBarController.tabBar];
	[action release];
}
- (void)addTags:(id)sender {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"tag" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"artist", @"type", nil, nil]];
#endif
	TagEditorViewController* tagEditor = [[TagEditorViewController alloc] initWithTopTags:_tags userTags:[[LastFMService sharedInstance] tagsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]]];
	tagEditor.delegate = self;
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
	[self presentModalViewController:tagEditor animated:YES];
	[tagEditor release];
}

-(void)tagEditorDidCancel {
	[self.navigationController dismissModalViewControllerAnimated:YES];
}
- (void)tagEditorAddTags:(NSArray *)tags {
	[[LastFMService sharedInstance] addTags:tags toArtist:_artist];
	if([LastFMService sharedInstance].error)
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	[self dismissModalViewControllerAnimated:YES];
}
- (void)tagEditorRemoveTags:(NSArray *)tags {
	for(NSString *tag in tags) {
		[[LastFMService sharedInstance] removeTag:tag fromArtist:_artist];
		if([LastFMService sharedInstance].error)
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
	}
}
@end
