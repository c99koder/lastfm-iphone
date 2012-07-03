/* RadioListViewController.m - Display a Last.fm radio list
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

#import "RadioListViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import "DebugViewController.h"
#import "MobileLastFMApplicationDelegate.h"
#import "UIColor+LastFMColors.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "FlurryAnalytics.h"
#endif

@implementation RadioListViewController
- (void)_refresh {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSDictionary *stations = nil;
    @try {
        [[LastFMRadio sharedInstance] fetchRecentURLs];
    } @catch(NSException *e) {
    }
	if([_username isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]])
		stations = [[[LastFMService sharedInstance] userStations] retain];
	if(![[NSThread currentThread] isCancelled]) {
		@synchronized(self) {
			[_stations release];
			_stations = stations;
			[_refreshThread release];
			_refreshThread = nil;
		}
		[self performSelectorOnMainThread:@selector(rebuildMenu) withObject:nil waitUntilDone:YES];
	} else {
		[stations release];
	}
	[pool release];
}
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		self.title = @"Radio";
		self.tabBarItem.image = [UIImage imageNamed:@"tabbar_radio.png"];
		_username = [username retain];
		if([_username isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]])
			_stations = [[[LastFMService sharedInstance] userStations] retain];
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
	self.tableView.sectionFooterHeight = 0;*/
	self.tableView.backgroundColor = [UIColor lfmTableBackgroundColor];
	UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width, 45)];
	bar.placeholder = @"Type an artist, genre, or username";
	bar.delegate = self;
	self.tableView.tableHeaderView = bar;
	
	for ( UIView* view in [bar subviews] ) {
		if( [ view isKindOfClass: [UITextField class] ] ) {
			[((UITextField*)view) setReturnKeyType:UIReturnKeyGo];
		}
	}
	
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
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"radio-search"];
#endif
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
        if(_data) {
            [_data release];
            _data = nil;
        }
		
		[_recent release];
		_recent = [[[LastFMRadio sharedInstance] recentURLs] retain];
		
		NSMutableArray *sections = [[NSMutableArray alloc] init];
		
		NSMutableArray *stations = [[NSMutableArray alloc] init];
		if(_stations) {
			for(int i = 0; i < [[_stations objectForKey:@"personalstations"] count]; i++) {
				NSDictionary *station = [[_stations objectForKey:@"personalstations"] objectAtIndex:i];
				
				if([[station objectForKey:@"url"] hasSuffix:@"/personal"] && [[station objectForKey:@"available"] isEqualToString:@"1"]) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Library Radio", @"My Library station"),
																																	 [NSString stringWithFormat:@"lastfm://user/%@/personal", _username],
																																	 NSLocalizedString(@"Music you know and love", @"My Library description"),
																																	 nil] 
																													forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description",nil]]];
				}
				if([[station objectForKey:@"url"] hasSuffix:@"/mix"] && [[station objectForKey:@"available"] isEqualToString:@"1"]) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Mix Radio", @"My Mix Radio"),
																																	 [NSString stringWithFormat:@"lastfm://user/%@/mix", _username],
																																	 NSLocalizedString(@"Your library + new music", @"Mix Radio description"),
																																	 nil] 
																													forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description", nil]]];
				}
				if([[station objectForKey:@"url"] hasSuffix:@"/recommended"] && [[station objectForKey:@"available"] isEqualToString:@"1"]) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Recommended Radio", @"My Recommended Radio"),
																																	 [NSString stringWithFormat:@"lastfm://user/%@/recommended", _username],
																																	 NSLocalizedString(@"New Music from Last.fm", @"Recommendation Radio description"),
																																	 nil] 
																													forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description" ,nil]]];
				}
			}
		} else {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Library Radio", @"My Library station"),
																								[NSString stringWithFormat:@"lastfm://user/%@/personal", _username],
																								NSLocalizedString(@"Music you know and love", @"My Library description"),
																								nil] 
															forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description",nil]]];
			
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Mix Radio", @"My Mix Radio"),
																	[NSString stringWithFormat:@"lastfm://user/%@/mix", _username],
																	NSLocalizedString(@"Your library + new music", @"Mix Radio description"),
																	nil] 
															forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description", nil]]];
			
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Recommended Radio", @"My Recommended Radio"),
																								[NSString stringWithFormat:@"lastfm://user/%@/recommended", _username],
																									NSLocalizedString(@"New Music from Last.fm", @"Recommendation Radio description"),
																								nil] 
															forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description" ,nil]]];
		}
		if([stations count])
			[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Personal Stations", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		else
			[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Personal Stations", @"hint", nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		[stations release];
		
		stations = [[NSMutableArray alloc] init];
		if(_stations) {
			for(int i = 0; i < [[_stations objectForKey:@"networkstations"] count]; i++) {
				NSDictionary *station = [[_stations objectForKey:@"networkstations"] objectAtIndex:i];
				
				if([[station objectForKey:@"url"] hasSuffix:@"/friends"] && [[station objectForKey:@"available"] isEqualToString:@"1"]) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Friends’ Radio",
																																	 [NSString stringWithFormat:@"lastfm://user/%@/friends", _username],
																																	 @"Music your friends like",
																																	 nil] 
																													forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description", nil]]];
				}
				if([[station objectForKey:@"url"] hasSuffix:@"/neighbours"] && [[station objectForKey:@"available"] isEqualToString:@"1"]) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Neighbourhood Radio",
																																	 [NSString stringWithFormat:@"lastfm://user/%@/neighbours", _username],
																																	 @"Music from listeners like you",
																																	 nil] 
																													forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description", nil]]];
				}
			}
		} else {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Friends’ Radio",
																						[NSString stringWithFormat:@"lastfm://user/%@/friends", _username],
																						@"Music your friends like",
																						nil] 
													forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description", nil]]];

			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Neighbourhood Radio",
																						[NSString stringWithFormat:@"lastfm://user/%@/neighbours", _username],
																						@"Music from listeners like you",
																						nil] 
													forKeys:[NSArray arrayWithObjects:@"title", @"url", @"description", nil]]];
		}

		if([stations count])
			[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Network Stations", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		[stations release];
		
		if([_recent count] && [_username isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]]) {
			stations = [[NSMutableArray alloc] init];
			for(int x=0; x<[_recent count]; x++) {
				NSMutableString* stationTitle = [NSMutableString stringWithString:[[_recent objectAtIndex:x] objectForKey:@"name"]];
				[stationTitle replaceOccurrencesOfString:[NSString stringWithFormat:@"%@’s", _username] withString:@"My" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [stationTitle length])];
				NSRange range = [[[_recent objectAtIndex:x] objectForKey:@"url"] rangeOfString:@"/tag/"];
				if(range.location != NSNotFound) {
					NSString *tag = [[[[_recent objectAtIndex:x] objectForKey:@"url"] substringFromIndex:range.location + 5] unURLEscape];
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:stationTitle, [NSString stringWithFormat:@"Playing just '%@'", tag], [[_recent objectAtIndex:x] objectForKey:@"url"],nil] forKeys:[NSArray arrayWithObjects:@"title", @"description", @"url",nil]]];
				} else {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:stationTitle, [[_recent objectAtIndex:x] objectForKey:@"url"],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
				}
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
	if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]] && [[[_data objectAtIndex:section] objectForKey:@"stations"] isKindOfClass:[NSArray class]])
		return [[[_data objectAtIndex:section] objectForKey:@"stations"] count];
	else
		return 1;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]] && [[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] isKindOfClass:[NSArray class]])
		return 52;
	else
		return 70;
}
-(void)playRadioStation:(NSString *)url {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:url animated:YES];
	}
}
- (void)_search:(NSTimer *)timer {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *query = [timer userInfo];
	NSString *station = [[LastFMService sharedInstance] searchForStation:query];
	if(station) {
		NSLog(@"Station: %@", station);
		[self playRadioStation:station];
	} else {
		NSDictionary *profile = [[LastFMService sharedInstance] profileForUser:query authenticated:NO];
		if(profile) {
			station = [NSString stringWithFormat:@"lastfm://user/%@/personal", query];
			NSLog(@"Station: %@", station);
			[self playRadioStation:station];
		} else {
			UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Station Not Found" message:@"Unable to find a station matching this search.  Please enter a different artist or genre." delegate:[UIApplication sharedApplication].delegate cancelButtonTitle:NSLocalizedString(@"OK", @"OK") otherButtonTitles:nil] autorelease];
			[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
		}
	}
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	[pool release];
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]] && [[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] isKindOfClass:[NSArray class]]) {
		NSString *station = [[[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] objectAtIndex:[indexPath row]] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
		if([station hasPrefix:@"lastfm://"])
			[self playRadioStation:station];
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"debug"]) {
		DebugViewController *controller = [[DebugViewController alloc] initWithNibName:@"DebugView" bundle:nil];
		[self.navigationController pushViewController:controller animated:YES];
		[controller release];
	}
	[self.tableView reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	if([[_data objectAtIndex:[newIndexPath section]] isKindOfClass:[NSDictionary class]] && [[[_data objectAtIndex:[newIndexPath section]] objectForKey:@"stations"] isKindOfClass:[NSString class]])
		return;
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
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]] && [[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] isKindOfClass:[NSArray class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell.textLabel.text = [[[stations objectAtIndex:[indexPath row]] objectForKey:@"title"] capitalizedString];
		cell.detailTextLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"description"];
		if([[[stations objectAtIndex:[indexPath row]] objectForKey:@"url"] isEqualToString:@"tags"])
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		UITableViewCell *hintCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"hintCell"] autorelease];
		hintCell.backgroundView = [[[UIView alloc] init] autorelease];
		hintCell.backgroundColor = [UIColor clearColor];
		hintCell.selectionStyle = UITableViewCellSelectionStyleNone;
		hintCell.textLabel.textColor = [UIColor colorWithRed:(76.0f / 255.0f) green:(86.0f / 255.0f) blue:(108.0f / 255.0f) alpha:1.0];
		hintCell.textLabel.shadowColor = [UIColor whiteColor];
		hintCell.textLabel.shadowOffset = CGSizeMake(0.0, 1.0);
		hintCell.textLabel.font = [UIFont systemFontOfSize:14];
		hintCell.textLabel.numberOfLines = 0;
		//hintCell.textLabel.textAlignment = UITextAlignmentCenter;
		hintCell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
		hintCell.textLabel.text = [NSString stringWithFormat:@"\
Last.fm Radio is a subscription service. You have a free trial of %@ tracks.\n\n\
Type an artist or genre to start listening.", [[NSUserDefaults standardUserDefaults] objectForKey:@"trial_playsleft"]];
		return hintCell;
	} else {
		cell.textLabel.text = @"Debug";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	
	if(cell.accessoryType == UITableViewCellAccessoryNone) {
		UIImage *img = [UIImage imageNamed:@"radiostarter.png"];
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
	[_stations release];
}
@end
