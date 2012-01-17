/* ProfileViewController.m - Display a Last.fm profile
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

#import "ProfileViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "NSString+LastFMTimeExtensions.h"
#import "ArtworkCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "ArtistViewController.h"
#import "UIApplication+openURLWithWarning.h"
#import "UIColor+LastFMColors.h"
#import "EventDetailsViewController.h"

@implementation ProfileViewController
- (void)_refresh {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_loading = YES;
	NSDictionary *profile = [[[LastFMService sharedInstance] profileForUser:_username] retain];
	NSArray *tracks = [[NSMutableArray arrayWithArray:[[LastFMService sharedInstance] recentlyPlayedTracksForUser:_username]] retain];
	NSArray *artists = [[[[LastFMService sharedInstance] weeklyArtistsForUser:_username] objectForKey:@"artists"] retain];
	NSMutableDictionary *images = [[NSMutableDictionary alloc] init];
	for(int x = 0; x < [artists count] && x < 3; x++) {
		NSDictionary *info = [[LastFMService sharedInstance] metadataForArtist:[[artists objectAtIndex:x] objectForKey:@"name"] inLanguage:@"en"];
		if(info != nil && [info objectForKey:@"image"] != nil && [artists objectAtIndex:x] != nil && [[artists objectAtIndex:x] objectForKey:@"name"] != nil)
			[images setObject:[info objectForKey:@"image"] forKey:[[artists objectAtIndex:x] objectForKey:@"name"]];
	}
	friendsCount = [[[LastFMService sharedInstance] friendsOfUser:_username] count];
	NSArray *friendsListeningNow = nil;
	if(friendsCount > 0)
		friendsListeningNow = [[[LastFMService sharedInstance] nowListeningFriendsOfUser:_username] retain];
	NSArray *events = nil;
	if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username])
		events = [[[LastFMService sharedInstance] eventsForUser:_username] retain];
	_loading = NO;
	if(![[NSThread currentThread] isCancelled]) {
		@synchronized(self) {
			[_profile release];
			_profile = profile;
			[_recentTracks release];
			_recentTracks = tracks;
			[_weeklyArtists release];
			_weeklyArtists = artists;
			[_weeklyArtistImages release];
			_weeklyArtistImages = images;
			[_friendsListeningNow release];
			_friendsListeningNow = friendsListeningNow;
			[_events release];
			_events = events;
			[_refreshThread release];
			_refreshThread = nil;
		}
		[self performSelectorOnMainThread:@selector(rebuildMenu) withObject:nil waitUntilDone:YES];
	} else {
		[profile release];
		[tracks release];
		[artists release];
		[images release];
		[friendsListeningNow release];
		[events release];
	}
	[pool release];
}
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_username = [username retain];
		_profile = [[[LastFMService sharedInstance] profileForUser:_username] retain];
		self.title = @"Profile";
		self.tabBarItem.image = [UIImage imageNamed:@"tabbar_profile.png"];
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
- (void)viewDidUnload {
	[super viewDidUnload];
	NSLog(@"Releasing profile data");
	[_friendsListeningNow release];
	_friendsListeningNow = nil;
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
	self.tableView.backgroundColor = [UIColor lfmTableBackgroundColor];
	[LastFMService sharedInstance].cacheOnly = YES;
	[_recentTracks release];
	_recentTracks = [[NSMutableArray arrayWithArray:[[LastFMService sharedInstance] recentlyPlayedTracksForUser:_username]] retain];
	[_weeklyArtists release];
	_weeklyArtists = [[[[LastFMService sharedInstance] weeklyArtistsForUser:_username] objectForKey: @"artists"] retain];
	[_weeklyArtistImages release];
	_weeklyArtistImages = [[NSMutableDictionary alloc] init];
	for(int x = 0; x < [_weeklyArtists count] && x < 3; x++) {
		NSDictionary *info = [[LastFMService sharedInstance] metadataForArtist:[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"] inLanguage:@"en"];
		if([info objectForKey:@"image"])
			[_weeklyArtistImages setObject:[info objectForKey:@"image"] forKey:[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"]];
	}
	friendsCount = [[[LastFMService sharedInstance] friendsOfUser:_username] count];
	_friendsListeningNow = nil;
	if(friendsCount > 0)
		_friendsListeningNow = [[[LastFMService sharedInstance] nowListeningFriendsOfUser:_username] retain];	
	if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username])
		_events = [[[LastFMService sharedInstance] eventsForUser:_username] retain];
	[LastFMService sharedInstance].cacheOnly = NO;
	_loading = YES;
	[self rebuildMenu];
}
- (void)rebuildMenu {
	@synchronized(self) {
        if(_data) {
            [_data release];
            _data = nil;
        }
		
		NSMutableArray *sections = [[NSMutableArray alloc] init];
		
		[sections addObject:@"profile"];
		
		if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username] && ([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_expired"] isEqualToString:@"0"]))
			[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"",
																															 [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"Play %@'s Library", _username], [NSString stringWithFormat:@"lastfm://user/%@/personal", [_username URLEscaped]], nil]
																																																										 forKeys:[NSArray arrayWithObjects:@"title", @"url", nil]], nil]
																															 , nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		
		if([[_profile objectForKey:@"playcount"] isEqualToString:@"0"]) {
			[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Welcome To Last.fm", @"Welcome", nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		} else {
			NSMutableArray *stations;
			
			if([_weeklyArtists count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_weeklyArtists count] && x < 3; x++) {
					if([_weeklyArtistImages objectForKey:[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"]])
						[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"], /*[[_weeklyArtists objectAtIndex:x] objectForKey:@"image"],*/
																											[_weeklyArtistImages objectForKey:[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"]], 
																											@"noimage_artist.png",
																											[NSString stringWithFormat:@"lastfm-artist://%@", [[[_weeklyArtists objectAtIndex:x] objectForKey:@"name"] URLEscaped]],
																											[[_weeklyArtists objectAtIndex:x] objectForKey: @"playcount"],
																											nil ] 
																		forKeys:[NSArray arrayWithObjects:@"title", @"image", @"placeholder", @"url", @"playcount", nil]]];
				}
				if([_weeklyArtists count] > 3)
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"More", @"-", [NSString stringWithFormat:@"lastfm-weeklyartists://%@", [_username URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Top Weekly Artists", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			} else if(_loading) {
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Top Weekly Artists", @"Loading", nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
			}
			
			if([_recentTracks count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_recentTracks count] && x < 5; x++) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_recentTracks objectAtIndex:x] objectForKey:@"name"], 
																										[[_recentTracks objectAtIndex:x] objectForKey:@"artist"], 
																										[[[_recentTracks objectAtIndex:x] objectForKey:@"uts"] shortDateStringFromUTS], 
																										//[[_recentTracks objectAtIndex:x] objectForKey:@"image"], 
