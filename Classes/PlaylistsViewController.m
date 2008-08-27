/* PlaylistsViewController.m - Display Last.fm user playlists
 * CopyrightableView (C) 2008 Sam Steele
 *
 * This file is partableView of MobileLastFM.
 *
 * MobileLastFM is free software; you can redistribute itableView and/or modify
 * itableView under the terms of the GNU General Public License version 2
 * as published by the Free Software Foundation.
 *
 * MobileLastFM is distributed in the hope thatableView itableView will be useful,
 * butableView WITHOUtableView ANY WARRANTY; withoutableView even the implied warranty of
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

@synthesize delegate;

- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)bundle {
	if(self = [super initWithNibName:nibName bundle:bundle]) {
		_data = [[[LastFMService sharedInstance] playlistsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] retain];
		if(!_data)
			_data = [[NSMutableArray alloc] init];
		_newPlaylist = nil;
	}
	return self;
}
- (void)_keyboardWillAppear:(NSNotification *)notification {
	CGRect frame = _tableView.frame;
	CGRect keyboardFrame;
	[[notification.userInfo objectForKey:UIKeyboardBoundsUserInfoKey] getValue:&keyboardFrame];
	frame.size.height -= keyboardFrame.size.height;
	_tableView.frame = frame;
}
- (void)_keyboardWillDisappear:(NSNotification *)notification {
	CGRect frame = _tableView.frame;
	CGRect keyboardFrame;
	[[notification.userInfo objectForKey:UIKeyboardBoundsUserInfoKey] getValue:&keyboardFrame];
	frame.size.height += keyboardFrame.size.height;
	_tableView.frame = frame;
}
- (void)_doneButtonPressed:(id)sender {
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(_addButtonPressed:)] autorelease];
	[_data insertObject:[NSDictionary dictionaryWithObjectsAndKeys:_newPlaylist.text,@"title",nil] atIndex:0];
	[_tableView beginUpdates];
	[_tableView setEditing:NO animated:YES];
	[_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:NO];
	[_tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:NO];
	[_tableView endUpdates];
	[_newPlaylist resignFirstResponder];
	[_newPlaylist removeFromSuperview];
	[_newPlaylist release];
	_newPlaylist = nil;
	_tableView.scrollEnabled = YES;
	//TODO: Create the new playlist here when web service becomes available
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
		[_tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
	[_tableView setEditing:YES animated:YES];
	[_tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:YES];
	_tableView.scrollEnabled = NO;
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
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_keyboardWillAppear:) name:UIKeyboardDidShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_keyboardWillDisappear:) name:UIKeyboardWillHideNotification object:nil];
	_newPlaylist = nil;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableViewableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableViewableView numberOfRowsInSection:(NSInteger)section {
	return _tableView.editing?[_data count]+1:[_data count];
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
		cell.text = [[_data objectAtIndex:tableView.editing?[indexPath row]-1:[indexPath row]] objectForKey:@"title"];
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
