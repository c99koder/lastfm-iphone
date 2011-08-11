/* RecentTracksViewController.m - List of recent tracks
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

#import "LastFMService.h"
#import "ArtworkCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+LastFMTimeExtensions.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "UIApplication+openURLWithWarning.h"
#import "NSString+URLEscaped.h"
#import "RecentTracksViewController.h"

@implementation RecentTracksViewController

- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStylePlain]) {
		_data = [[[LastFMService sharedInstance] recentlyPlayedTracksForUser:username] retain];
		self.title = @"Recent Tracks";
	}
	return self;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 52;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	ArtworkCell *cell = (ArtworkCell*)[tableView dequeueReusableCellWithIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"uts"]];
	if (cell == nil) {
		cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"uts"]] autorelease];
	}
	[cell showProgress:NO];
	cell.title.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"name"];
	cell.subtitle.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"artist"];
	cell.detailAtBottom = YES;
	cell.detailTextLabel.textColor = [UIColor colorWithRed:36.0f/255 green:112.0f/255 blue:216.0f/255 alpha:1.0];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
	if([[[_data objectAtIndex:[indexPath row]] objectForKey:@"nowplaying"] isEqualToString:@"true"])
		cell.detailTextLabel.text = @"Now Playing ";
	else
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ ", [[[_data objectAtIndex:[indexPath row]] objectForKey:@"uts"] StringFromUTS]];
	cell.detailTextLabel.textAlignment = UITextAlignmentRight;
	cell.noArtwork = YES;
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  return cell;
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	NSString *url = [NSString stringWithFormat:@"lastfm-track://%@/%@", [[[_data objectAtIndex:[indexPath row]] objectForKey:@"artist"] URLEscaped], [[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"] URLEscaped]];
	[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:url]];
	[self.tableView reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.1];
}
- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc. that aren't in use.
}
- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}
- (void)dealloc {
	[_data release];
  [super dealloc];
}
@end

