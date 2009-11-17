/* SearchViewController.m - Search view controller
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
- (void)_showProfile:(NSString *)text {
	UITabBarController *tabBarController = [((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) profileViewForUser:text];
	[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:tabBarController animated:YES];
}	
- (void)_searchThread:(NSString *)text {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *results = nil;
	[text retain];
	
	switch(_searchType.selectedSegmentIndex) {
		case 0:
			results = [[LastFMService sharedInstance] searchForArtist:text];
			break;
		case 1:
			results = [[LastFMService sharedInstance] searchForTag:text];
			break;
		case 2:
		{
				NSDictionary *profile = [[LastFMService sharedInstance] profileForUser:text];
				if(profile) {
					[self performSelectorOnMainThread:@selector(_showProfile:) withObject:text waitUntilDone:YES];
				} else {
					[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) displayError:NSLocalizedString(@"ERROR_NOSUCHUSER", @"User not found error") withTitle:NSLocalizedString(@"ERROR_NOSUCHUSER_TITLE", @"User not found error title")];
					_searchBar.text = @"";
				}
				results = nil;
		}
		break;
	}

	[text release];
	
	if(![[NSThread currentThread] isCancelled]) {
		[_data release];
		if([results count]) {
			_data = [[NSMutableArray alloc] init];
			for(NSDictionary *result in results) {
				if([result objectForKey:@"streamable"] == nil || [[result objectForKey:@"streamable"] intValue]) {
					NSMutableDictionary *entry = [[NSMutableDictionary alloc] initWithDictionary:result];
					if([[result objectForKey:@"streamable"] intValue]) {
						NSArray *artists = [[LastFMService sharedInstance] artistsSimilarTo:[result objectForKey:@"name"]];
						if([artists count] >= 3) {
							NSString *subtitle = [[NSString alloc] initWithFormat:@"%@, %@, %@", [[artists objectAtIndex:0] objectForKey:@"name"], 
																		[[artists objectAtIndex:1] objectForKey:@"name"], [[artists objectAtIndex:2] objectForKey:@"name"]];
							[entry setObject:subtitle forKey:@"subtitle"];
							[subtitle release];
						}
					} else {
						NSArray *artists = [[LastFMService sharedInstance] topArtistsForTag:[result objectForKey:@"name"]];
						if([artists count] >= 3) {
							NSString *subtitle = [[NSString alloc] initWithFormat:@"%@, %@, %@", [[artists objectAtIndex:0] objectForKey:@"name"], 
																		[[artists objectAtIndex:1] objectForKey:@"name"], [[artists objectAtIndex:2] objectForKey:@"name"]];
							[entry setObject:subtitle forKey:@"subtitle"];
							[subtitle release];
						}
					}
					[(NSMutableArray *)_data addObject:entry];
					[entry release];
					
					if([_data count] >= 4)
						break;
				}
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
		[self loadContentForCells:[_table visibleCells]];
	}
	[_searchThread release];
	_searchThread = nil;
	[pool release];
}
-(void)_search:(NSTimer *)timer {
	[_searchThread cancel];
	_searchThread = [[NSThread alloc] initWithTarget:self selector:@selector(_searchThread:) object:[timer userInfo]];
	[_searchThread start];
	[_searchTimer release];
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
	_table.frame = CGRectMake(0,44,320,156);
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
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
		_searchTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0
																										 target:self
																									 selector:@selector(_search:)
																									 userInfo:_searchBar.text
																										repeats:NO] retain];
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
	return 58;
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
	ArtworkCell *cell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"]];
	if (cell == nil) {
		cell = [[[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"]] autorelease];
	}
	cell.title.text = [[[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"] stringByAppendingString:@" Radio"] capitalizedString];
	cell.subtitle.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"subtitle"];
	if([[_data objectAtIndex:[indexPath row]] objectForKey:@"image"])
		cell.imageURL = [[_data objectAtIndex:[indexPath row]] objectForKey:@"image"];
	else
		[cell hideArtwork:YES];
	cell.shouldCacheArtwork = YES;
	
	NSString *radioURL = [NSString stringWithFormat:@"lastfm://artist/%@/similarartists",
												[[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"] URLEscaped]];
	if([[LastFMRadio sharedInstance] state] != RADIO_IDLE &&
		 [[[LastFMRadio sharedInstance] stationURL] isEqualToString:radioURL]) {
		[self showNowPlayingButton:NO];
		UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 64, 30)];
		[btn setBackgroundImage:[UIImage imageNamed:@"now_playing_list.png"] forState:UIControlStateNormal];
		btn.adjustsImageWhenHighlighted = YES;
		[btn addTarget:self action:@selector(nowPlayingButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
		cell.accessoryView = btn;
		[btn release];
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	} else {
		[cell addStreamIcon];
	}
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
