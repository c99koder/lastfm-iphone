/* ProfileViewController.m - Display a Last.fm profile
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

#import "ProfileViewController.h"
#import "FriendsViewController.h"
#import "ChartsViewController.h"
#import "SearchViewController.h"
#import "TagRadioViewController.h"
#import "PlaylistsViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"

@implementation ProfileViewController
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_username = [username retain];
		self.title = _username;
	}
	return self;
}
- (void)viewDidLoad {
	self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
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
	return 3;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 46;
}
-(void)_rowSelected:(NSTimer *)timer {
	NSIndexPath *newIndexPath = [timer userInfo];
	UINavigationController *controller = nil;
	
	switch([newIndexPath row]) {
		case 0:
			controller = [[ChartsListViewController alloc] initWithUsername:_username];
			break;
		case 1:
			controller = [[TagRadioViewController alloc] initWithUsername:_username];
			break;
		case 2:
			controller = [[FriendsViewController alloc] initWithUsername:_username];
			break;
	}
	
	if(controller) {
		[self.navigationController pushViewController:controller animated:YES];
		[controller release];
	}
	[[self tableView] reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
	//Hack to make the loading throbber appear before we block
	[NSTimer scheduledTimerWithTimeInterval:0.5
																	 target:self
																 selector:@selector(_rowSelected:)
																 userInfo:newIndexPath
																	repeats:NO];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"simplecell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"simplecell"] autorelease];
	}

	switch([indexPath row]) {
		case 0:
			cell.text = @"Charts";
			break;
		case 1:
			cell.text = @"Tags";
			break;
		case 2:
			cell.text = @"Friends";
			break;
	}
	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_username release];
}
@end
