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
	if (self = [super init]) {
		self.title = username;
		_username = [username retain];
		/*NSDictionary *profile = [[LastFMService sharedInstance] profileForUser:_username];
		if(profile) {
			NSMutableString *url = [NSMutableString stringWithString:[profile objectForKey:@"avatar"]];
			[url replaceOccurrencesOfString:@"/160/" withString:@"/50/" options:NSLiteralSearch range:NSMakeRange(0, [url length])];
			NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:url]
																								cachePolicy:NSURLRequestUseProtocolCachePolicy
																						timeoutInterval:30.0];
			
			NSData *theResponseData;
			NSURLResponse *theResponse = NULL;
			NSError *theError = NULL;
			
			if([(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection] && !shouldUseCache(CACHE_FILE(@"Profiles",([NSString stringWithFormat:@"%@.jpg", _username])), 3600)) {
				theResponseData = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&theError];
				[theResponseData writeToFile:CACHE_FILE(@"Profiles",([NSString stringWithFormat:@"%@.jpg", _username])) atomically: YES];
			}
			
			int usernameWidth = [_username sizeWithFont:[UIFont boldSystemFontOfSize: 18]].width;
			if(usernameWidth > 200) usernameWidth = 200;
			
			UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0,0,usernameWidth + 36, 32)];
			header.backgroundColor = [UIColor clearColor];
			
			UIImageView *avatar = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:CACHE_FILE(@"Profiles",([NSString stringWithFormat:@"%@.jpg", _username]))]];
			[avatar setFrame:CGRectMake(0, 0, 32, 32)];
			[header addSubview:avatar];
			[avatar release];
			
			UILabel *name = [[UILabel alloc] initWithFrame:CGRectMake(36,0,usernameWidth,32)];
			name.font = [UIFont boldSystemFontOfSize: 18];
			name.textColor = [UIColor whiteColor];
			name.backgroundColor = [UIColor clearColor];
			name.textAlignment = UITextAlignmentCenter;
			name.text = _username;
			name.adjustsFontSizeToFitWidth = YES;
			name.minimumFontSize = 12;
			[header addSubview: name];
			[name release];
			self.navigationItem.titleView = header;
			[header release];*/
		
		_data = [[NSMutableArray alloc] init];
			
		if([_username isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]]) {
			[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Start a new station", @"Start a new station"), @"title",
												@"search", @"type",
												nil]];
		}
		if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue])
			[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Personal Radio", @"Listen to Personal Radio"), @"title",
												@"station", @"type",
												[NSString stringWithFormat:@"lastfm://user/%@/personal",[_username URLEscaped]], @"url",
												nil]];
		[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: 
											NSLocalizedString(@"Recommended Radio", @"Listen to Recommendation Radio"), @"title",
											@"station", @"type",
											[NSString stringWithFormat:@"lastfm://user/%@/recommended/100",[_username URLEscaped]], @"url",
											nil]];
		if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue])
			[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Loved Tracks Radio", @"Listen to Loved Tracks"), @"title",
											@"station", @"type", 
											[NSString stringWithFormat:@"lastfm://user/%@/loved",[_username URLEscaped]], @"url",
											nil]];
		[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Neighbour Radio", @"Listen to My Neighborhood"), @"title",
											@"station", @"type", 
											[NSString stringWithFormat:@"lastfm://user/%@/neighbours",[_username URLEscaped]], @"url",
											nil]];
		
		NSArray *playlists = [[LastFMService sharedInstance] playlistsForUser:_username];
		if([playlists count] == 1) {
			[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"My Playlist", @"Listen to My Playlist"), @"title",
												@"station", @"type", 
												[NSString stringWithFormat:@"lastfm://user/%@/playlist",[_username URLEscaped]], @"url",
												nil]];
		} else if([playlists count] > 1) {
			[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Playlists", @"Show User Playlists"), @"title",
												@"playlists", @"type",
												nil]];
		}
		if([_username isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]]) {
			[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Recent Stations", @"Recent Radio Stations chart title"), @"title",
												@"recent", @"type",
												nil]];
		}
		[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Charts", @"Show User Charts"), @"title",
											@"charts", @"type",
											nil]];
		[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Events", @"Show User Events"), @"title",
											@"events", @"type",
											nil]];
		
		NSArray *tags = [[LastFMService sharedInstance] tagsForUser:_username];
		if([tags count]) {
			[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Tags", @"Show User Tags"), @"title",
												@"tags", @"type",
												nil]];
		}
		/*for(NSDictionary *tag in tags) {
			if([[tag objectForKey:@"count"] intValue] >= 5)
				[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: [NSString stringWithFormat:@"%@ tag radio", [tag objectForKey:@"name"]], @"title",
													@"station", @"type", 
													[NSString stringWithFormat:@"lastfm://usertags/%@/%@",[_username URLEscaped],[[tag objectForKey:@"name"] URLEscaped]], @"url",
													nil]];
		}*/
		[_data addObject:[NSDictionary dictionaryWithObjectsAndKeys: NSLocalizedString(@"Friends", @"Browse Friends"), @"title",
											@"friends", @"type",
											nil]];
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
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 46;
}
-(void)playRadioStation:(NSString *)url {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:url animated:YES];
	}
}
-(void)_rowSelected:(NSTimer *)timer {
	NSIndexPath *newIndexPath = [timer userInfo];
	UINavigationController *controller = nil;
	
	if([[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"type"] isEqualToString:@"station"]) {
		[self playRadioStation:[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"url"]];
	} else if([[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"type"] isEqualToString:@"friends"]) {
		controller = [[FriendsViewController alloc] initWithUsername:_username];
	} else if([[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"type"] isEqualToString:@"search"]) {
		controller = [[[SearchViewController alloc] initWithNibName:@"SearchView" bundle:nil] retain];
	} else if([[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"type"] isEqualToString:@"charts"]) {
		controller = [[ChartsListViewController alloc] initWithUsername:_username];
	} else if([[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"type"] isEqualToString:@"recent"]) {
		controller = [[RecentRadioViewController alloc] init];
	} else if([[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"type"] isEqualToString:@"tags"]) {
		controller = [[TagRadioViewController alloc] initWithUsername:_username];
	} else if([[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"type"] isEqualToString:@"events"]) {
		controller = [[EventsListViewController alloc] initWithUsername:_username];
	} else if([[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"type"] isEqualToString:@"playlists"]) {
		controller = [[PlaylistsViewController alloc] initWithUsername:_username];
	}
	if(controller) {
		[self.navigationController pushViewController:controller animated:YES];
		[controller release];
	}
	[[self tableView] reloadData];
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
	
	cell.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"title"];
	[cell showProgress: NO];
	if(![[[_data objectAtIndex:[indexPath row]] objectForKey:@"type"] isEqualToString:@"station"])
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	else
		if([[LastFMRadio sharedInstance] state] != RADIO_IDLE &&
			 [[[LastFMRadio sharedInstance] stationURL] isEqualToString:[[_data objectAtIndex:[indexPath row]] objectForKey:@"url"]]) {
			[self showNowPlayingButton:NO];
			UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 64, 30)];
			[btn setBackgroundImage:[UIImage imageNamed:@"now_playing_list.png"] forState:UIControlStateNormal];
			btn.adjustsImageWhenHighlighted = YES;
			[btn addTarget:self action:@selector(nowPlayingButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
			cell.accessoryView = btn;
			[btn release];
		} else {
			UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
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
	[_username release];
	[_data release];
}
@end
