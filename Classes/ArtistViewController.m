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
#import "MobileLastFMApplicationDelegate.h"
#import "UIApplication+openURLWithWarning.h"
#import "EventsTabViewController.h"
#import "EventDetailsViewController.h"

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
		
		[NSThread detachNewThreadSelector:@selector(_loadInfoTab) toTarget:self withObject:nil];
		[NSThread detachNewThreadSelector:@selector(_loadSimilarTab) toTarget:self withObject:nil];
		[NSThread detachNewThreadSelector:@selector(_loadEventsTab) toTarget:self withObject:nil];
		self.title = artist;
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if(_paintItBlack) {
		self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
		UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 61, 31)];
		[btn setBackgroundImage:[UIImage imageNamed:@"nowplaying_back.png"] forState:UIControlStateNormal];
		btn.adjustsImageWhenHighlighted = YES;
		[btn addTarget:self.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
		UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView: btn];
		self.navigationItem.leftBarButtonItem = item;
		[btn release];
		[item release];
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
}
- (void)rebuildMenu {
	NSString *bio = [[_metadata objectForKey:@"summary"] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"];
	NSString *html = [NSString stringWithFormat:@"%@ <a href=\"http://www.last.fm/music/%@/+wiki\">Read More »</a>", bio, [_artist URLEscaped]];
	_bioView.html = html;
	
	if(_data)
		[_data release];
	
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	NSMutableArray *stations;

	if(_toggle.selectedSegmentIndex == 0) {
		if(!_infoTabLoaded) {
			[sections addObject:@"Loading"];
		} else {
			[sections addObject:@"profile"];
			
			if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_expired"] isEqualToString:@"0"])
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"",
																															 [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"Play %@ Radio", _artist], [NSString stringWithFormat:@"lastfm://artist/%@/similarartists", [_artist URLEscaped]], nil]
																																																										 forKeys:[NSArray arrayWithObjects:@"title", @"url", nil]], nil]
																															 , nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];

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
						taghtml = [taghtml stringByAppendingFormat:@"<a href='lastfm-tag://%@'>%@, </a>", [[[_tags objectAtIndex: i] objectForKey:@"name"] URLEscaped], [[[_tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
					else
						taghtml = [taghtml stringByAppendingFormat:@"<a href='lastfm-tag://%@'>%@</a>", [[[_tags objectAtIndex: i] objectForKey:@"name"] URLEscaped], [[[_tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
				}
			}
			
			_tagsView.html = taghtml;
			
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
		return nil;
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
	if(_toggle.selectedSegmentIndex == 0 && [indexPath section] == 0)
		return 86;
	else if((_toggle.selectedSegmentIndex == 1 || _paintItBlack) && [_events count]) {
		return 64;
	} else if(_toggle.selectedSegmentIndex == 0 && [[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"bio"]) {
		_bioView.text.width = self.view.frame.size.width - 32;
		return _bioView.text.height + 16;
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
				details.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonPressed:)];
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
	
	if((_toggle.selectedSegmentIndex == 1 || _paintItBlack) && !_eventsTabLoaded) {
		return loadingCell;
	}

	if(_toggle.selectedSegmentIndex == 2 && !_similarTabLoaded) {
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
			emptyCell.textLabel.text = @"No Upcoming Events";
			return emptyCell;
		}
	}

	if([indexPath section] == 0 && _toggle.selectedSegmentIndex == 0) {
		ArtworkCell *profilecell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"ProfileCell"];
		if(profilecell == nil) {
			profilecell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ProfileCell"] autorelease];
			profilecell.contentView.bounds = CGRectMake(0,0,80,80);
			profilecell.selectionStyle = UITableViewCellSelectionStyleNone;
			profilecell.placeholder = @"noimage_artist.png";
			profilecell.imageURL = [_metadata objectForKey:@"image"];
			profilecell.shouldRoundTop = YES;
			profilecell.shouldRoundBottom = YES;
			profilecell.shouldCacheArtwork = YES;
			profilecell.title.text = _artist;
			profilecell.accessoryType = UITableViewCellAccessoryNone;
			
			NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
			[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
			profilecell.subtitle.lineBreakMode = UILineBreakModeWordWrap;
			profilecell.subtitle.numberOfLines = 0;
			profilecell.subtitle.text = [NSString stringWithFormat:@"%@ plays\n%@ listeners\n%@ plays in your library",
																	 [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[_metadata objectForKey:@"playcount"] intValue]]],
																	 [numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[_metadata objectForKey:@"listeners"] intValue]]],
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
			[cell hideArtwork:YES];
		}
		cell.shouldFillHeight = YES;
		if([indexPath row] == 0)
			cell.shouldRoundTop = YES;
		if([indexPath row] == [self tableView:tableView numberOfRowsInSection:[indexPath section]]-1)
			cell.shouldRoundBottom = YES;
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
	[_tracks release];
	[_albums release];
	[_events release];
	[_tags release];
	[_artist release];
	[_metadata release];
	[_toggle release];
	[_similarArtists release];
	[_bioView release];
	[_data release];
}
@end
