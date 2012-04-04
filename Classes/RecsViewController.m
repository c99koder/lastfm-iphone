/* RecsViewController.m - Display recs
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

#import "RecsViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "UIColor+LastFMColors.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "FlurryAnalytics.h"
#endif

@implementation RecsViewController
- (void)_dismiss:(NSString *)artist {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[[LastFMService sharedInstance] dismissRecommendedArtist:artist];
	if([LastFMService sharedInstance].error)
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate performSelectorOnMainThread:@selector(reportError:) withObject:[LastFMService sharedInstance].error waitUntilDone:YES];
	[pool release];
}
- (void)_refresh {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *artists = [[[LastFMService sharedInstance] recommendedArtistsForUser:_username] retain];
	NSArray *releases = [[[LastFMService sharedInstance] releasesForUser:_username] retain];
	NSArray *recommendedReleases = [[[LastFMService sharedInstance] recommendedReleasesForUser:_username] retain];
	NSString *releaseDataSource = [[[LastFMService sharedInstance] releaseDataSourceForUser:_username] retain];
	if(![[NSThread currentThread] isCancelled]) {
		@synchronized(self) {
			[_artists release];
			_artists = artists;
			[_releases release];
			_releases = releases;
			[_recommendedReleases release];
			_recommendedReleases = recommendedReleases;
			[_releaseDataSource release];
			_releaseDataSource = releaseDataSource;
			[_refreshThread release];
			_refreshThread = nil;
		}
		[self performSelectorOnMainThread:@selector(rebuildMenu) withObject:nil waitUntilDone:YES];
		[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
		[self performSelectorOnMainThread:@selector(loadContentForCells:) withObject:[self.tableView visibleCells] waitUntilDone:YES];
	} else {
		[artists release];
		[releases release];
		[recommendedReleases release];
		[releaseDataSource release];
	}
	[pool release];
}
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_username = [username retain];
		_recsTitleLabel = [[UILabel alloc] init];
		_recsTitleLabel.text = @"New Music Recommendations";
		_recsTitleLabel.backgroundColor = [UIColor clearColor];
		_recsTitleLabel.textColor = [UIColor darkGrayColor];
		_recsTitleLabel.lineBreakMode = UILineBreakModeWordWrap;
		_recsTitleLabel.font = [UIFont boldSystemFontOfSize:[UIFont labelFontSize]];
		_recsTitleLabel.textColor = [UIColor colorWithRed:(76.0f / 255.0f) green:(86.0f / 255.0f) blue:(108.0f / 255.0f) alpha:1.0];
		_recsTitleLabel.shadowColor = [UIColor whiteColor];
		_recsTitleLabel.shadowOffset = CGSizeMake(0.0, 1.0);
		_recsTitleLabel.numberOfLines = 0;
		
		UISegmentedControl *toggle = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Music", @"New Releases", nil]];
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
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editButtonPressed:)] autorelease];
		self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Recommended" style:UIBarButtonItemStylePlain target:nil action:nil] autorelease];
		self.title = @"Recommended";
		self.tabBarItem.image = [UIImage imageNamed:@"tabbar_recs.png"];
	}
	return self;
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;
	
	if(toggle.selectedSegmentIndex == 1)
		return NO;
	
	if(toggle.selectedSegmentIndex == 0 && [indexPath section] == 0 ) 
		if( [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_expired"] isEqualToString:@"0"])
			return NO;
	
	return YES;
}
- (void)doneButtonPressed:(id)sender {
	[self.tableView setEditing:NO animated:YES];
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editButtonPressed:)] autorelease];
	_recsTitleLabel.text = @"New Music Recommendations";
	_recsTitleLabel.font = [UIFont boldSystemFontOfSize:[UIFont labelFontSize]];
	_recsTitleLabel.textAlignment = UITextAlignmentLeft;
	//((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController.topViewController.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
 }
- (void)editButtonPressed:(id)sender {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"recs-edit"];
#endif
	[self.tableView setEditing:YES animated:YES];
	_recsTitleLabel.text = @"Dismiss artists you’re not keen on to get fresh recommendations.";
	_recsTitleLabel.font = [UIFont systemFontOfSize:[UIFont systemFontSize]];
	_recsTitleLabel.textAlignment = UITextAlignmentCenter;
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonPressed:)] autorelease];
	//((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController.topViewController.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
}
- (void)viewDidUnload {
	[super viewDidUnload];
	NSLog(@"Releasing recs data");
	[_artists release];
	_artists = nil;
	[_releases release];
	_releases = nil;
	[_recommendedReleases release];
	_recommendedReleases = nil;
	[_releaseDataSource release];
	_releaseDataSource = nil;
	[_data release];
	_data = nil;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.tableView.tableHeaderView resignFirstResponder];
	[self.tableView setContentOffset:CGPointMake(0,self.tableView.tableHeaderView.frame.size.height)];
	if(self.navigationItem.rightBarButtonItem == nil)
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editButtonPressed:)] autorelease];

	if ( self.tableView.editing == YES ) {
		[self doneButtonPressed:nil];
	}
	
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.75];
	UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;
	
	if(toggle.selectedSegmentIndex == 0)
		self.navigationItem.rightBarButtonItem.enabled = YES;
	else
		self.navigationItem.rightBarButtonItem.enabled = NO;
	[UIView commitAnimations];
	
	[self rebuildMenu];
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
	[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:YES];
	
	if(_refreshThread) {
		[_refreshThread cancel];
		[_refreshThread release];
	}
	
	_refreshThread = [[NSThread alloc] initWithTarget:self selector:@selector(_refresh) object:nil];
	[_refreshThread start];
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if(editingStyle == UITableViewCellEditingStyleDelete) {
#if !(TARGET_IPHONE_SIMULATOR)
		[FlurryAnalytics logEvent:@"recs-dismiss"];
#endif
		NSMutableArray *newArtists = [NSMutableArray arrayWithArray:_artists];
		[self performSelectorInBackground:@selector(_dismiss:) withObject:[[_artists objectAtIndex:[indexPath row]] objectForKey:@"name"]];
		[newArtists removeObjectAtIndex:[indexPath row]];
		[_artists release];
		_artists = [newArtists retain];
		[self rebuildMenu];
		[tableView beginUpdates];
		if([_artists count] >= 25)
			[tableView insertRowsAtIndexPaths:[NSArray arrayWithObjects:[NSIndexPath indexPathForRow:24 inSection:[indexPath section]],nil] withRowAnimation:UITableViewRowAnimationFade];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath,nil] withRowAnimation:UITableViewRowAnimationLeft];
		[tableView endUpdates];
		[self loadContentForCells:[self.tableView visibleCells]];
	}
}
- (void)viewDidLoad {
	self.tableView.backgroundColor = [UIColor lfmTableBackgroundColor];
	[LastFMService sharedInstance].cacheOnly = YES;
	[_artists release];
	_artists = [[[LastFMService sharedInstance] recommendedArtistsForUser:_username] retain];
	[_releases release];
	_releases = [[[LastFMService sharedInstance] releasesForUser:_username] retain];
	[_recommendedReleases release];
	_recommendedReleases = [[[LastFMService sharedInstance] recommendedReleasesForUser:_username] retain];
	[_releaseDataSource release];
	_releaseDataSource = [[[LastFMService sharedInstance] releaseDataSourceForUser:_username] retain];
	[LastFMService sharedInstance].cacheOnly = NO;
	[self rebuildMenu];
}
- (void)rebuildMenu {
	@synchronized(self) {
        if(_data) {
            [_data release];
            _data = nil;
        }
		
		NSMutableArray *sections = [[NSMutableArray alloc] init];
		NSMutableArray *stations;
		
		UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;
		
		if(toggle.selectedSegmentIndex == 0) {
			if(([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_expired"] isEqualToString:@"0"]) && [_artists count])
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"", 
																														 [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"My Recommended Radio", [NSString stringWithFormat:@"lastfm://user/%@/recommended", _username], @"New music from Last.fm", nil]
																																																										forKeys:[NSArray arrayWithObjects:@"title", @"url", @"details", nil]], nil]
																														 , nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		
			if([_artists count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_artists count] && x < 25; x++) {
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_artists objectAtIndex:x] objectForKey:@"name"], [[_artists objectAtIndex:x] objectForKey:@"image"],
																																	 [NSString stringWithFormat:@"lastfm-artist://%@", [[[_artists objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
				}
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Music Recommendations", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
				self.navigationItem.rightBarButtonItem.enabled = YES;
			} else {
				self.navigationItem.rightBarButtonItem.enabled = NO;
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"New Music Recommendations", @"hint", nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
			}
		} else {
			if([_releases count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_releases count] && x < 20; x++) {
					NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
					[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
					[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z2"]; //"Fri, 21 Jan 2011 21:00:00 +0000"
					NSDate *date = [formatter dateFromString:[[_releases objectAtIndex:x] objectForKey:@"releasedate"]];
					[formatter setLocale:[NSLocale currentLocale]];
					
					[formatter setDateStyle:NSDateFormatterMediumStyle];
					NSString *releaseDate = @""; 
					if([formatter stringFromDate:date])
						releaseDate = [NSString stringWithFormat:@"Released %@", [formatter stringFromDate:date]];
					[formatter release];
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_releases objectAtIndex:x] objectForKey:@"name"], [[_releases objectAtIndex:x] objectForKey:@"image"], [[_releases objectAtIndex:x] objectForKey:@"artist"], releaseDate,
																																	 [NSString stringWithFormat:@"lastfm-album://%@/%@", [[[_releases objectAtIndex:x] objectForKey:@"artist"] URLEscaped], [[[_releases objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"artist", @"releasedate", @"url", nil]]];
				}
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"From Artists In Your Library", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			} else {
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"From Artists In Your Library", @"hint", nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
			}

			if([_recommendedReleases count]) {
				stations = [[NSMutableArray alloc] init];
				for(int x=0; x<[_recommendedReleases count] && x < 20; x++) {
					NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
					[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
					[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss Z2"]; //"Fri, 21 Jan 2011 21:00:00 +0000"
					NSDate *date = [formatter dateFromString:[[_recommendedReleases objectAtIndex:x] objectForKey:@"releasedate"]];
					[formatter setLocale:[NSLocale currentLocale]];
					
					[formatter setDateStyle:NSDateFormatterMediumStyle];
					NSString *releaseDate = [NSString stringWithFormat:@"Released %@", [formatter stringFromDate:date]];
					[formatter release];
					[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_recommendedReleases objectAtIndex:x] objectForKey:@"name"], [[_recommendedReleases objectAtIndex:x] objectForKey:@"image"], [[_recommendedReleases objectAtIndex:x] objectForKey:@"artist"], releaseDate,
																																	 [NSString stringWithFormat:@"lastfm-album://%@/%@", [[[_recommendedReleases objectAtIndex:x] objectForKey:@"artist"] URLEscaped], [[[_recommendedReleases objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"artist", @"releasedate", @"url", nil]]];
				}
				[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Recommended By Last.fm", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
				[stations release];
			}
		}
		_data = sections;
	}
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [_data count];
}
- (NSString*)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath*)indexPath {
	return @"Dismiss";
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]] && [[[_data objectAtIndex:section] objectForKey:@"stations"] isKindOfClass:[NSArray class]])
		return [[[_data objectAtIndex:section] objectForKey:@"stations"] count];
	else
		return 1;
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 45; 
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return [((NSDictionary *)[_data objectAtIndex:section]) objectForKey:@"title"];
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;
	if( [toggle selectedSegmentIndex] == 1 ) return nil;
	int recListSection = 0;
	if( [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_expired"] isEqualToString:@"0"])
		++recListSection;
	
	if( section != recListSection )
		return nil;
	
	_recsTitleLabel.frame = CGRectMake( 20, 5,
							 tableView.frame.size.width - 40,
							 [self tableView:tableView heightForHeaderInSection:section]);
	UIView* view = [[[UIView alloc] init] autorelease];
	[view addSubview: _recsTitleLabel];
	return view;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]] && [[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] isKindOfClass:[NSArray class]]) {
	UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;
	
	if(toggle.selectedSegmentIndex == 1)
		return 72;
	else
		return 52;
	} else {
		return 100;
	}
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]] && [[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] isKindOfClass:[NSArray class]]) {
		NSString *station = [[[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] objectAtIndex:[indexPath row]] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
		[[UIApplication sharedApplication] performSelectorOnMainThread:@selector(openURLWithWarning:) withObject:[NSURL URLWithString:station] waitUntilDone:YES];
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
			cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:[[stations objectAtIndex:[indexPath row]] objectForKey:@"title"]] autorelease];
		}
	}
	if(cell == nil)
		cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ArtworkCell"] autorelease];
	
	UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;

	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if([indexPath section] == 0 && toggle.selectedSegmentIndex == 0 && ([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_expired"] isEqualToString:@"0"]) && [_artists count]) {
		UITableViewCell *stationCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"StationCell"] autorelease];
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		stationCell.textLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		stationCell.detailTextLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"details"];
		stationCell.imageView.image = [UIImage imageNamed:@"radiostarter.png"];
		return stationCell;
	}
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]] && [[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] isKindOfClass:[NSArray class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell.title.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"]) {
			cell.Yoffset = 12;
			cell.subtitle.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"];
		}
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"releasedate"]) {
			cell.Yoffset = 6;
			cell.title.font = [UIFont boldSystemFontOfSize:12];
			cell.title.textColor = [UIColor grayColor];
			cell.subtitle.font = [UIFont boldSystemFontOfSize:16];
			cell.subtitle.textColor = [UIColor blackColor];
			cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
			cell.detailTextLabel.textColor = [UIColor grayColor];
			cell.detailTextLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"releasedate"];
		}
		cell.shouldCacheArtwork = YES;
		if(toggle.selectedSegmentIndex == 0)
			cell.placeholder = @"noimage_artist.png";
		else
			cell.placeholder = @"noimage_album.png";
		cell.imageURL = [[stations objectAtIndex:[indexPath row]] objectForKey:@"image"];
		cell.shouldFillHeight = YES;
		if([indexPath row] == 0)
			cell.shouldRoundTop = YES;
		else
			cell.shouldRoundTop = NO;
		if([indexPath row] == [self tableView:tableView numberOfRowsInSection:[indexPath section]]-1)
			cell.shouldRoundBottom = YES;
		else
			cell.shouldRoundBottom = NO;
	} else {
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
When you have a listening history, Last.fm will give you new music here.\n\n\
Install the Last.fm Scrobbler on your computer to import your listening history.";
		return hintCell;
	}
	
	if(cell.accessoryType == UITableViewCellAccessoryNone) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	return cell;
}
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;
	if((toggle.selectedSegmentIndex == 0 && section == 1) || (toggle.selectedSegmentIndex == 1 && (section == 1 || [_recommendedReleases count] == 0))) {
		return 48;
	} else {
		return 0;
	}
}
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;
	if((toggle.selectedSegmentIndex == 0 && section == 1) || (toggle.selectedSegmentIndex == 1 && (section == 1 || [_recommendedReleases count] == 0))) {
		// Create label with section title
		UILabel *label = [[[UILabel alloc] init] autorelease];
		label.frame = CGRectMake(10, 6, 300, 40);
		label.backgroundColor = [UIColor clearColor];
		label.textColor = [UIColor colorWithRed:(76.0f / 255.0f) green:(86.0f / 255.0f) blue:(108.0f / 255.0f) alpha:1.0];
		label.shadowColor = [UIColor whiteColor];
		label.shadowOffset = CGSizeMake(0.0, 1.0);
		label.font = [UIFont systemFontOfSize:14];
		label.numberOfLines = 2;
		label.textAlignment = UITextAlignmentCenter;
		label.lineBreakMode = UILineBreakModeWordWrap;
		if(toggle.selectedSegmentIndex == 0)
			label.text = @"This list updates over time based on your recent listening/activity.";
		else
			label.text = [NSString stringWithFormat:@"New releases data provided by\n%@", _releaseDataSource];
		// Create header view and add label as a subview
		UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 40)];
		[view autorelease];
		[view addSubview:label];
		
		return view;
	} else {
		return nil;
	}
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
	[_artists release];
	[_releases release];
	[_data release];
}
@end
