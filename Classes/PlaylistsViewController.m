/* PlaylistsViewController.m - Display Last.fm user playlists
 * Copyright (C) 2008 Sam Steele
 *
 * This file is part of MobileLastFM.
 *
 * MobileLastFM is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2
 * as published by the Free Software Foundation.
 *
 * MobileLastFM is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 */

#import "PlaylistsViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "NSString+URLEscaped.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"

@implementation PlaylistsViewController

- (id)initWithUsername:(NSString *)username {
	if (self = [super init]) {
		self.title = [NSString stringWithFormat:NSLocalizedString(@"%@'s Playlists", @"Playlists view title"), username];
		_username = [username retain];
		NSArray *playlists = [[LastFMService sharedInstance] playlistsForUser:_username];
		_data = [[NSMutableArray alloc] init];
		for(NSDictionary *playlist in playlists) {
			if(![[playlist objectForKey:@"streamable"] isEqualToString:@"0"])
				[_data addObject:playlist];
		}
	}
	
	if(![_data count]) {
		[self release];
		return nil;
	} else {
		return self;
	}
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
	[self playRadioStation:[NSString stringWithFormat:@"lastfm://playlist/%@/shuffle", [[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"id"] URLEscaped]]];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"BasicCell"];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"BasicCell"];
	}
	cell.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"title"];
	[cell showProgress: NO];
	if([[LastFMRadio sharedInstance] state] != RADIO_IDLE &&
		 [[[LastFMRadio sharedInstance] stationURL] isEqualToString:[NSString stringWithFormat:@"lastfm://playlist/%@/shuffle", [[[_data objectAtIndex:[indexPath row]] objectForKey:@"id"] URLEscaped]]]) {
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
