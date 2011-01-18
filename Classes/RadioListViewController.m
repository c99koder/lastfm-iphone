/* RadioListViewController.m - Display a Last.fm radio list
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

#import "RadioListViewController.h"
#import "SearchViewController.h"
#import "TagRadioViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import </usr/include/objc/objc-class.h>
#import "DebugViewController.h"
#import "MobileLastFMApplicationDelegate.h"

@implementation RadioListViewController
- (void)_refresh {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[[LastFMRadio sharedInstance] fetchRecentURLs];
	if(![[NSThread currentThread] isCancelled]) {
		@synchronized(self) {
			[_refreshThread release];
			_refreshThread = nil;
		}
		[self performSelectorOnMainThread:@selector(rebuildMenu) withObject:nil waitUntilDone:YES];
	}
	[pool release];
}
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		self.title = @"Radio";
		_username = [username retain];
		_searchData = [[RadioSearchDataSource alloc] init];
		_refreshThread = [[NSThread alloc] initWithTarget:self selector:@selector(_refresh) object:nil];
		[_refreshThread start];
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	//[self.tableView setContentOffset:CGPointMake(0,self.tableView.tableHeaderView.frame.size.height)];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	
	[self rebuildMenu];

	if(_refreshThread) {
		[_refreshThread cancel];
		[_refreshThread release];
	}
	
	_refreshThread = [[NSThread alloc] initWithTarget:self selector:@selector(_refresh) object:nil];
	[_refreshThread start];
	
	UISearchBar *bar = (UISearchBar *)self.tableView.tableHeaderView;
	[bar resignFirstResponder];
	bar.showsCancelButton = NO;
	bar.text = @"";
}
- (void)viewDidLoad {
	/*self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	self.tableView.sectionHeaderHeight = 0;
	self.tableView.sectionFooterHeight = 0;
	self.tableView.backgroundColor = [UIColor blackColor];*/
	UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width, 45)];
	bar.placeholder = @"Enter an artist or genre";
	bar.delegate = self;
	self.tableView.tableHeaderView = bar;
	/*UISearchDisplayController *searchController = [[UISearchDisplayController alloc] initWithSearchBar:bar contentsController:self];
	searchController.delegate = self;
	searchController.searchResultsDataSource = _searchData;
	searchController.searchResultsDelegate = _searchData;*/
	[bar release];
}
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
	searchBar.showsCancelButton = YES;
	return YES;
}
- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	searchBar.showsCancelButton = NO;
	[searchBar resignFirstResponder];
}
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	if(_searchTimer) {
		[_searchTimer invalidate];
		[_searchTimer release];
		_searchTimer = nil;
	}
	if([searchBar.text length]) {
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		_searchTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0
																										 target:self
																									 selector:@selector(_search:)
																									 userInfo:searchBar.text
																										repeats:NO] retain];
	}
}
- (void)_search:(NSTimer *)timer {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *query = [timer userInfo];
	/*[_searchData search:query];
	[self.searchDisplayController.searchResultsTableView reloadData];
	[self.searchDisplayController loadContentForCells:[self.searchDisplayController.searchResultsTableView visibleCells]];*/
	NSString *station = [[LastFMService sharedInstance] searchForStation:query];
	NSLog(@"Station: %@", station);
	[self playRadioStation:station];
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[pool release];
}
- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)query {
	if(_searchTimer) {
		[_searchTimer invalidate];
		[_searchTimer release];
		_searchTimer = nil;
	}
	if([query length]) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		_searchTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0
																										 target:self
																									 selector:@selector(_search:)
																									 userInfo:query
																										repeats:NO] retain];
	}
	return NO;
}
- (void)rebuildMenu {
	@synchronized(self) {
		if(_data)
			[_data release];
		
		[_recent release];
		_recent = [[[LastFMRadio sharedInstance] recentURLs] retain];
		
		NSMutableArray *sections = [[NSMutableArray alloc] init];
		
		NSMutableArray *stations = [[NSMutableArray alloc] init];
		[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Library", @"My Library station"),
																						  [NSString stringWithFormat:@"lastfm://user/%@/personal", _username],
																						  NSLocalizedString(@"Music you know and love", @"My Library description"),
																						  nil] 
														forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description",nil]]];
		
		[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Mix Radio", @"My Mix Radio"),
																[NSString stringWithFormat:@"lastfm://user/%@/mix", _username],
																NSLocalizedString(@"Your library + new music", @"Mix Radio description"),
																nil] 
														forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description", nil]]];
		
		[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"Recommended by Last.fm", @"Recommended by Last.fm station"),
																						  [NSString stringWithFormat:@"lastfm://user/%@/recommended", _username],
																					      NSLocalizedString(@"New Music from Last.fm", @"Recommendation Radio description"),
																						  nil] 
														forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description" ,nil]]];
		
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Personal Stations", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		[stations release];
		
		stations = [[NSMutableArray alloc] init];
		[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Friends Radio",
																						  [NSString stringWithFormat:@"lastfm://user/%@/friends", _username],
																						  @"Music your friends like",
																						  nil] 
														forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description", nil]]];

		[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Neighbourhood Radio",
																						  [NSString stringWithFormat:@"lastfm://user/%@/neighbours", _username],
																						  @"Music from listeners like you",
																						  nil] 
														forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description", nil]]];
		
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Network Stations", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		[stations release];
		
		if([_recent count]) {
			stations = [[NSMutableArray alloc] init];
			for(int x=0; x<[_recent count]; x++) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_recent objectAtIndex:x] objectForKey:@"name"],[[_recent objectAtIndex:x] objectForKey:@"url"],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
			}
			[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"Recent Stations", @"Recent Stations heading"), stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
			[stations release];
		}
		
