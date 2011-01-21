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
	[_emptyView release];
	_emptyView = nil;
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
	bar.placeholder = @"Music Search";
	bar.delegate = self;
	self.tableView.tableHeaderView = bar;
	self.tableView.dataSource = _searchData;
	self.tableView.delegate = self;
	
	_emptyView = [[UIView alloc] initWithFrame:CGRectMake(0,60,self.view.frame.size.width,self.view.frame.size.height)];
	_emptyView.backgroundColor = [UIColor whiteColor];
	_emptyView.opaque = NO;
	
	UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(0,128,_emptyView.frame.size.width,40)];
	hint.text = @"Search Last.fm for Information about\nartists, albums, tracks, and tags.";
	hint.numberOfLines = 2;
	hint.font = [UIFont boldSystemFontOfSize:16];
	hint.textColor = [UIColor grayColor];
	hint.textAlignment = UITextAlignmentCenter;
	[_emptyView addSubview: hint];
	
	UIImageView *image = [[UIImageView alloc] initWithFrame:CGRectMake((_emptyView.frame.size.width - 55) / 2, hint.frame.origin.y - 61,55,55)];
	image.image = [UIImage imageNamed:@"search_icon"];
	[_emptyView addSubview: image];
	
	[hint release];
	[image release];
	
	if([_searchData.data count] == 0) {
		self.tableView.scrollEnabled = NO;
		self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		[self.tableView addSubview: _emptyView];
	}
	[bar release];
}
- (void)_search:(NSTimer *)timer {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *query = [timer userInfo];
	[_searchData search:query];
	[self.searchDisplayController.searchResultsTableView reloadData];
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[pool release];
}
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
	[_emptyView removeFromSuperview];
	self.tableView.scrollEnabled = YES;
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	[self.tableView reloadData];
	return YES;
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
	[searchBar resignFirstResponder];
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 52;
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	NSArray *_data = [_searchData data];
	if([[_data objectAtIndex:[indexPath row]] isKindOfClass:[NSDictionary class]]) {
		NSString *station = [[_data objectAtIndex:[indexPath row]] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
		[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:station]];
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"logout"]) {
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) logoutButtonPressed:nil];
	}
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
	if([newIndexPath row] > 0) {
		[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	}
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.1];
}
- (void)dealloc {
	[super dealloc];
	[_searchData release];
}
@end
