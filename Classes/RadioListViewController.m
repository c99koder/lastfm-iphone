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
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		self.title = [username retain];
		_username = [username retain];
		[[LastFMRadio sharedInstance] fetchRecentURLs];
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.tableView setContentOffset:CGPointMake(0,self.tableView.tableHeaderView.frame.size.height)];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	
	[self rebuildMenu];
}
- (void)viewDidLoad {
	/*self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	self.tableView.sectionHeaderHeight = 0;
	self.tableView.sectionFooterHeight = 0;
	self.tableView.backgroundColor = [UIColor blackColor];*/
	UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width, 45)];
	bar.placeholder = @"Search Radio";
	self.tableView.tableHeaderView = bar;
	[bar release];
}
- (void)rebuildMenu {
	if(_data)
		[_data release];
	
	[_recent release];
	_recent = [[[LastFMRadio sharedInstance] recentURLs] retain];
	
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	
	NSMutableArray *stations = [[NSMutableArray alloc] init];
	[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Library", @"My Library station"),[NSString stringWithFormat:@"lastfm://user/%@/personal", _username],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
	[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"Recommended by Last.fm", @"Recommended by Last.fm station"),[NSString stringWithFormat:@"lastfm://user/%@/recommended", _username],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
	[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Mix Radio", @"My Mix Radio"),[NSString stringWithFormat:@"lastfm://user/%@/mix", _username],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
	
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"showneighborradio"] isEqualToString:@"YES"])
		[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Neighborhood Radio", @"Neighborhood Radio station"),[NSString stringWithFormat:@"lastfm://user/%@/neighbours", _username],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];

	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue]) {
		if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"removeLovedTracks"] isEqualToString:@"YES"])
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"Loved Tracks", @"Loved Tracks station"),[NSString stringWithFormat:@"lastfm://user/%@/loved", _username],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
		if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"removeUserTags"] isEqualToString:@"YES"])
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"Tag Radio", @"Tag Radio station"),@"tags",nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
	}
	
	NSString *heading;
	
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username])
		heading = NSLocalizedString(@"My Stations", @"My Stations heading");
	else
		heading = [NSString stringWithFormat:@"%@'s Stations", _username];
	
	[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:heading, stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
	
	if([_recent count]) {
		stations = [[NSMutableArray alloc] init];
		for(int x=0; x<[_recent count]; x++) {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_recent objectAtIndex:x] objectForKey:@"name"],[[_recent objectAtIndex:x] objectForKey:@"url"],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
		}
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"Recent Stations", @"Recent Stations heading"), stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
	}
	
#ifndef DISTRIBUTION	
	[sections addObject:@"debug"];
#endif
	
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
				[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:tags animated:YES];
				[tags release];
			}
		}
	} else if([[_data objectAtIndex:[indexPath section]] isEqualToString:@"start"]) {
		if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username]) {
			SearchViewController *controller = [[SearchViewController alloc] initWithNibName:@"SearchView" bundle:nil];
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:controller animated:YES];
			[controller release];
		}
	} else if([[_data objectAtIndex:[indexPath section]] isEqualToString:@"debug"]) {
		DebugViewController *controller = [[DebugViewController alloc] initWithNibName:@"DebugView" bundle:nil];
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:controller animated:YES];
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
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero] autorelease];

	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		if([[[stations objectAtIndex:[indexPath row]] objectForKey:@"url"] isEqualToString:@"tags"])
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else {
		cell.text = @"Debug";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	
	if(cell.accessoryType == UITableViewCellAccessoryNone) {
		UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
		img.opaque = YES;
		cell.accessoryView = img;
		[img release];
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_username release];
	[_recent release];
	[_data release];
}
@end
