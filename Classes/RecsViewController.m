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

#import "RecsViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import "MobileLastFMApplicationDelegate.h"

@implementation RecsViewController
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_username = [username retain];
		_artists = [[[LastFMService sharedInstance] recommendedArtistsForUser:username] retain];
		_releases = [[[LastFMService sharedInstance] releasesForUser:username] retain];
		_recommendedReleases = [[[LastFMService sharedInstance] recommendedReleasesForUser:username] retain];
		/*UISegmentedControl *toggle = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Music", @"Latest Releases", nil]];
		toggle.segmentedControlStyle = UISegmentedControlStyleBar;
		toggle.selectedSegmentIndex = 0;
		[toggle addTarget:self
							 action:@selector(rebuildMenu)
		 forControlEvents:UIControlEventValueChanged];
		self.navigationItem.titleView = toggle;*/
		self.title = @"Recommendations";
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self.tableView setContentOffset:CGPointMake(0,self.tableView.tableHeaderView.frame.size.height)];
	
	[self rebuildMenu];
}
- (void)viewDidLoad {
	//self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	//self.tableView.sectionHeaderHeight = 0;
	//self.tableView.sectionFooterHeight = 0;
	//self.tableView.backgroundColor = [UIColor blackColor];
	
	UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width, 45)];
	//bar.barStyle = UIBarStyleBlackTranslucent;
	//bar.backgroundColor = [UIColor grayColor];
	bar.placeholder = @"Search Recommendations";
	self.tableView.tableHeaderView = bar;
	[bar release];
}
- (void)rebuildMenu {
	if(_data)
		[_data release];
	
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	NSMutableArray *stations;
	
	//UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;
	
	//if(toggle.selectedSegmentIndex == 0) {
	[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Play my recommendations", 
																													 [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Recommended Radio", @"lastfm://...", nil]
																																																									forKeys:[NSArray arrayWithObjects:@"title", @"url", nil]], nil]
																													 , nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
	
	if([_artists count]) {
		stations = [[NSMutableArray alloc] init];
		for(int x=0; x<[_artists count] && x < 3; x++) {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_artists objectAtIndex:x] objectForKey:@"name"], [[_artists objectAtIndex:x] objectForKey:@"image"],
																															 [NSString stringWithFormat:@"lastfm-artost://%@", [[_artists objectAtIndex:x] objectForKey:@"name"]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
		}
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Recommended Artists", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		[stations release];
	}
	//} else {
	stations = [[NSMutableArray alloc] init];
	if([_releases count]) {
		for(int x=0; x<[_releases count] && x < 3; x++) {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_releases objectAtIndex:x] objectForKey:@"name"], [[_releases objectAtIndex:x] objectForKey:@"image"], [[_releases objectAtIndex:x] objectForKey:@"artist"],
																															 [NSString stringWithFormat:@"lastfm-artost://%@", [[_releases objectAtIndex:x] objectForKey:@"name"]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"artist", @"url",nil]]];
		}
	}
	if([_recommendedReleases count]) {
		for(int x=0; x<[_recommendedReleases count] && x < 3; x++) {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_recommendedReleases objectAtIndex:x] objectForKey:@"name"], [[_recommendedReleases objectAtIndex:x] objectForKey:@"image"], [[_recommendedReleases objectAtIndex:x] objectForKey:@"artist"],
																															 [NSString stringWithFormat:@"lastfm-artost://%@", [[_recommendedReleases objectAtIndex:x] objectForKey:@"name"]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"artist", @"url",nil]]];
		}
	}
	[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Releases", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
	[stations release];
	//}
	_data = [sections retain];
	
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
	return [((NSDictionary *)[_data objectAtIndex:section]) objectForKey:@"title"];
}
/*- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
 return [[[UIView alloc] init] autorelease];
 }*/
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 52;
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSString *station = [[[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] objectAtIndex:[indexPath row]] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
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
	ArtworkCell *cell = [[[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"TrackCell"] autorelease];
	
	//UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;

	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if([indexPath section] == 0/* && toggle.selectedSegmentIndex == 0*/) {
		UITableViewCell *stationCell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"StationCell"] autorelease];
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		stationCell.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
		img.opaque = YES;
		stationCell.accessoryView = img;
		[img release];
		return stationCell;
	}
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell.title.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"]) {
			cell.subtitle.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"];
		}
		cell.shouldCacheArtwork = YES;
		cell.imageURL = [[stations objectAtIndex:[indexPath row]] objectForKey:@"image"];
		cell.shouldFillHeight = YES;
		if([indexPath row] == 0)
			cell.shouldRoundTop = YES;
		if([indexPath row] == [self tableView:tableView numberOfRowsInSection:[indexPath section]]-1)
			cell.shouldRoundBottom = YES;
	}
	
	if([indexPath section] > 0 && cell.accessoryType == UITableViewCellAccessoryNone) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_username release];
	[_artists release];
	[_releases release];
	[_data release];
}
@end