#ifndef DISTRIBUTION	
		[sections addObject:@"debug"];
#endif
		
		_data = sections;

		[self.tableView reloadData];
		[self loadContentForCells:[self.tableView visibleCells]];
	}
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
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 52;
}
-(void)playRadioStation:(NSString *)url {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:url animated:YES];
	}
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSString *station = [[[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] objectAtIndex:[indexPath row]] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
		if([station hasPrefix:@"lastfm://"])
			[self playRadioStation:station];
		else if([station isEqualToString:@"tags"]) {
			TagRadioViewController *tags = [[TagRadioViewController alloc] initWithUsername:_username];
			if(tags) {
				[self.navigationController pushViewController:tags animated:YES];
				[tags release];
			}
		}
	} else if([[_data objectAtIndex:[indexPath section]] isEqualToString:@"start"]) {
		if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username]) {
			SearchViewController *controller = [[SearchViewController alloc] initWithNibName:@"SearchView" bundle:nil];
			[self.navigationController pushViewController:controller animated:YES];
			[controller release];
		}
	} else if([[_data objectAtIndex:[indexPath section]] isEqualToString:@"debug"]) {
		DebugViewController *controller = [[DebugViewController alloc] initWithNibName:@"DebugView" bundle:nil];
		[self.navigationController pushViewController:controller animated:YES];
		[controller release];
	}
	[self.tableView reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.1];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]])
		return [((NSDictionary *)[_data objectAtIndex:section]) objectForKey:@"title"];
	else
		return nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil] autorelease];

	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell.textLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		cell.detailTextLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"description"];
		if([[[stations objectAtIndex:[indexPath row]] objectForKey:@"url"] isEqualToString:@"tags"])
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else {
		cell.textLabel.text = @"Debug";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	
	if(cell.accessoryType == UITableViewCellAccessoryNone) {
		UIImage *img = [UIImage imageNamed:@"streaming.png"];
		cell.imageView.image = img;
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	if(_refreshThread) {
		[_refreshThread cancel];
		[_refreshThread release];
	}
	[_username release];
	[_recent release];
	[_searchData release];
	[_data release];
}
@end
