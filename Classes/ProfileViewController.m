/* ProfileViewController.m - Display a Last.fm profile
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

#import "ProfileViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "ArtistViewController.h"
#import "UIApplication+openURLWithWarning.h"

@implementation ProfileViewController
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_username = [username retain];
		_recentTracks = [[NSMutableArray arrayWithArray:[[LastFMService sharedInstance] recentlyPlayedTracksForUser:username]] retain];
		_weeklyArtists = [[[LastFMService sharedInstance] weeklyArtistsForUser:username] retain];
		self.title = @"Last.fm";
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
	//self.tableView.backgroundColor = [UIColor blackColor];
	
	UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width, 45)];
	//bar.barStyle = UIBarStyleBlackTranslucent;
	//bar.backgroundColor = [UIColor grayColor];
	bar.placeholder = @"Search Last.fm";
	self.tableView.tableHeaderView = bar;
	[bar release];
}
- (void)rebuildMenu {
	if(_data)
		[_data release];
	
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	
	[sections addObject:@"profile"];
	
	NSMutableArray *stations;
	
	if([_weeklyArtists count]) {
		stations = [[NSMutableArray alloc] init];
		for(int x=0; x<[_weeklyArtists count] && x < 3; x++) {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"], [[_weeklyArtists objectAtIndex:x] objectForKey:@"image"],
																															 [NSString stringWithFormat:@"lastfm-artist://%@", [[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
		}
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Top Weekly Artists", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		[stations release];
	}
	
	if([_recentTracks count]) {
		stations = [[NSMutableArray alloc] init];
		for(int x=0; x<[_recentTracks count] && x < 10; x++) {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_recentTracks objectAtIndex:x] objectForKey:@"name"], [[_recentTracks objectAtIndex:x] objectForKey:@"artist"], [[_recentTracks objectAtIndex:x] objectForKey:@"image"],
																															 [NSString stringWithFormat:@"lastfm-track://%@/_/%@", [[[_recentTracks objectAtIndex:x] objectForKey:@"artist"] URLEscaped], [[[_recentTracks objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"artist", @"image", @"url",nil]]];
		}
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Recently Listened", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		[stations release];
	}
	
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
	if(section > 0)
		return [((NSDictionary *)[_data objectAtIndex:section]) objectForKey:@"title"];
	else
		return nil;
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
	ArtworkCell *cell = [[[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"TrackCell"] autorelease];
	
	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
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

	} else if([indexPath section] == 0) {
		ArtworkCell *profilecell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"ProfileCell"];
		if(profilecell == nil) {
			NSDictionary *profile = [[LastFMService sharedInstance] profileForUser:_username];
			profilecell = [[[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"ProfileCell"] autorelease];
			profilecell.selectionStyle = UITableViewCellSelectionStyleNone;
			profilecell.imageURL = [profile objectForKey:@"avatar"];
			profilecell.shouldRoundTop = YES;
			profilecell.shouldRoundBottom = YES;
			if([[profile objectForKey:@"realname"] length])
				profilecell.title.text = [profile objectForKey:@"realname"];
			else
				profilecell.title.text = _username;
			
			NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
			[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
			profilecell.subtitle.text = [NSString stringWithFormat:@"%@ %@ %@",[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[profile objectForKey:@"playcount"] intValue]]], NSLocalizedString(@"plays since", @"x plays since join date"), [profile objectForKey:@"registered"]];
			[numberFormatter release];
		}
		return profilecell;
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
	[_recentTracks release];
	[_weeklyArtists release];
	[_data release];
}
@end
