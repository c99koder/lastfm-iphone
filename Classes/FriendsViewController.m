/* FriendsViewController.m - Display Last.fm friends list
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

#import "FriendsViewController.h"
#import "ProfileViewController.h"
#import "ArtworkCell.h"
#import "UIViewController+NowPlayingButton.h"
#import "MobileLastFMApplicationDelegate.h"
#import "UITableViewCell+ProgressIndicator.h"
#include "version.h"

int usernameSort(id friend1, id friend2, void *reverse) {
	if ((int *)reverse == NO) {
		return [[friend2 objectForKey:@"username"] localizedCaseInsensitiveCompare:[friend1 objectForKey:@"username"]];
	}
	return [[friend1 objectForKey:@"username"] localizedCaseInsensitiveCompare:[friend2 objectForKey:@"username"]];
}

@implementation FriendsViewController
@synthesize delegate;

- (id)initWithUsername:(NSString *)username {
	UInt32 reverseSort = NO;
	
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_data = [[[[LastFMService sharedInstance] friendsOfUser:username] sortedArrayUsingFunction:usernameSort context:&reverseSort] retain];
		if([LastFMService sharedInstance].error) {
			[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
			[self release];
			return nil;
		}
		if(![_data count]) {
			[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) displayError:NSLocalizedString(@"FRIENDS_EMPTY", @"No friends") withTitle:NSLocalizedString(@"FRIENDS_EMPTY_TITLE", @"No friends title")];
			[self release];
			return nil;
		}
		self.title = [NSString stringWithFormat:NSLocalizedString(@"%@'s Friends", @"Friends view title"), username];
		UIBarButtonItem *backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Friends", @"Friends back button title") style:UIBarButtonItemStylePlain target:nil action:nil];
		self.navigationItem.backBarButtonItem = backBarButtonItem;
		[backBarButtonItem release];
		_username = [username retain];
	}
	return self;
}
- (void)cancelButtonPressed:(id)sender {
	[delegate friendsViewControllerDidCancel:self];
}
- (void)viewDidLoad {
	self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if(delegate) {
		UIBarButtonItem *cancel = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"Cancel")
																															 style:UIBarButtonItemStylePlain
																															target:self
																															action:@selector(cancelButtonPressed:)];
		self.navigationItem.rightBarButtonItem = cancel;
		[cancel release];
	} else {
		[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	}
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 52;
}
- (void)_showProfile:(NSTimer *)timer {
	NSIndexPath *newIndexPath = timer.userInfo;
	if(delegate) {
		[delegate friendsViewController:self didSelectFriend:[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"username"]];
	} else {
		ProfileViewController *profile = [[ProfileViewController alloc] initWithUsername:[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"username"]];
		[self.navigationController pushViewController:profile animated:YES];
		[profile release];
		[[self.tableView cellForRowAtIndexPath:newIndexPath] showProgress:NO];
	}
}	
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[[tableView cellForRowAtIndexPath:newIndexPath] showProgress:YES];
	[NSTimer scheduledTimerWithTimeInterval:0.5
																	 target:self
																 selector:@selector(_showProfile:)
																 userInfo:newIndexPath
																	repeats:NO];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	ArtworkCell *cell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"username"]];
	if (cell == nil)
		cell = [[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"username"]];
	cell.title.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"username"];
	cell.title.backgroundColor = [UIColor whiteColor];
	cell.title.opaque = YES;
	cell.subtitle.backgroundColor = [UIColor whiteColor];
	cell.subtitle.opaque = YES;
	cell.imageURL = [[_data objectAtIndex:[indexPath row]] objectForKey:@"image"];
	cell.shouldCacheArtwork = YES;
	if(!delegate)
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
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
