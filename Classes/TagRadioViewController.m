/* TagRadioViewController.m - Display Last.fm tag radio list
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

#import "TagRadioViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "NSString+URLEscaped.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"

@implementation TagRadioViewController

- (id)initWithUsername:(NSString *)username {
	int i;
	
	if (self = [super init]) {
		self.title = [NSString stringWithFormat:NSLocalizedString(@"%@'s Tags", @"Tags view title"), username];
		_username = [username retain];
		NSArray *tags = [[LastFMService sharedInstance] tagsForUser:_username];
		_data = [[NSMutableArray alloc] init];
		for(i=0; i<[tags count]; i++) {
			[_data addObject: [[tags objectAtIndex: i] objectForKey:@"name"]];
		}
		if(![_data count]) {
			[self release];
			return nil;
		}
	}
	
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
-(void)_playRadio:(NSTimer *)timer {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:[timer userInfo] animated:YES];
		[[self tableView] reloadData];
	}
}
-(void)playRadioStation:(NSString *)url {
	//Hack to make the loading throbber appear before we block
	[NSTimer scheduledTimerWithTimeInterval:0.5
																	 target:self
																 selector:@selector(_playRadio:)
																 userInfo:url
																	repeats:NO];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[[tableView cellForRowAtIndexPath:newIndexPath] showProgress: YES];
	[self playRadioStation:[NSString stringWithFormat:@"lastfm://usertags/%@/%@", _username, [[_data objectAtIndex:[newIndexPath row]] URLEscaped]]];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BasicCell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"BasicCell"] autorelease];
	}
	cell.textLabel.text = [_data objectAtIndex:[indexPath row]];
	[cell showProgress: NO];
	if([[LastFMRadio sharedInstance] state] != RADIO_IDLE &&
		 [[[LastFMRadio sharedInstance] stationURL] isEqualToString:[NSString stringWithFormat:@"lastfm://globaltags/%@", [cell.textLabel.text URLEscaped]]]) {
		[self showNowPlayingButton:NO];
		UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 64, 30)];
		[btn setBackgroundImage:[UIImage imageNamed:@"now_playing_list.png"] forState:UIControlStateNormal];
		btn.adjustsImageWhenHighlighted = YES;
		[btn addTarget:self action:@selector(nowPlayingButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
		cell.accessoryView = btn;
		[btn release];
	} else {
		UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
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
	[_data release];
}
@end
