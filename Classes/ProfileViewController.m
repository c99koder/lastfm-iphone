/* ProfileViewController.m - Display a Last.fm profile
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

#import "ProfileViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "ArtistViewController.h"
#import "UIApplication+openURLWithWarning.h"

@implementation ProfileViewController
- (void)_refresh {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *tracks = [[NSMutableArray arrayWithArray:[[LastFMService sharedInstance] recentlyPlayedTracksForUser:_username]] retain];
	NSArray *artists = [[[LastFMService sharedInstance] weeklyArtistsForUser:_username] retain];
	NSMutableDictionary *images = [[NSMutableDictionary alloc] init];
	for(int x = 0; x < [artists count] && x < 3; x++) {
		NSDictionary *info = [[LastFMService sharedInstance] metadataForArtist:[[artists objectAtIndex:x] objectForKey:@"name"] inLanguage:@"en"];
		[images setObject:[info objectForKey:@"image"] forKey:[[artists objectAtIndex:x] objectForKey:@"name"]];
	}
	friendsCount = [[[LastFMService sharedInstance] friendsOfUser:_username] count];
	NSArray *friendsListeningNow = nil;
	if(friendsCount > 0)
		friendsListeningNow = [[[LastFMService sharedInstance] nowListeningFriendsOfUser:_username] retain];	
	if(![[NSThread currentThread] isCancelled]) {
		@synchronized(self) {
			[_recentTracks release];
			_recentTracks = tracks;
			[_weeklyArtists release];
			_weeklyArtists = artists;
			[_weeklyArtistImages release];
			_weeklyArtistImages = images;
			[_friendsListeningNow release];
			_friendsListeningNow = friendsListeningNow;
			[_refreshThread release];
			_refreshThread = nil;
		}
		[self performSelectorOnMainThread:@selector(rebuildMenu) withObject:nil waitUntilDone:YES];
	} else {
		[tracks release];
		[artists release];
		[images release];
	}
	[pool release];
}
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_username = [username retain];
		self.title = @"Profile";
	}
	return self;
}
- (void)viewDidUnload {
	[super viewDidUnload];
	NSLog(@"Releasing profile data");
	[_recentTracks release];
	_recentTracks = nil;
	[_weeklyArtists release];
	_weeklyArtists = nil;
	[_weeklyArtistImages release];
	_weeklyArtistImages = nil;
	[_data release];
	_data = nil;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	
	if(_refreshThread) {
		[_refreshThread cancel];
		[_refreshThread release];
	}
	
	_refreshThread = [[NSThread alloc] initWithTarget:self selector:@selector(_refresh) object:nil];
	[_refreshThread start];
}
- (void)viewDidLoad {
	[LastFMService sharedInstance].cacheOnly = YES;
	[_recentTracks release];
	_recentTracks = [[NSMutableArray arrayWithArray:[[LastFMService sharedInstance] recentlyPlayedTracksForUser:_username]] retain];
	[_weeklyArtists release];
	_weeklyArtists = [[[LastFMService sharedInstance] weeklyArtistsForUser:_username] retain];
	[_weeklyArtistImages release];
	_weeklyArtistImages = [[NSMutableDictionary alloc] init];
	for(int x = 0; x < [_weeklyArtists count] && x < 3; x++) {
		NSDictionary *info = [[LastFMService sharedInstance] metadataForArtist:[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"] inLanguage:@"en"];
		[_weeklyArtistImages setObject:[info objectForKey:@"image"] forKey:[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"]];
	}
	friendsCount = [[[LastFMService sharedInstance] friendsOfUser:_username] count];
	_friendsListeningNow = nil;
	if(friendsCount > 0)
		_friendsListeningNow = [[[LastFMService sharedInstance] nowListeningFriendsOfUser:_username] retain];	
	[LastFMService sharedInstance].cacheOnly = NO;
	[self rebuildMenu];
}
- (void)rebuildMenu {
	@synchronized(self) {
		if(_data)
			[_data release];
		
		NSMutableArray *sections = [[NSMutableArray alloc] init];
		
		[sections addObject:@"profile"];
		
		NSMutableArray *stations;
		
		if([_weeklyArtists count]) {
			stations = [[NSMutableArray alloc] init];
			for(int x=0; x<[_weeklyArtists count] && x < 3; x++) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"], /*[[_weeklyArtists objectAtIndex:x] objectForKey:@"image"],*/
																																 [_weeklyArtistImages objectForKey:[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"]],
																																 [NSString stringWithFormat:@"lastfm-artist://%@", [[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
			}
			[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Top Weekly Artists", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
			[stations release];
		}
		
		if([_recentTracks count]) {
			stations = [[NSMutableArray alloc] init];
			for(int x=0; x<[_recentTracks count] && x < 5; x++) {
				if(![[[_recentTracks objectAtIndex:x] objectForKey:@"nowplaying"] isEqualToString:@"true"])
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_recentTracks objectAtIndex:x] objectForKey:@"name"], [[_recentTracks objectAtIndex:x] objectForKey:@"artist"], [[_recentTracks objectAtIndex:x] objectForKey:@"image"],
																																 [NSString stringWithFormat:@"lastfm-track://%@/%@", [[[_recentTracks objectAtIndex:x] objectForKey:@"artist"] URLEscaped], [[[_recentTracks objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"artist", @"image", @"url",nil]]];
			}
			[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Recently Listened", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
			[stations release];
		}

		if([_friendsListeningNow count]) {
			stations = [[NSMutableArray alloc] init];
			for(int x=0; x<[_friendsListeningNow count] && x < 3; x++) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_friendsListeningNow objectAtIndex:x] objectForKey:@"username"], [[_friendsListeningNow objectAtIndex:x] objectForKey:@"artist"], [[_friendsListeningNow objectAtIndex:x] objectForKey:@"image"], [[_friendsListeningNow objectAtIndex:x] objectForKey:@"title"], [[_friendsListeningNow objectAtIndex:x] objectForKey:@"realname"],
																																	 [NSString stringWithFormat:@"lastfm-user://%@", [[[_friendsListeningNow objectAtIndex:x] objectForKey:@"username"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"artist", @"image", @"track", @"realname", @"url",nil]]];
			}
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"More", @"-", [NSString stringWithFormat:@"lastfm-friends://%@", [_username URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
			[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Friends Listening Now", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
			[stations release];
		} else if(friendsCount) {
			[sections addObject:@"myfriends"];
		}
		
		if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username])
			[sections addObject:@"logout"];
		
		_data = sections;
		
		[self.tableView reloadData];
		[self loadContentForCells:[self.tableView visibleCells]];
	}
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [_data count];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]])
		return [[[_data objectAtIndex:section] objectForKey:@"stations"] count];
	else
		return 1;
}
/*- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	if([self tableView:tableView numberOfRowsInSection:section] > 1)
		return 10;
	else
		return 0;
}*/
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]])
		return [((NSDictionary *)[_data objectAtIndex:section]) objectForKey:@"title"];
	else
		return nil;
}
/*- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	return [[[UIView alloc] init] autorelease];
}*/
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 52;
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSString *station = [[[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] objectAtIndex:[indexPath row]] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
		[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:station]];
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"myfriends"]) {
		[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:[NSString stringWithFormat:@"lastfm-friends://%@", [_username URLEscaped]]]];
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"logout"]) {
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) logoutButtonPressed:nil];
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
	ArtworkCell *cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"TrackCell"] autorelease];
	
	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell.title.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"]) {
			if([[stations objectAtIndex:[indexPath row]] objectForKey:@"track"]) {
				cell.subtitle.text = [NSString stringWithFormat:@"%@ - %@", [[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"], [[stations objectAtIndex:[indexPath row]] objectForKey:@"track"]];
			} else {
				cell.subtitle.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"];
			}
		}
		cell.shouldCacheArtwork = YES;
		if(![[[stations objectAtIndex:[indexPath row]] objectForKey:@"image"] isEqualToString:@"-"])
			cell.imageURL = [[stations objectAtIndex:[indexPath row]] objectForKey:@"image"];
		else
			[cell hideArtwork:YES];
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"realname"]) {
			cell.detailTextLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"realname"];
			cell.detailTextLabel.textColor = [UIColor blackColor];
			cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
			cell.detailTextLabel.textAlignment = UITextAlignmentLeft;
		}	else {
			cell.detailTextLabel.text = @"";
		}
		cell.shouldFillHeight = YES;
		if([indexPath row] == 0)
			cell.shouldRoundTop = YES;
		if([indexPath row] == [self tableView:tableView numberOfRowsInSection:[indexPath section]]-1)
			cell.shouldRoundBottom = YES;

	} else if([indexPath section] == 0) {
		ArtworkCell *profilecell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"ProfileCell"];
		if(profilecell == nil) {
			NSDictionary *profile = [[LastFMService sharedInstance] profileForUser:_username];
			profilecell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ProfileCell"] autorelease];
			profilecell.selectionStyle = UITableViewCellSelectionStyleNone;
			profilecell.imageURL = [profile objectForKey:@"avatar"];
			profilecell.shouldRoundTop = YES;
			profilecell.shouldRoundBottom = YES;
			if([[profile objectForKey:@"realname"] length])
				profilecell.title.text = [profile objectForKey:@"realname"];
			else
				profilecell.title.text = _username;
			
			NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
			[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
			profilecell.subtitle.text = [NSString stringWithFormat:@"%@ %@ %@",[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[profile objectForKey:@"playcount"] intValue]]], NSLocalizedString(@"plays since", @"x plays since join date"), [profile objectForKey:@"registered"]];
			[numberFormatter release];
		}
		return profilecell;
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"logout"]) {
		UITableViewCell *logoutcell = [[[UITableViewCell alloc] initWithFrame:CGRectZero] autorelease];
		logoutcell.textLabel.text = @"Logout";
		logoutcell.textLabel.textColor = [UIColor whiteColor];
		logoutcell.textLabel.textAlignment = UITextAlignmentCenter;
		logoutcell.backgroundColor = [UIColor redColor];
		return logoutcell;
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"myfriends"]) {
		UITableViewCell *friendscell = [[[UITableViewCell alloc] initWithFrame:CGRectZero] autorelease];
		friendscell.textLabel.text = [NSString stringWithFormat:@"My Friends (%i)", friendsCount];
		friendscell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return friendscell;
	}
	
	if([indexPath section] > 0 && cell.accessoryType == UITableViewCellAccessoryNone) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	if(_refreshThread) {
		[_refreshThread cancel];
		[_refreshThread release];
	}
	[_username release];
	[_recentTracks release];
	[_weeklyArtists release];
	[_weeklyArtistImages release];
	[_friendsListeningNow release];
	[_data release];
}
@end
