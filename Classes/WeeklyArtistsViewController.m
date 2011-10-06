/* WeeklyArtistsViewController.m - List of weekly artists
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
#import "WeeklyArtistsViewController.h"
#import "UIColor+LastFMColors.h"

@implementation WeeklyArtistsViewController

- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		NSDictionary* res = [[LastFMService sharedInstance] weeklyArtistsForUser:username];
		_data = [[res objectForKey: @"artists"] retain];
		_from = [[NSDate dateWithTimeIntervalSince1970:[[res objectForKey: @"from" ] intValue]] retain];
		_to = [[NSDate dateWithTimeIntervalSince1970: [[res objectForKey: @"to" ] intValue]] retain];
		_images = [[NSMutableDictionary alloc] init];
		for(int x = 0; x < [_data count]; x++) {
			NSDictionary *info = [[LastFMService sharedInstance] metadataForArtist:[[_data objectAtIndex:x] objectForKey:@"name"] inLanguage:@"en"];
			if([info objectForKey:@"image"])
				[_images setObject:[info objectForKey:@"image"] forKey:[[_data objectAtIndex:x] objectForKey:@"name"]];
		}
		self.title = @"Top Weekly Artists";
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

	int playcount = [[[_data objectAtIndex:[indexPath row]] objectForKey:@"playcount"] intValue ];
	cell.subtitle.text = [NSString stringWithFormat: @"%i play%s", playcount, playcount > 1 ? "s" : "" ];
	cell.placeholder = @"noimage_artist.png";
	cell.imageURL = [_images objectForKey:[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"]];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  return cell;
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	NSString *url = [NSString stringWithFormat:@"lastfm-artist://%@", [[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"] URLEscaped]];
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
- (void)viewDidLoad {
	[self.tableView setBackgroundColor:[UIColor lfmTableBackgroundColor]];
}
- (void)viewDidUnload {
	// Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
	// For example: self.myOutlet = nil;
}
- (void)dealloc {
	[_data release];
	[_images release];
	[_to release];
	[_from release];
  [super dealloc];
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if( section != 0 ) return 0.0f;
	return 40.0f;
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if( section != 0 ) return nil;
	
	UILabel* label = [[[UILabel alloc] initWithFrame:CGRectMake(20, 6, 300, 40)] autorelease];
	label.textColor = [UIColor colorWithRed:(76.0f / 255.0f) green:(86.0f / 255.0f) blue:(108.0f / 255.0f) alpha:1.0];
	label.backgroundColor = [UIColor clearColor];
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	[formatter setTimeStyle: NSDateFormatterMediumStyle];
	[formatter setDateFormat: @"d MMM"];
	label.text = [NSString stringWithFormat: @"For the week of %@ - %@", [formatter stringFromDate:_from], [formatter stringFromDate: _to ] ];
	[formatter release];
	label.textAlignment = UITextAlignmentCenter;
	label.font = [UIFont systemFontOfSize:14];
	return label;
}
@end

