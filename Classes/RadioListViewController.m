/* RadioListViewController.m - Display a Last.fm radio list
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

#import "RadioListViewController.h"
#import "SearchViewController.h"
#import "TagRadioViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import </usr/include/objc/objc-class.h>
#import "DebugViewController.h"
#import "MobileLastFMApplicationDelegate.h"

@implementation RadioListViewController
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		self.title = [username retain];
		_username = [username retain];
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	
	[self rebuildMenu];
}
- (void)viewDidLoad {
	self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	self.tableView.sectionHeaderHeight = 0;
	self.tableView.sectionFooterHeight = 0;
	self.tableView.backgroundColor = [UIColor blackColor];

	if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"removePlaylists"] isEqualToString:@"YES"]) {
		[_playlists release];
		_playlists = [[NSMutableArray alloc] init];
		NSArray *playlists = [[LastFMService sharedInstance] playlistsForUser:_username];
		for(NSDictionary *playlist in playlists) {
			if(![[playlist objectForKey:@"streamable"] isEqualToString:@"0"])
				[_playlists addObject:playlist];
		}
	}
	if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username]) {
		_commonArtists = [[[[LastFMService sharedInstance] compareArtistsOfUser:_username withUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] objectForKey:@"artists"] retain];
		
		if(![_commonArtists isKindOfClass:[NSArray class]]) {
			[_commonArtists release];
			_commonArtists = nil;
		}
	} else {
		[[LastFMRadio sharedInstance] fetchRecentURLs];
	}
}
- (void)rebuildMenu {
	if(_data)
		[_data release];
	
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username]) {
		[_recent release];
		_recent = [[[LastFMRadio sharedInstance] recentURLs] retain];
	}
	
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	
	[sections addObject:@"start"];
	
	NSMutableArray *stations = [[NSMutableArray alloc] init];
	[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Library", @"My Library station"),[NSString stringWithFormat:@"lastfm://user/%@/personal", _username],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
	[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"Recommended by Last.fm", @"Recommended by Last.fm station"),[NSString stringWithFormat:@"lastfm://user/%@/recommended", _username],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
	
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"showneighborradio"] isEqualToString:@"YES"])
		[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Neighborhood Radio", @"Neighborhood Radio station"),[NSString stringWithFormat:@"lastfm://user/%@/neighbours", _username],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];

	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue]) {
		if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"removeLovedTracks"] isEqualToString:@"YES"])
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"Loved Tracks", @"Loved Tracks station"),[NSString stringWithFormat:@"lastfm://user/%@/loved", _username],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
		if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"removeUserTags"] isEqualToString:@"YES"])
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"Tag Radio", @"Tag Radio station"),@"tags",nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
	}
	
	NSString *heading;
	
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username])
		heading = NSLocalizedString(@"My Stations", @"My Stations heading");
	else
		heading = [NSString stringWithFormat:@"%@'s Stations", _username];
	
	[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:heading, stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
	
	if([_commonArtists count]) {
		stations = [[NSMutableArray alloc] init];
		for(int x=0; x<[_commonArtists count]; x++) {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[_commonArtists objectAtIndex:x],
																															 [NSString stringWithFormat:@"lastfm://artist/%@/similarartists", [[_commonArtists objectAtIndex:x] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
		}
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"Common Artists", @"Common Artists heading"), stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
	}
	
	if([_recent count]) {
		stations = [[NSMutableArray alloc] init];
		for(int x=0; x<[_recent count]; x++) {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_recent objectAtIndex:x] objectForKey:@"name"],[[_recent objectAtIndex:x] objectForKey:@"url"],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
		}
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"Recent Stations", @"Recent Stations heading"), stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
	}

	if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"removePlaylists"] isEqualToString:@"YES"] && [_playlists count]) {
		stations = [[NSMutableArray alloc] init];
		for(int x=0; x<[_playlists count]; x++) {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_playlists objectAtIndex:x] objectForKey:@"title"],
																															 [NSString stringWithFormat:@"lastfm://playlist/%@/shuffle", [[_playlists objectAtIndex:x] objectForKey:@"id"]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"url",nil]]];
		}
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:NSLocalizedString(@"My Playlists", @"My Playlists heading"), stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
	}
	
#ifndef DISTRIBUTION	
	[sections addObject:@"debug"];
#endif
	
	_data = [sections retain];

	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [_data count];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]])
		return [[[_data objectAtIndex:section] objectForKey:@"stations"] count] + 1;
	else
		return 1;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if([self tableView:tableView numberOfRowsInSection:section])
		return 10;
	else
		return 0;
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	return [[[UIView alloc] init] autorelease];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([indexPath section] == 0)
		return [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username]?46:67;
	else if([indexPath row] > 0 || [indexPath section] == 5)
		return 46;
	else
		return 29;
}
-(void)playRadioStation:(NSString *)url {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:url animated:YES];
	}
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSString *station = [[[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] objectAtIndex:[indexPath row]-1] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
		if([station hasPrefix:@"lastfm://"])
			[self playRadioStation:station];
		else if([station isEqualToString:@"tags"]) {
			TagRadioViewController *tags = [[TagRadioViewController alloc] initWithUsername:_username];
			if(tags) {
				[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:tags animated:YES];
				[tags release];
			}
		}
	} else if([[_data objectAtIndex:[indexPath section]] isEqualToString:@"start"]) {
		if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username]) {
			SearchViewController *controller = [[SearchViewController alloc] initWithNibName:@"SearchView" bundle:nil];
			[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:controller animated:YES];
			[controller release];
		}
	} else if([[_data objectAtIndex:[indexPath section]] isEqualToString:@"debug"]) {
		DebugViewController *controller = [[DebugViewController alloc] initWithNibName:@"DebugView" bundle:nil];
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:controller animated:YES];
		[controller release];
	}
	[self.tableView reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
	if([newIndexPath row] > 0) {
		[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	}
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.1];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero] autorelease];
	UIImageView *v;
	UILabel *l;
	UIImageView *img;

	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		if([indexPath row] == 0) {
			v = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"rounded_table_cell_header.png"]];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.backgroundView = v;
			l = [[UILabel alloc] initWithFrame:v.frame];
			l.textAlignment = UITextAlignmentCenter;
			l.font = [UIFont boldSystemFontOfSize:14];
			l.textColor = [UIColor whiteColor];
			l.shadowColor = [UIColor blackColor];
			l.shadowOffset = CGSizeMake(0,-1);
			l.backgroundColor = [UIColor clearColor];
			l.text = [((NSDictionary *)[_data objectAtIndex:[indexPath section]]) objectForKey:@"title"];
			[cell.contentView addSubview:l];
			[l release];
			[v release];
		} else {
			NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
			cell.text = [[stations objectAtIndex:[indexPath row]-1] objectForKey:@"title"];
			if([[[stations objectAtIndex:[indexPath row]-1] objectForKey:@"url"] isEqualToString:@"tags"])
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
	} else if([indexPath section] == 0) {
		if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username] && [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username]) {
			v = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"rounded_table_cell_button.png"]];
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			cell.backgroundView = v;
			[v release];
			l = [[UILabel alloc] initWithFrame:CGRectMake(10,0,280,46)];
			l.textAlignment = UITextAlignmentLeft;
			l.font = [UIFont boldSystemFontOfSize:18];
			l.textColor = [UIColor whiteColor];
			l.shadowColor = [UIColor blackColor];
			l.shadowOffset = CGSizeMake(0,-1);
			l.backgroundColor = [UIColor clearColor];
			l.text = NSLocalizedString(@"Start a New Station", @"Start a New Station button");
			l.textAlignment = UITextAlignmentCenter;
			[cell.contentView addSubview:l];
			[l release];
		} else {
			ArtworkCell *profilecell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"ProfileCell"];
			if(profilecell == nil) {
				NSDictionary *profile = [[LastFMService sharedInstance] profileForUser:_username];
				profilecell = [[[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"ProfileCell"] autorelease];
				profilecell.selectionStyle = UITableViewCellSelectionStyleNone;
				v = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"profile_panel.png"]];
				profilecell.backgroundView = v;
				[v release];
				profilecell.imageURL = [profile objectForKey:@"avatar"];
				UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(70,6,230,18)];
				l.backgroundColor = [UIColor clearColor];
				l.textColor = [UIColor whiteColor];
				if([[profile objectForKey:@"realname"] length])
					l.text = [profile objectForKey:@"realname"];
				else
					l.text = _username;
				l.font = [UIFont boldSystemFontOfSize: 16];
				[profilecell.contentView addSubview: l];
				[l release];
				
				NSMutableString *line2 = [NSMutableString string];
				if([[profile objectForKey:@"age"] length])
					[line2 appendFormat:@"%@, ", [profile objectForKey:@"age"]];
				[line2 appendFormat:@"%@", [profile objectForKey:@"country"]];
				l = [[UILabel alloc] initWithFrame:CGRectMake(70,26,230,16)];
				l.backgroundColor = [UIColor clearColor];
				l.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
				l.text = line2;
				l.font = [UIFont systemFontOfSize: 14];
				[profilecell.contentView addSubview: l];
				[l release];
				
				NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
				[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
				l = [[UILabel alloc] initWithFrame:CGRectMake(70,44,230,16)];
				l.backgroundColor = [UIColor clearColor];
				l.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
				l.text = [NSString stringWithFormat:@"%@ %@ %@",[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[profile objectForKey:@"playcount"] intValue]]], NSLocalizedString(@"plays since", @"x plays since join date"), [profile objectForKey:@"registered"]];
				l.font = [UIFont systemFontOfSize: 14];
				[profilecell.contentView addSubview: l];
				[l release];
				[numberFormatter release];
			}
			return profilecell;
		}
	} else {
		cell.text = @"Debug";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	
	if([indexPath row] > 0 && cell.accessoryType == UITableViewCellAccessoryNone) {
		img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
		img.opaque = YES;
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
	[_loadingThread cancel];
	[_username release];
	[_playlists release];
	[_recent release];
	[_data release];
}
@end
