/* FriendsViewController.m - Display Last.fm friends list
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

#import "FriendsViewController.h"
#import "ProfileViewController.h"
#import "RadioListViewController.h"
#import "ArtworkCell.h"
#import "UIViewController+NowPlayingButton.h"
#import "MobileLastFMApplicationDelegate.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "HomeViewController.h"
#import "UIColor+LastFMColors.h"
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
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_username = [username retain];
		self.title = @"Friends";
		UIBarButtonItem *backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Friends", @"Friends back button title") style:UIBarButtonItemStylePlain target:nil action:nil];
		self.navigationItem.backBarButtonItem = backBarButtonItem;
		[backBarButtonItem release];
		NSMutableArray *frames = [[NSMutableArray alloc] init];
		int i;
		for(i=1; i<=11; i++) {
			NSString *filename = [NSString stringWithFormat:@"icon_eq_f%02i.png", i];
			[frames addObject:[UIImage imageNamed:filename]];
		}
		_eqFrames = frames;
	}
	return self;
}
- (void)cancelButtonPressed:(id)sender {
	[delegate friendsViewControllerDidCancel:self];
}
- (void)viewDidLoad {
	UInt32 reverseSort = NO;
	UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width, 45)];
	bar.placeholder = @"Search Friends";
	self.tableView.tableHeaderView = bar;
	self.tableView.backgroundColor = [UIColor lfmTableBackgroundColor];

	UISearchDisplayController *searchController = [[UISearchDisplayController alloc] initWithSearchBar:bar contentsController:self];
	searchController.delegate = self;
	searchController.searchResultsDataSource = self;
	searchController.searchResultsDelegate = self;
	[bar release];
	
	_data = [[[[LastFMService sharedInstance] friendsOfUser:_username] sortedArrayUsingFunction:usernameSort context:&reverseSort] retain];
	if([LastFMService sharedInstance].error) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
		[self release];
		return;
	}
	if(![_data count]) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) displayError:NSLocalizedString(@"FRIENDS_EMPTY", @"No friends") withTitle:NSLocalizedString(@"FRIENDS_EMPTY_TITLE", @"No friends title")];
		[self release];
		return;
	}
	if(!delegate)
		_friendsListeningNow = [[[LastFMService sharedInstance] nowListeningFriendsOfUser:_username] retain];
	
	if([_friendsListeningNow count]) {
		UISegmentedControl *toggle = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Listening Now", @"All Friends", nil]];
		toggle.segmentedControlStyle = UISegmentedControlStyleBar;
		toggle.selectedSegmentIndex = 0;
		CGRect frame = toggle.frame;
		frame.size.width = self.view.frame.size.width - 20;
		toggle.frame = frame;
		[toggle addTarget:self
							 action:@selector(viewWillAppear:)
		 forControlEvents:UIControlEventValueChanged];
		self.navigationItem.titleView = toggle;
        [toggle release];
	}		
}
- (void)viewDidUnload {
	[super viewDidUnload];
	NSLog(@"Releasing friends data");
	[_data release];
	_data = nil;
	[_friendsListeningNow release];
	_friendsListeningNow = nil;
}	
- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)query {
	[_searchResults release];
	_searchResults = nil;
	if([query length]) {
		_searchResults = [[NSMutableArray alloc] init];
		query = [query lowercaseString];
		for (NSDictionary *friend in _data) {
			if ([[[friend objectForKey:@"username"] lowercaseString] rangeOfString:query].location == 0 || 
					([friend objectForKey:@"realname"] && [[[friend objectForKey:@"realname"] lowercaseString] rangeOfString:query].location == 0)) {
				[_searchResults addObject:friend];
			}
		} 
	}
	return YES;
}
- (void)searchDisplayControllerDidEndSearch:(UISearchDisplayController *)controller {
	[_searchResults release];
	_searchResults = nil;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[_searchResults release];
	_searchResults = nil;
	if(delegate) {
		self.navigationItem.titleView = nil;
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
	[self.tableView setContentOffset:CGPointMake(0,self.tableView.tableHeaderView.frame.size.height)];
	[self.tableView.tableHeaderView resignFirstResponder];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return nil;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;

	if(_searchResults)
		return [_searchResults count];
	else if(toggle == nil || toggle.selectedSegmentIndex == 1)
		return [_data count];
	else
		return [_friendsListeningNow count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 52;
}
- (void)_showProfile:(NSTimer *)timer {
	UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;
	NSIndexPath *newIndexPath = timer.userInfo;
	NSArray *source = _data;
	if(_searchResults) {
		source = _searchResults;
	} else if(toggle != nil && toggle.selectedSegmentIndex == 0) {
		source = _friendsListeningNow;
	}
	if(delegate) {
		[delegate friendsViewController:self didSelectFriend:[[source objectAtIndex:[newIndexPath row]] objectForKey:@"username"]];
	} else {
		ProfileViewController *profile = [[ProfileViewController alloc] initWithUsername:[[source objectAtIndex:[newIndexPath row]] objectForKey:@"username"]];
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
	UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;
	ArtworkCell *cell;
	if(_searchResults) {
		cell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[_searchResults objectAtIndex:[indexPath row]] objectForKey:@"username"]];
		if (cell == nil)
			cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[[_searchResults objectAtIndex:[indexPath row]] objectForKey:@"username"]] autorelease];
	} else if(toggle != nil && toggle.selectedSegmentIndex == 0) {
		cell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[_friendsListeningNow objectAtIndex:[indexPath row]] objectForKey:@"username"]];
		if (cell == nil)
			cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[[_friendsListeningNow objectAtIndex:[indexPath row]] objectForKey:@"username"]] autorelease];
	} else {
		cell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"username"]];
		if (cell == nil)
			cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"username"]] autorelease];
	}
	
	if(_searchResults) {
		cell.title.text = [[_searchResults objectAtIndex:[indexPath row]] objectForKey:@"username"];
		cell.title.textColor = [UIColor blackColor];
		cell.title.font = [UIFont boldSystemFontOfSize:16];
		cell.title.backgroundColor = [UIColor clearColor];
		cell.title.opaque = YES;
		cell.detailTextLabel.text = [[_searchResults objectAtIndex:[indexPath row]] objectForKey:@"realname"];
		cell.detailTextLabel.textColor = [UIColor blackColor];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
		cell.detailTextLabel.textAlignment = UITextAlignmentLeft;
		cell.subtitle.text = @"";
		cell.subtitle.backgroundColor = [UIColor clearColor];
		cell.subtitle.opaque = YES;
		[cell.subtitle.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
		cell.shouldCacheArtwork = YES;
		cell.placeholder = @"noimage_user.png";
		cell.imageURL = [[_searchResults objectAtIndex:[indexPath row]] objectForKey:@"image"];
		if(!delegate)
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		else
			cell.accessoryType = UITableViewCellAccessoryNone;
	} else if(toggle == nil || toggle.selectedSegmentIndex == 1) {
		cell.title.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"username"];
		cell.title.textColor = [UIColor blackColor];
		cell.title.font = [UIFont boldSystemFontOfSize:16];
		cell.title.backgroundColor = [UIColor clearColor];
		cell.title.opaque = YES;
		cell.detailTextLabel.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"realname"];
		cell.detailTextLabel.textColor = [UIColor blackColor];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
		cell.detailTextLabel.textAlignment = UITextAlignmentLeft;
		cell.subtitle.text = @"";
		cell.subtitle.backgroundColor = [UIColor clearColor];
		cell.subtitle.opaque = YES;
		[cell.subtitle.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
		cell.shouldCacheArtwork = YES;
		cell.placeholder = @"noimage_user.png";
		cell.imageURL = [[_data objectAtIndex:[indexPath row]] objectForKey:@"image"];
		if(!delegate)
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		else
			cell.accessoryType = UITableViewCellAccessoryNone;
	} else if(toggle.selectedSegmentIndex == 0) {
		cell.title.text = [[_friendsListeningNow objectAtIndex:[indexPath row]] objectForKey:@"username"];
		cell.title.textColor = [UIColor blackColor];
		cell.title.font = [UIFont boldSystemFontOfSize:16];
		cell.title.backgroundColor = [UIColor clearColor];
		cell.title.opaque = YES;
		cell.detailTextLabel.text = [[_friendsListeningNow objectAtIndex:[indexPath row]] objectForKey:@"realname"];
		cell.detailTextLabel.textColor = [UIColor blackColor];
		cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
		cell.detailTextLabel.textAlignment = UITextAlignmentLeft;
		cell.subtitle.text = [NSString stringWithFormat:@"    %@ - %@", [[_friendsListeningNow objectAtIndex:[indexPath row]] objectForKey:@"artist"],
													[[_friendsListeningNow objectAtIndex:[indexPath row]] objectForKey:@"title"]];
		UIImageView *eq = [[[UIImageView alloc] initWithFrame:CGRectMake(0,4,12,12)] autorelease];
		eq.animationImages = _eqFrames;
		eq.animationDuration = 2;
		[eq startAnimating];
		[cell.subtitle.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
		[cell.subtitle addSubview:eq];
		cell.subtitle.backgroundColor = [UIColor clearColor];
		cell.subtitle.opaque = YES;
		cell.shouldCacheArtwork = YES;
		cell.placeholder = @"noimage_user.png";
		cell.imageURL = [[_friendsListeningNow objectAtIndex:[indexPath row]] objectForKey:@"image"];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_eqFrames release];
	[_username release];
	[_friendsListeningNow release];
	[_searchResults release];
	[_data release];
}
@end
