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

@implementation ArtistViewController
- (void)paintItBlack {
	_paintItBlack = YES;
}
- (void)_loadInfoTab {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_tags = [[[LastFMService sharedInstance] topTagsForArtist:_artist] retain];
	_metadata = [[[LastFMService sharedInstance] metadataForArtist:_artist inLanguage:@"en"] retain];
	_albums = [[[LastFMService sharedInstance] topAlbumsForArtist:_artist] retain];
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
		[NSThread detachNewThreadSelector:@selector(_loadInfoTab) toTarget:self withObject:nil];
		[NSThread detachNewThreadSelector:@selector(_loadSimilarTab) toTarget:self withObject:nil];
		self.title = artist;
	}
	return self;
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
	if(_paintItBlack)
		self.tableView.backgroundColor = [UIColor blackColor];
	self.tableView.scrollsToTop = NO;
	
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
- (void)rebuildMenu {
	[self.tableView setContentOffset:CGPointMake(0,0)];
	
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
																															 [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"Play %@ Radio", _artist], [NSString stringWithFormat:@"lastfm://artist/%@/similarartists", _artist], nil]
																																																										 forKeys:[NSArray arrayWithObjects:@"title", @"url", nil]], nil]
																															 , nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];

			[sections addObject:@"bio"];
			
			if([_albums count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_albums count] && x < 5; x++) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_albums objectAtIndex:x] objectForKey:@"name"], [[_albums objectAtIndex:x] objectForKey:@"image"],
																																	 [NSString stringWithFormat:@"lastfm-artost://%@", [[_albums objectAtIndex:x] objectForKey:@"name"]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
				}
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Top Albums", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			}

			if([_tags count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_tags count] && x < 10; x++) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_tags objectAtIndex:x] objectForKey:@"name"],
																																	 [NSString stringWithFormat:@"lastfm-artost://%@", [[_tags objectAtIndex:x] objectForKey:@"name"]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
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
	} else {
		return nil;
	}
}
/*- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
 return [[[UIView alloc] init] autorelease];
 }*/
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([indexPath section] == 2 && _toggle.selectedSegmentIndex == 0) {
		return [[_metadata objectForKey:@"summary"] sizeWithFont:[UIFont systemFontOfSize:12.0f] constrainedToSize:CGSizeMake(self.view.frame.size.width - (18*2), MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap].height + 12;
	} else {
		return 52;
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
	if([newIndexPath row] > 0) {
		[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	}
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.1];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *loadingCell = [tableView dequeueReusableCellWithIdentifier:@"LoadingCell"];
	if(!loadingCell) {
		loadingCell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"LoadingCell"] autorelease];
		loadingCell.textLabel.text = @"Loading";
	}
	ArtworkCell *cell = nil;
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[stations objectAtIndex:[indexPath row]] objectForKey:@"title"]];
		if (cell == nil) {
			cell = [[[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:[[stations objectAtIndex:[indexPath row]] objectForKey:@"title"]] autorelease];
		}
	}
	if(cell == nil)
		cell = [[[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"ArtworkCell"] autorelease];
	
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
		UITableViewCell *stationCell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"StationCell"] autorelease];
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		stationCell.textLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
		img.opaque = YES;
		stationCell.accessoryView = img;
		[img release];
		return stationCell;
	}

	if([indexPath section] == 0 && _toggle.selectedSegmentIndex == 0) {
		ArtworkCell *profilecell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"ProfileCell"];
		if(profilecell == nil) {
			profilecell = [[[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"ProfileCell"] autorelease];
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
			biocell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"BioCell"] autorelease];
			UITextView *bio = [[UITextView alloc] initWithFrame:CGRectMake(0,6,self.view.frame.size.width - (18*2), [[_metadata objectForKey:@"bio"] sizeWithFont:[UIFont systemFontOfSize:12.0f] constrainedToSize:CGSizeMake(self.view.frame.size.width - 20, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap].height)];
			bio.text = [_metadata objectForKey:@"summary"];
			bio.backgroundColor = [UIColor clearColor];
			bio.textColor = [UIColor  blackColor];
			bio.editable = NO;
			bio.font = [UIFont systemFontOfSize:12.0f];
			[biocell.contentView addSubview:bio];
			[bio release];
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
		if([[[stations objectAtIndex:[indexPath row]] objectForKey:@"image"] length]) {
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
	[_data release];
}
@end
