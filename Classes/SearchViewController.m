/* SearchViewController.m - Search view controller
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

#import "SearchViewController.h"
#import "ProfileViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+URLEscaped.h"
#import "UITableViewCell+ProgressIndicator.h"

@implementation SearchViewController
- (void)viewDidLoad {
	for(UIView *view in [_searchBar subviews]) {
		if([view isKindOfClass:[UITextField class]]) {
			((UITextField *)view).autocorrectionType = UITextAutocorrectionTypeNo;
			((UITextField *)view).keyboardAppearance = UIKeyboardAppearanceAlert;
		}
	}
	_searchBar.placeholder = NSLocalizedString(@"Enter an artist name", @"Artist search placeholder text");
	_searchType.selectedSegmentIndex = 0;
	_searchType.tintColor = [UIColor grayColor];
	self.hidesBottomBarWhenPushed = YES;
}
- (IBAction)backButtonPressed:(id)sender {
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController popViewControllerAnimated:YES];
}
- (void)_searchThread:(NSString *)text {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *results = nil;
	
	switch(_searchType.selectedSegmentIndex) {
		case 0:
			results = [[LastFMService sharedInstance] searchForArtist:text];
			break;
		case 1:
			results = [[LastFMService sharedInstance] searchForTag:text];
			break;
		case 2:
			results = nil;
			break;
	}
	
	if(![[NSThread currentThread] isCancelled]) {
		[_data release];
		if([results count]) {
			_data = [[NSMutableArray alloc] init];
			for(NSDictionary *result in results) {
				if([result objectForKey:@"streamable"] == nil || [[result objectForKey:@"streamable"] intValue])
					[(NSMutableArray *)_data addObject:[result objectForKey:@"name"]];
			}
			if([_data count] < 1) {
				[_data release];
				_data = nil;
			}
		} else {
			_data = nil;
		}
		
		[_table reloadData];
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	}
	[_searchThread release];
	_searchThread = nil;
	[pool release];
}
-(void)_search:(NSTimer *)timer {
	[_searchThread cancel];
	_searchThread = [[NSThread alloc] initWithTarget:self selector:@selector(_searchThread:) object:[timer userInfo]];
	[_searchThread start];
	_searchTimer = nil;
}
-(IBAction)searchTypeChanged:(id)sender {
	if(_searchTimer) {
		[_searchTimer invalidate];
		[_searchTimer release];
		_searchTimer = nil;
	}
	if(_data) {
		[_data release];
		_data = nil;
		[_table reloadData];
	}
	_searchBar.text = @"";
	switch(_searchType.selectedSegmentIndex) {
		case 0:
			_searchBar.placeholder = NSLocalizedString(@"Enter an artist name", @"Artist search placeholder text");
			break;
		case 1:
			_searchBar.placeholder = NSLocalizedString(@"Enter a tag", @"Tag search placeholder text");
			break;
		case 2:
			_searchBar.placeholder = NSLocalizedString(@"Enter a username and press 'Search'", @"User search placeholder text");
			break;
	}
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	if(_searchType.selectedSegmentIndex < 2) {
		if(_searchTimer) {
			[_searchTimer invalidate];
			[_searchTimer release];
			_searchTimer = nil;
		}
		if([searchText length]) {
			[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
			_searchTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0
																				 target:self
																			 selector:@selector(_search:)
																			 userInfo:searchText
																				repeats:NO] retain];
		}
	}
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[_searchBar becomeFirstResponder];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	_table.frame = CGRectMake(0,44,320,205);
	[_table reloadData];
}
- (void)viewWillDisappear:(BOOL)animated {
	_searchBar.text = @"";
	[_searchBar resignFirstResponder];
	_table.frame = CGRectMake(0,44,320,372);
	[_table reloadData];
}
-(IBAction)searchBarSearchButtonClicked:(id)sender {
	if(_searchType.selectedSegmentIndex == 2) {
		UITabBarController *tabBarController = [((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) profileViewForUser:_searchBar.text];
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:tabBarController animated:YES];
		[tabBarController release];
	} else {
		[self searchBar:_searchBar textDidChange:_searchBar.text];
	}
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return _data?[_data count]:0;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 46;
}
- (void)_rowSelected:(NSTimer *)timer {
	NSIndexPath *newIndexPath = [timer userInfo];
	NSString *url = nil;
	
	switch(_searchType.selectedSegmentIndex) {
		case 0:
			url = [NSString stringWithFormat:@"lastfm://artist/%@/similarartists", [[_data objectAtIndex:[newIndexPath row]] URLEscaped]];
			break;
		case 1:
			url = [NSString stringWithFormat:@"lastfm://globaltags/%@", [[_data objectAtIndex:[newIndexPath row]] URLEscaped]];
			break;
	}
	
	if(url) {
		if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
			[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
		} else {
			[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:url animated:YES];
		}
	}
	[_table reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
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
	
	cell.text = [_data objectAtIndex:[indexPath row]];
	[cell showProgress: NO];
	UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
	img.opaque = YES;
	cell.accessoryView = img;
	[img release];
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_data release];
}
@end