//																										@"noimage_album.png", 
																										[NSString stringWithFormat:@"lastfm-track://%@/%@", [[[_recentTracks objectAtIndex:x] objectForKey:@"artist"] URLEscaped], [[[_recentTracks objectAtIndex:x] objectForKey:@"name"] URLEscaped]], 
																										[[_recentTracks objectAtIndex:x] objectForKey:@"nowplaying"], nil] 
																	forKeys:[NSArray arrayWithObjects:@"title", @"artist", @"date", /*@"image", @"placeholder",*/ @"url", @"nowplaying",nil]]];
				}
				if([_recentTracks count] > 5)
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"More", @"-", [NSString stringWithFormat:@"lastfm-recenttracks://%@", [_username URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Recently Listened Tracks", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			} else if(_loading) {
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Recently Listened Tracks", @"Loading", nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
			}
			
			if([_events count]) {
				[sections addObject:@"events"];
			}
			
			if([_friendsListeningNow count] && [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_friendsListeningNow count] && x < 3; x++) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_friendsListeningNow objectAtIndex:x] objectForKey:@"username"], [[_friendsListeningNow objectAtIndex:x] objectForKey:@"artist"], [[_friendsListeningNow objectAtIndex:x] objectForKey:@"image"], @"noimage_user.png", [[_friendsListeningNow objectAtIndex:x] objectForKey:@"title"], [[_friendsListeningNow objectAtIndex:x] objectForKey:@"realname"],
																																		 [NSString stringWithFormat:@"lastfm-user://%@", [[[_friendsListeningNow objectAtIndex:x] objectForKey:@"username"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"artist", @"image", @"placeholder", @"track", @"realname", @"url",nil]]];
				}
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat: @"More (%i)", friendsCount], @"-", [NSString stringWithFormat:@"lastfm-friends://%@", [_username URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Friends Listening Now", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			} else if(friendsCount) {
				[sections addObject:@"myfriends"];
			}
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
	if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]] && [[[_data objectAtIndex:section] objectForKey:@"stations"] isKindOfClass:[NSArray class]])
		return [[[_data objectAtIndex:section] objectForKey:@"stations"] count];
	else if([[_data objectAtIndex:section] isKindOfClass:[NSString class]] && [[_data objectAtIndex:section] isEqualToString:@"events"])
		return ([_events count] > 3)?4:[_events count];
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
	else if([[_data objectAtIndex:section] isKindOfClass:[NSString class]] && [[_data objectAtIndex:section] isEqualToString:@"events"])
		return @"Upcoming Events";
	else
		return nil;
}
/*- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	return [[[UIView alloc] init] autorelease];
}*/
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([[_profile objectForKey:@"playcount"] isEqualToString:@"0"] && [indexPath section] == 1)
		return 180;
	else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"events"] && [indexPath row] < 3)
		return 64;
	else
		return 52;
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]] && [[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] isKindOfClass:[NSArray class]]) {
		NSString *station = [[[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] objectAtIndex:[indexPath row]] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
		[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:station]];
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"events"]) {
		if([_events count]) {
			if([indexPath row]==3) {
				EventListViewController *controller = [[EventListViewController alloc] initWithEvents:_events];
				controller.title = [NSString stringWithFormat:@"%@'s Events", [_username capitalizedString]];
				[self.navigationController pushViewController:controller animated:YES];
				[controller release];
			} else {
				EventDetailsViewController *details = [[EventDetailsViewController alloc] initWithEvent:[_events objectAtIndex:[indexPath row]]];
				[self.navigationController pushViewController:details animated:YES];
				[details release];
			}
		}
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"myfriends"]) {
		[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:[NSString stringWithFormat:@"lastfm-friends://%@", [_username URLEscaped]]]];
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
	ArtworkCell *cell = nil;
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]] && [[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] isKindOfClass:[NSArray class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[stations objectAtIndex:[indexPath row]] objectForKey:@"title"]];
		if (cell == nil) {
			cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[[stations objectAtIndex:[indexPath row]] objectForKey:@"title"]] autorelease];
		}
	}
	if(cell == nil)
		cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ArtworkCell"] autorelease];
	
	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if([indexPath section] == 1 && ![[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username] &&
		 ([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_expired"] isEqualToString:@"0"])) {
		UITableViewCell *moreCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"StationCell"] autorelease];
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		moreCell.textLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		moreCell.imageView.image = [UIImage imageNamed:@"radiostarter.png"];
		return moreCell;
	}
	
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		if([[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] isKindOfClass:[NSArray class]]) {
			NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
			cell.title.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
			if([[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"]) {
				if([[stations objectAtIndex:[indexPath row]] objectForKey:@"track"]) {
					cell.subtitle.text = [NSString stringWithFormat:@"    %@ - %@", [[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"], [[stations objectAtIndex:[indexPath row]] objectForKey:@"track"]];
					UIImageView *eq = [[[UIImageView alloc] initWithFrame:CGRectMake(0,4,12,12)] autorelease];
					eq.animationImages = _eqFrames;
					eq.animationDuration = 2;
					[eq startAnimating];
					[cell.subtitle.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
					[cell.subtitle addSubview:eq];
				} else {
					cell.subtitle.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"];
				}
			}
			if( [[stations objectAtIndex:[indexPath row]] objectForKey:@"playcount"]) {
				int playcount = [[[stations objectAtIndex:[indexPath row]] objectForKey:@"playcount"] intValue ];
				cell.subtitle.text = [NSString stringWithFormat: @"%i play%s", playcount, playcount > 1 ? "s" : "" ];
			}
			cell.shouldCacheArtwork = YES;
			if([indexPath row] == 0)
				cell.shouldRoundTop = YES;
			else
				cell.shouldRoundTop = NO;
			if([indexPath row] == [self tableView:tableView numberOfRowsInSection:[indexPath section]]-1)
				cell.shouldRoundBottom = YES;
			else
				cell.shouldRoundBottom = NO;
			if(![[[stations objectAtIndex:[indexPath row]] objectForKey:@"placeholder"] isEqualToString:@"-"])
				cell.placeholder = [[stations objectAtIndex:[indexPath row]] objectForKey:@"placeholder"];
			if(![[[stations objectAtIndex:[indexPath row]] objectForKey:@"image"] isEqualToString:@"-"])
				cell.imageURL = [[stations objectAtIndex:[indexPath row]] objectForKey:@"image"];
			else
				cell.noArtwork = YES;
			if([[stations objectAtIndex:[indexPath row]] objectForKey:@"realname"]) {
				cell.detailTextLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"realname"];
				cell.detailTextLabel.textColor = [UIColor blackColor];
				cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
				cell.detailTextLabel.textAlignment = UITextAlignmentLeft;
			}	else if ([[stations objectAtIndex:[indexPath row]] objectForKey:@"date"]) {
				cell.noArtwork = YES;
				cell.detailAtBottom = YES;
				cell.detailTextLabel.textColor = [UIColor colorWithRed:36.0f/255 green:112.0f/255 blue:216.0f/255 alpha:1.0];
				cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
				cell.detailTextLabel.textAlignment = UITextAlignmentRight;
				if( [[[stations objectAtIndex:[indexPath row]] objectForKey:@"nowplaying" ] isEqualToString: @"true"]) {
					cell.detailTextLabel.text = @"Now Playing  ";
					UIImageView *eq = [[[UIImageView alloc] initWithFrame:CGRectMake(0,4,12,12)] autorelease];
					eq.animationImages = _eqFrames;
					eq.animationDuration = 2;
					[eq startAnimating];
					cell.subtitle.text = [NSString stringWithFormat: @"    %@", cell.subtitle.text];
					[cell.subtitle.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
					[cell.subtitle addSubview:eq];					
				}else {
					cell.detailTextLabel.text = [NSString stringWithFormat:@"%@  ", [[stations objectAtIndex:[indexPath row]] objectForKey:@"date"]];
				}

			}	else {
				cell.detailTextLabel.text = @"";
			}
			cell.shouldFillHeight = YES;
		} else if([[_profile objectForKey:@"playcount"] isEqualToString:@"0"]) {
			UITableViewCell *hintCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"hintCell"] autorelease];
			hintCell.backgroundView = [[[UIView alloc] init] autorelease];
			hintCell.backgroundColor = [UIColor clearColor];
			hintCell.selectionStyle = UITableViewCellSelectionStyleNone;
			hintCell.textLabel.textColor = [UIColor colorWithRed:(76.0f / 255.0f) green:(86.0f / 255.0f) blue:(108.0f / 255.0f) alpha:1.0];
			hintCell.textLabel.shadowColor = [UIColor whiteColor];
			hintCell.textLabel.shadowOffset = CGSizeMake(0.0, 1.0);
			hintCell.textLabel.font = [UIFont systemFontOfSize:14];
			hintCell.textLabel.numberOfLines = 0;
			//hintCell.textLabel.textAlignment = UITextAlignmentCenter;
			hintCell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
			hintCell.textLabel.text = @"\
Last.fm gives you new music recommendations and personal top charts based on what you listen to.\n\n\
To get started, install the Last.fm Scrobbler on your computer and import your listening history.\n\n\
Or, use this app to listen to radio and see how Last.fm tracks your music taste.";
			return hintCell;
		} else {
			cell.title.text = @"Loading";
			[cell showProgress:YES];
			cell.noArtwork = YES;
		}
	} else if([indexPath section] == 0) {
		ArtworkCell *profilecell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"ProfileCell"];
		if(profilecell == nil) {
			profilecell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ProfileCell"] autorelease];
			profilecell.placeholder = @"noimage_user.png";
			profilecell.imageURL = [_profile objectForKey:@"avatar"];
			profilecell.shouldRoundTop = YES;
			profilecell.shouldRoundBottom = YES;
		}
		profilecell.selectionStyle = UITableViewCellSelectionStyleNone;
		if([[_profile objectForKey:@"realname"] length])
			profilecell.title.text = [_profile objectForKey:@"realname"];
		else
			profilecell.title.text = _username;
		
		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
		profilecell.subtitle.text = [NSString stringWithFormat:@"%@ %@ %@",[numberFormatter stringFromNumber:[NSNumber numberWithInteger:[[_profile objectForKey:@"playcount"] intValue]]], NSLocalizedString(@"plays since", @"x plays since join date"), [[_profile objectForKey:@"registered"] shortDateStringFromUTS]];
		[numberFormatter release];
		return profilecell;
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"events"]) {
		if([indexPath row] < 3) {
			MiniEventCell *eventCell = (MiniEventCell *)[tableView dequeueReusableCellWithIdentifier:@"minieventcell"];
			if (eventCell == nil) {
				eventCell = [[[MiniEventCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"minieventcell"] autorelease];
			}
			
			NSDictionary *event = [_events objectAtIndex:[indexPath row]];
			
			NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
			[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"]; //"Fri, 21 Jan 2011 21:00:00"
			NSDate *date = [formatter dateFromString:[event objectForKey:@"startDate"]];
			[formatter setLocale:[NSLocale currentLocale]];
			
			[formatter setDateFormat:@"MMM"];
			eventCell.month.text = [[formatter stringFromDate:date] uppercaseString];
			
			[formatter setDateFormat:@"d"];
			eventCell.day.text = [formatter stringFromDate:date];
			
			eventCell.title.text = [event objectForKey:@"title"];
			[formatter setDateStyle:NSDateFormatterNoStyle];
			[formatter setTimeStyle:NSDateFormatterShortStyle];
			eventCell.location.text = [NSString stringWithFormat:@"%@, %@\n%@", [formatter stringFromDate:date], [event objectForKey:@"venue"], [event objectForKey:@"city"]];
			eventCell.location.lineBreakMode = UILineBreakModeWordWrap;
			eventCell.location.numberOfLines = 0;
			
			[formatter release];
			eventCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			
			[eventCell showProgress:NO];
			
			return eventCell;
		} else {
			UITableViewCell *moreCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MoreCell"] autorelease];
			moreCell.textLabel.text = @"More";
			moreCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			return moreCell;
		}
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"logout"]) {
		UITableViewCell *logoutcell = [tableView dequeueReusableCellWithIdentifier: @"logoutbutton"];
		if( logoutcell )
			return logoutcell;
		
		
		logoutcell = [[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"logoutbutton"] autorelease];
		[logoutcell setSelectionStyle:UITableViewCellSelectionStyleNone];
		UIButton* button = [UIButton buttonWithType:UIButtonTypeCustom];
		[button setBackgroundImage:[UIImage imageNamed:@"red_button.png"] forState:UIControlStateNormal];
		[button setTitle: @"Logout" forState:UIControlStateNormal];
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
		button.titleLabel.textAlignment = UITextAlignmentCenter;
		[button.titleLabel setShadowOffset:CGSizeMake(0, -1)];
		button.opaque = YES;
		[button addTarget:((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) action:@selector(logoutButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
		UIView* backView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
		logoutcell.backgroundColor = [UIColor clearColor];
		logoutcell.backgroundView = backView;
		
		[button setFrame: CGRectMake(0, 0, logoutcell.contentView.bounds.size.width-20, logoutcell.contentView.bounds.size.height)];
		[logoutcell.contentView addSubview: button ];
		[logoutcell layoutSubviews];

		return logoutcell;
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"myfriends"]) {
		UITableViewCell *friendscell = [[[UITableViewCell alloc] initWithFrame:CGRectZero] autorelease];
		
		if( [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] isEqualToString:_username] )
			friendscell.textLabel.text = [NSString stringWithFormat:@"My Friends (%i)", friendsCount];
		else
			friendscell.textLabel.text = [NSString stringWithFormat:@"%@’s Friends (%i)", _username, friendsCount];
		
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
	[_eqFrames release];
	[_username release];
	[_recentTracks release];
	[_weeklyArtists release];
	[_weeklyArtistImages release];
	[_friendsListeningNow release];
	[_data release];
	[_profile release];
}
@end
