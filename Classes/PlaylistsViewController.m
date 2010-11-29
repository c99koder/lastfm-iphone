/* PlaylistsViewController.m - Display Last.fm user playlists
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

#import "PlaylistsViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "NSString+URLEscaped.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"

@implementation PlaylistsViewController

@synthesize delegate;

- (id)init {
	if(self = [super initWithStyle:UITableViewStylePlain]) {
		_data = [[[LastFMService sharedInstance] playlistsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] retain];
		if(!_data)
			_data = [[NSMutableArray alloc] init];
		_newPlaylist = nil;
	}
	return self;
}
- (void)_doneButtonPressed:(id)sender {
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(_addButtonPressed:)] autorelease];
	NSDictionary *playlist = [[LastFMService sharedInstance] createPlaylist:_newPlaylist.text];
	if(playlist) {
		[_data insertObject:playlist atIndex:0];
		[self.tableView beginUpdates];
		[self.tableView setEditing:NO animated:YES];
		[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:NO];
		[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:NO];
		[self.tableView endUpdates];
	} else {
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) reportError:[LastFMService sharedInstance].error];
		[self.tableView setEditing:NO animated:YES];
		[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:NO];
	}
	[_newPlaylist resignFirstResponder];
	[_newPlaylist removeFromSuperview];
	[_newPlaylist release];
	_newPlaylist = nil;
	self.tableView.scrollEnabled = YES;
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return NO;
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[self _doneButtonPressed:textField];
	return NO;
}
- (void)_addButtonPressed:(id)sender {
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(_doneButtonPressed:)] autorelease];
	if([_data count])
		[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
	[self.tableView setEditing:YES animated:YES];
	[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:YES];
	self.tableView.scrollEnabled = NO;
}
- (void)_cancelButtonPressed:(id)sender {
	[delegate playlistViewControllerDidCancel];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[delegate playlistViewControllerDidSelectPlaylist:[[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"id"] intValue]];
}
- (void)viewDidLoad {
	self.title = NSLocalizedString(@"Select a Playlist", @"Playlist selector title");
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(_cancelButtonPressed:)] autorelease];
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(_addButtonPressed:)] autorelease];
	_newPlaylist = nil;
}
- (NSInteger)numberOfSectionsIntableView:(UITableView *)tableViewableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableViewableView numberOfRowsInSection:(NSInteger)section {
	return self.tableView.editing?[_data count]+1:[_data count];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:tableView.editing?@"EditingCell":@"BasicCell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:tableView.editing?@"EditingCell":@"BasicCell"] autorelease];
	}
	if(tableView.editing && [indexPath row] == 0) {
		if(!_newPlaylist) {
			_newPlaylist = [[UITextField alloc] initWithFrame:CGRectMake(10,10,300,52)];
			_newPlaylist.delegate = self;
			_newPlaylist.font = [UIFont boldSystemFontOfSize:20];
			_newPlaylist.autocorrectionType = UITextAutocorrectionTypeNo;
			_newPlaylist.autocapitalizationType = UITextAutocapitalizationTypeNone;
			_newPlaylist.returnKeyType = UIReturnKeyDone;
			[_newPlaylist becomeFirstResponder];
			[cell.contentView addSubview:_newPlaylist];
		}
	} else {
		cell.textLabel.text = [[_data objectAtIndex:tableView.editing?[indexPath row]-1:[indexPath row]] objectForKey:@"title"];
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[_data release];
	[_newPlaylist release];
	self.delegate = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}
@end
