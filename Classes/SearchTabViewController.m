/* SearchTabViewController.m - Display search results
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

#import "SearchTabViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "ArtistViewController.h"
#import "UIApplication+openURLWithWarning.h"

@implementation SearchTabViewController
- (void)viewDidUnload {
	[super viewDidUnload];
	NSLog(@"Releasing search data");
	[_searchData release];
	_searchData = nil;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
}
- (id)initWithStyle:(UITableViewStyle)style {
	if (self = [super initWithStyle:style]) {
		_searchData = [[GlobalSearchDataSource alloc] init];
		self.title = @"Search";
	}
	return self;
}
- (void)viewDidLoad {
	UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width, 45)];
	bar.placeholder = @"Search Last.fm";
	self.tableView.tableHeaderView = bar;
	self.tableView.dataSource = _searchData;
	self.tableView.delegate = _searchData;
	
	UISearchDisplayController *searchController = [[UISearchDisplayController alloc] initWithSearchBar:bar contentsController:self];
	searchController.delegate = self;
	searchController.searchResultsDataSource = _searchData;
	searchController.searchResultsDelegate = _searchData;
	
	[bar release];
}
- (void)_search:(NSTimer *)timer {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *query = [timer userInfo];
	[_searchData search:query];
	[self.searchDisplayController.searchResultsTableView reloadData];
	[self.tableView reloadData];
	[self.searchDisplayController loadContentForCells:[self.searchDisplayController.searchResultsTableView visibleCells]];
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
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_searchData release];
}
@end
