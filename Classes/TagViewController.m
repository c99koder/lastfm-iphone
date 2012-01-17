/* TagViewController.m - Display a tag
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

#import "TagViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "ArtworkCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "UIApplication+openURLWithWarning.h"
#import "UIColor+LastFMColors.h"

@implementation TagViewController
- (void)_loadAlbums {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_albums = [[[LastFMService sharedInstance] topAlbumsForTag:_tag] retain];
	_albumsDidLoad = YES;
	[self performSelectorOnMainThread:@selector(rebuildMenu) withObject:nil waitUntilDone:YES];
	[pool release];
}
- (void)_loadTracks {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_tracks = [[[LastFMService sharedInstance] topTracksForTag:_tag] retain];
	_tracksDidLoad = YES;
	[self performSelectorOnMainThread:@selector(rebuildMenu) withObject:nil waitUntilDone:YES];
	[pool release];
}
- (void)_loadArtists {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_artists = [[[LastFMService sharedInstance] topArtistsForTag:_tag] retain];
	_artistsDidLoad = YES;
	[self performSelectorOnMainThread:@selector(rebuildMenu) withObject:nil waitUntilDone:YES];
	[pool release];
}
- (void)_loadTags {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_tags = [[[LastFMService sharedInstance] tagsSimilarTo:_tag] retain];
	_similarTagsDidLoad = YES;
	[self performSelectorOnMainThread:@selector(rebuildMenu) withObject:nil waitUntilDone:YES];
	[pool release];
}
- (id)initWithTag:(NSString *)tag {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_tag = [tag retain];

		self.title = [tag capitalizedString];
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self rebuildMenu];
}
- (void)viewDidLoad {
	self.tableView.backgroundColor = [UIColor lfmTableBackgroundColor];
	self.tableView.scrollsToTop = NO;
	_bioView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
	_tagsView = [[TTStyledTextLabel alloc] initWithFrame:CGRectZero];
	_tracksDidLoad = NO;
	_albumsDidLoad = NO;
	_artistsDidLoad = NO;
	_similarTagsDidLoad = NO;
	_metadata = [[[LastFMService sharedInstance] metadataForTag:_tag inLanguage:@"en"] retain];
	[NSThread detachNewThreadSelector:@selector(_loadTracks) toTarget:self withObject:nil];
	[NSThread detachNewThreadSelector:@selector(_loadAlbums) toTarget:self withObject:nil];
	[NSThread detachNewThreadSelector:@selector(_loadArtists) toTarget:self withObject:nil];
	[NSThread detachNewThreadSelector:@selector(_loadTags) toTarget:self withObject:nil];
}
- (void)viewDidUnload {
	[_tracks release];
	_tracks = nil;
	[_tags release];
	_tags = nil;
	[_metadata release];
	_metadata = nil;
	[_artists release];
	_artists = nil;
	[_albums release];
	_albums = nil;
	[_data release];
	_data = nil;
	[_bioView release];
	_bioView = nil;
	[_tagsView release];
	_tagsView = nil;
}
- (void)rebuildMenu {
	NSString *bio = [[_metadata objectForKey:@"wiki"] stringByReplacingOccurrencesOfString:@"\n" withString:@"<br/>"];
	//Fix Relative URL with a search replace hack:
	bio = [bio stringByReplacingOccurrencesOfString:@"href=\"/" withString:@"href=\"http://www.last.fm/"];
	
	//Handle some HTML entities, as Three20 can't parse them
	bio = [bio stringByReplacingOccurrencesOfString:@"&ndash;" withString:@"–"];
	bio = [bio stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
	NSString *html = [NSString stringWithFormat:@"%@ <a href=\"http://www.last.fm/tag/%@/wiki\">Read More »</a>", bio, [_tag URLEscaped]];
	_bioView.html = html;
	
	if(_data) {
		[_data release];
        _data = nil;
    }
	
	NSMutableArray *sections = [[NSMutableArray alloc] init];
	NSMutableArray *stations;
	
	if( [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue] || [[[NSUserDefaults standardUserDefaults] objectForKey:@"trial_expired"] isEqualToString:@"0"])
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"",
																													 [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"Play %@ Tag Radio", [_tag capitalizedString]], [NSString stringWithFormat:@"lastfm://globaltags/%@", [_tag URLEscaped]], nil]
																																																								 forKeys:[NSArray arrayWithObjects:@"title", @"url", nil]], nil]
																													 , nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
	
	if([_tags count]) {
		[sections addObject:@"tags"];
		NSString *taghtml = @"";
		
		for(int i = 0; i < [_tags count] && i < 10; i++) {
			if(i < [_tags count]-1 && i < 9)
				taghtml = [taghtml stringByAppendingFormat:@"<a href='lastfm-tag://%@'>%@</a>, ", [[[_tags objectAtIndex: i] objectForKey:@"name"] URLEscaped], [[[_tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
			else
				taghtml = [taghtml stringByAppendingFormat:@"<a href='lastfm-tag://%@'>%@</a>", [[[_tags objectAtIndex: i] objectForKey:@"name"] URLEscaped], [[[_tags objectAtIndex: i] objectForKey:@"name"] lowercaseString]];
		}
		
		_tagsView.html = taghtml;
		_tagsView.font = [UIFont systemFontOfSize:[UIFont labelFontSize]];
	}

	if([[_metadata objectForKey:@"wiki"] length])
		[sections addObject:@"bio"];
	
	if(!_artistsDidLoad) {
		[sections addObject:@"loading"];
	} else if([_artists count]) {
		stations = [[NSMutableArray alloc] init];
		for(int x=0; x<[_artists count] && x < 5; x++) {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_artists objectAtIndex:x] objectForKey:@"name"], [[_artists objectAtIndex:x] objectForKey:@"image"],
																															 [NSString stringWithFormat:@"lastfm-artist://%@", [[[_artists objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url",nil]]];
		}
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Top Artists", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		[stations release];
	}
	
	if(!_albumsDidLoad) {
		[sections addObject:@"loading"];
	} else if([_albums count]) {
		stations = [[NSMutableArray alloc] init];
		for(int x=0; x<[_albums count] && x < 5; x++) {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_albums objectAtIndex:x] objectForKey:@"name"], [[_albums objectAtIndex:x] objectForKey:@"artist"], [[_albums objectAtIndex:x] objectForKey:@"image"],
																															 [NSString stringWithFormat:@"lastfm-album://%@/%@", [[[_albums objectAtIndex:x] objectForKey:@"artist"] URLEscaped], [[[_albums objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"artist", @"image", @"url",nil]]];
		}
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Top Albums", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		[stations release];
	}
	
	if(!_tracksDidLoad) {
		[sections addObject:@"loading"];
	} else if([_tracks count]) {
		stations = [[NSMutableArray alloc] init];
		for(int x=0; x<[_tracks count] && x < 5; x++) {
			[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_tracks objectAtIndex:x] objectForKey:@"name"], [[_tracks objectAtIndex:x] objectForKey:@"artist"],
																															 [NSString stringWithFormat:@"lastfm-album://%@/%@", [[[_tracks objectAtIndex:x] objectForKey:@"artist"] URLEscaped], [[[_tracks objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] forKeys:[NSArray arrayWithObjects:@"title", @"artist", @"url",nil]]];
		}
		[sections addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Top Tracks", stations, nil] forKeys:[NSArray arrayWithObjects:@"title",@"stations",nil]]];
		[stations release];
	}
	
	_data = sections;
	
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
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
	if([[_data objectAtIndex:section] isKindOfClass:[NSDictionary class]]) {
		return [((NSDictionary *)[_data objectAtIndex:section]) objectForKey:@"title"];
	}	else if([[_data objectAtIndex:section] isKindOfClass:[NSString class]] && [[_data objectAtIndex:section] isEqualToString:@"bio"]) {
			return @"About This Tag";
	}	else if([[_data objectAtIndex:section] isKindOfClass:[NSString class]] && [[_data objectAtIndex:section] isEqualToString:@"tags"]) {
		return @"Similar Tags";
	} else {
		return nil;
	}
}
/*- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
 return [[[UIView alloc] init] autorelease];
 }*/
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"bio"]) {
		_bioView.text.width = self.view.frame.size.width - 32;
		return _bioView.text.height + 16;
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"tags"]) {
		_tagsView.text.width = self.view.frame.size.width - 32;
		return _tagsView.text.height + 16;
	} else {
		return 52;
	}
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSString *station = [[[[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"] objectAtIndex:[indexPath row]] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
		[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:station]];
	}
	[self.tableView reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
	if([[_data objectAtIndex:[newIndexPath section]] isKindOfClass:[NSDictionary class]]) {
		[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	}
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.1];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *loadingCell = [tableView dequeueReusableCellWithIdentifier:@"LoadingCell"];
	if(!loadingCell) {
		loadingCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LoadingCell"] autorelease];
		loadingCell.textLabel.text = @"Loading";
		[loadingCell showProgress:YES];
	}
	ArtworkCell *cell = nil;
	
	if([indexPath section] == 2 && !_artistsDidLoad) {
		return loadingCell;
	}
	
	if([indexPath section] == 3 && !_albumsDidLoad) {
		return loadingCell;
	}
	
	if([indexPath section] == 4 && !_tracksDidLoad) {
		return loadingCell;
	}
	
	if([indexPath section] == 5 && !_similarTagsDidLoad) {
		return loadingCell;
	}
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[stations objectAtIndex:[indexPath row]] objectForKey:@"title"]];
		if (cell == nil) {
			cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[[stations objectAtIndex:[indexPath row]] objectForKey:@"title"]] autorelease];
		}
	}
	if(cell == nil)
		cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ArtworkCell"] autorelease];
	
	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if([indexPath section] == 0 && [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_subscriber"] intValue]) {
		UITableViewCell *stationCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"StationCell"] autorelease];
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		stationCell.textLabel.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		stationCell.imageView.image = [UIImage imageNamed:@"radiostarter.png"];
		return stationCell;
	}
	
 	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"tags"]) {
		UITableViewCell *tagcell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"TagCell"];
		if(tagcell == nil) {
			tagcell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TagCell"] autorelease];
			tagcell.selectionStyle = UITableViewCellSelectionStyleNone;
			_tagsView.frame = CGRectMake(8,8,self.view.frame.size.width - 32, _tagsView.text.height);
			_tagsView.textColor = [UIColor blackColor];
			_tagsView.backgroundColor = [UIColor clearColor];
			
			[tagcell.contentView addSubview:_tagsView];
		}
		return tagcell;
	}

	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"bio"]) {
		UITableViewCell *biocell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"BioCell"];
		if(biocell == nil) {
			biocell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"BioCell"] autorelease];
			biocell.selectionStyle = UITableViewCellSelectionStyleNone;
			_bioView.frame = CGRectMake(8,8,self.view.frame.size.width - 32, _bioView.text.height);
			_bioView.backgroundColor = [UIColor clearColor];
			_bioView.textColor = [UIColor blackColor];
			[biocell.contentView addSubview:_bioView];
		}
		return biocell;
	}
	
	if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSDictionary class]]) {
		NSArray *stations = [[_data objectAtIndex:[indexPath section]] objectForKey:@"stations"];
		cell.title.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"title"];
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"]) {
			cell.subtitle.text = [[stations objectAtIndex:[indexPath row]] objectForKey:@"artist"];
		}
		cell.shouldCacheArtwork = YES;
		cell.shouldFillHeight = YES;
		if([indexPath row] == 0)
			cell.shouldRoundTop = YES;
		else
			cell.shouldRoundTop = NO;
		if([indexPath row] == [self tableView:tableView numberOfRowsInSection:[indexPath section]]-1)
			cell.shouldRoundBottom = YES;
		else
			cell.shouldRoundBottom = NO;
		if([[stations objectAtIndex:[indexPath row]] objectForKey:@"image"] != nil) {
			cell.imageURL = [[stations objectAtIndex:[indexPath row]] objectForKey:@"image"];
		} else {
			cell.noArtwork = YES;
		}
	}		
	if(cell.accessoryType == UITableViewCellAccessoryNone) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_tracks release];
	[_tags release];
	[_tag release];
	[_metadata release];
	[_artists release];
	[_albums release];
	[_data release];
	[_bioView release];
	[_tagsView release];
}
@end
