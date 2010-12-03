/* RecsViewController.m - Display recs
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

#import "ArtistViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "UIApplication+openURLWithWarning.h"
#import "EventsTabViewController.h"
#import "EventDetailsViewController.h"

@implementation ArtistViewController
- (void)paintItBlack {
	_paintItBlack = YES;
}
- (void)jumpToEventsPage {
	_toggle.selectedSegmentIndex = 1;
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
		webViewHeight = 0;
		
		[NSThread detachNewThreadSelector:@selector(_loadInfoTab) toTarget:self withObject:nil];
		[NSThread detachNewThreadSelector:@selector(_loadSimilarTab) toTarget:self withObject:nil];
		[NSThread detachNewThreadSelector:@selector(_loadEventsTab) toTarget:self withObject:nil];
		self.title = artist;
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
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
	//self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	//self.tableView.sectionHeaderHeight = 0;
	//self.tableView.sectionFooterHeight = 0;
	if(_paintItBlack)
		self.tableView.backgroundColor = [UIColor blackColor];
	self.tableView.scrollsToTop = NO;
	
	_bioView = [[UIWebView alloc] initWithFrame:CGRectZero];
	_bioView.delegate = self;

	_toggle = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Info", @"Events", @"Similar Artists", nil]];
	_toggle.segmentedControlStyle = UISegmentedControlStyleBar;
	_toggle.selectedSegmentIndex = 0;
	_toggle.frame = CGRectMake(6,6,self.view.frame.size.width - 12, _toggle.frame.size.height);
	[_toggle addTarget:self
						 action:@selector(rebuildMenu)
	 forControlEvents:UIControlEventValueChanged];
	
	//UIView *toggleContainer = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.view.frame.size.width, _toggle.frame.size.height + 12)];
	UINavigationBar *toggleContainer = [[UINavigationBar alloc] initWithFrame:CGRectMake(0,0,self.view.frame.size.width,_toggle.frame.size.height + 12)];
	if(_paintItBlack)
		toggleContainer.barStyle = UIBarStyleBlackOpaque;
	[toggleContainer addSubview: _toggle];
	self.tableView.tableHeaderView = toggleContainer;
	[toggleContainer release];
	//self.navigationItem.titleView = _toggle;
}
- (void)webViewDidFinishLoad:(UIWebView *)aWebView {
	CGRect frame = aWebView.frame;
	frame.size.height = 1;
	aWebView.frame = frame;
	CGSize fittingSize = [aWebView sizeThatFits:CGSizeZero];
	fittingSize.width = frame.size.width;
	frame.size = fittingSize;
	aWebView.frame = frame;
	
	webViewHeight = fittingSize.height;
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}
- (void)rebuildMenu {
	NSString *bio = [[_metadata objectForKey:@"summary"] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"];
	NSString *html = [NSString stringWithFormat:@"<html><head><style>a { color: #34A3EC; text-decoration:none; }</style></head>\
										<body style=\"margin:0; padding:0; color:black; background: white; font-family: Helvetica; font-size: 11pt;\">\
										<div style=\"padding:0px; margin:0; top:0px; left:0px; width:286px; position:absolute;\">\
										%@ <a href=\"http://www.last.fm/Music/%@/wiki\">Read More »</a></body></html>", bio, [_artist URLEscaped]];
	[_bioView loadHTMLString:html baseURL:nil];
	
	if(_data)
		[_data release];
	
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	NSMutableArray *stations;

	if(_toggle.selectedSegmentIndex == 0) {
		if(!_infoTabLoaded) {
			[sections addObject:@"Loading"];
		} else {
			[sections addObject:@"profile"];
			
			[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"",
																															 [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"Play %@ Radio", _artist], [NSString stringWithFormat:@"lastfm://artist/%@/similarartists", [_artist URLEscaped]], nil]
																																																										 forKeys:[NSArray arrayWithObjects:@"title", @"url", nil]], nil]
																															 , nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];

			[sections addObject:@"bio"];
			
			if([_tracks count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_tracks count] && x < 5; x++) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_tracks objectAtIndex:x] objectForKey:@"name"], [[_tracks objectAtIndex:x] objectForKey:@"image"],
																																	 [NSString stringWithFormat:@"lastfm-track://%@/%@", [_artist URLEscaped], [[[_tracks objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
				}
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Top Tracks", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			}
			
			if([_albums count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_albums count] && x < 5; x++) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_albums objectAtIndex:x] objectForKey:@"name"], [[_albums objectAtIndex:x] objectForKey:@"image"],
																																	 [NSString stringWithFormat:@"lastfm-album://%@/%@", [_artist URLEscaped], [[[_albums objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
				}
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Top Albums", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			}

			if([_tags count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_tags count] && x < 10; x++) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_tags objectAtIndex:x] objectForKey:@"name"],
																																	 [NSString stringWithFormat:@"lastfm-tag://%@", [[[_tags objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
				}
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Related Tags", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			}
		}
	} else if(_toggle.selectedSegmentIndex == 2) {
		if(!_similarTabLoaded) {
			[sections addObject:@"Loading"];
		} else {
			if([_similarArtists count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_similarArtists count] && x < 20; x++) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_similarArtists objectAtIndex:x] objectForKey:@"name"], [[_similarArtists objectAtIndex:x] objectForKey:@"image"],
																																	 [NSString stringWithFormat:@"lastfm-artist://%@", [[[_similarArtists objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
				}
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			}
		}
	}
	_data = [sections retain];
	
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
	if(_toggle.selectedSegmentIndex == 1)
		return 1;
	else
		return [_data count];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(_toggle.selectedSegmentIndex == 1)
		return _eventsTabLoaded?[_events count]:1;
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
	if(_toggle.selectedSegmentIndex == 1)
		return nil;
	else if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]])
		return [((NSDictionary *)[_data objectAtIndex:section]) objectForKey:@"title"];
	else
		return nil;
}
/*- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
 return [[[UIView alloc] init] autorelease];
 }*/
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(_toggle.selectedSegmentIndex == 1) {
		return 64;
	} else if([indexPath section] == 2 && _toggle.selectedSegmentIndex == 0) {
		return webViewHeight + 16;
	} else {
		return 52;
	}
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	if(_toggle.selectedSegmentIndex == 1) {
		EventDetailsViewController *details = [[EventDetailsViewController alloc] initWithEvent:[_events objectAtIndex:[indexPath row]]];
		if([[((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController topViewController] isKindOfClass:[PlaybackViewController class]]) {
			[((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController popViewControllerAnimated:NO];
			[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:YES];
			[((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController.navigationBar setBarStyle:UIBarStyleDefault];
		}
		[((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController pushViewController:details animated:YES];
		[details release];
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSString *station = [[[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] objectAtIndex:[indexPath row]] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
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
		loadingCell.textLabel.text = @"Loading";
		[loadingCell showProgress:YES];
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
	
	if(_toggle.selectedSegmentIndex == 0 && !_infoTabLoaded) {
		return loadingCell;
	}
	
	if(_toggle.selectedSegmentIndex == 1 && !_eventsTabLoaded) {
		return loadingCell;
	}

	if(_toggle.selectedSegmentIndex == 2 && !_similarTabLoaded) {
		return loadingCell;
	}
	
	if([indexPath section] == 1 && _toggle.selectedSegmentIndex == 0) {
		UITableViewCell *stationCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"StationCell"] autorelease];
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		stationCell.textLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
		img.opaque = YES;
		stationCell.accessoryView = img;
		[img release];
		return stationCell;
	}
	
	if(_toggle.selectedSegmentIndex == 1) {
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
	}

	if([indexPath section] == 0 && _toggle.selectedSegmentIndex == 0) {
		ArtworkCell *profilecell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"ProfileCell"];
		if(profilecell == nil) {
			profilecell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ProfileCell"] autorelease];
			profilecell.selectionStyle = UITableViewCellSelectionStyleNone;
			profilecell.imageURL = [_metadata objectForKey:@"image"];
			profilecell.shouldRoundTop = YES;
			profilecell.shouldRoundBottom = YES;
			profilecell.shouldCacheArtwork = YES;
			profilecell.title.text = _artist;
			
			NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
			[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
			profilecell.subtitle.text = [NSString stringWithFormat:@"%@ plays in your library",[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[_metadata objectForKey:@"userplaycount"] intValue]]]];
			[numberFormatter release];
		}		
		return profilecell;
	}
	
	if([indexPath section] == 2 && _toggle.selectedSegmentIndex == 0) {
		UITableViewCell *biocell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"BioCell"];
		if(biocell == nil) {
			biocell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"BioCell"] autorelease];
			_bioView.frame = CGRectMake(12,8,self.view.frame.size.width - (20*2), webViewHeight);
			[biocell.contentView addSubview:_bioView];
		}
		return biocell;
	}

	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell.title.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"]) {
			cell.subtitle.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"];
		}
		cell.shouldCacheArtwork = YES;
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"image"] != nil) {
			cell.imageURL = [[stations objectAtIndex:[indexPath row]] objectForKey:@"image"];
		} else {
			[cell hideArtwork:YES];
		}
		cell.shouldFillHeight = YES;
		if([indexPath row] == 0)
			cell.shouldRoundTop = YES;
		if([indexPath row] == [self tableView:tableView numberOfRowsInSection:[indexPath section]]-1)
			cell.shouldRoundBottom = YES;
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
	[_tags release];
	[_artist release];
	[_metadata release];
	[_toggle release];
	[_similarArtists release];
	[_bioView release];
	[_data release];
}
@end
