/* Search.m - Search data sources
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

#import "Search.h"
#import "LastFMService.h"
#import "ArtworkCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+URLEscaped.h"
#import "UIApplication+openURLWithWarning.h"
#import "UITableViewCell+ProgressIndicator.h"

@implementation GlobalSearchDataSource
- (void)search:(NSString *)query {
	if(_data) {
		[_data release];
        _data = nil;
    }
	
	NSArray *results = [[LastFMService sharedInstance] search:query];
	NSMutableArray *stations = [[NSMutableArray alloc] init];
	float scale = 1.0f;
	if([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
		scale = [[UIScreen mainScreen] scale];
	
	if([results count]) {
		for(int x=0; x<[results count]; x++) {
			if([[[results objectAtIndex:x] objectForKey:@"kind"] isEqualToString:@"tag"]) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[results objectAtIndex:x] objectForKey:@"name"],(scale==1.0f)?[[NSBundle mainBundle] pathForResource:@"searchresults_tag" ofType:@"png"]:[[NSBundle mainBundle] pathForResource:@"searchresults_tag@2x" ofType:@"png"],@"searchresults_tag.png",
																																 [NSString stringWithFormat:@"lastfm-tag://%@", [[[results objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] 
																												forKeys:[NSArray arrayWithObjects:@"title", @"image", @"placeholder", @"url", nil]]];
			}
			if([[[results objectAtIndex:x] objectForKey:@"kind"] isEqualToString:@"artist"]) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[results objectAtIndex:x] objectForKey:@"name"],[[results objectAtIndex:x] objectForKey:@"image"],@"noimage_artist.png",
																																 [NSString stringWithFormat:@"lastfm-artist://%@", [[[results objectAtIndex:x] objectForKey:@"name"] URLEscaped]], nil] 
																												forKeys:[NSArray arrayWithObjects:@"title", @"image", @"placeholder",@"url", nil]]];
			}
			if([[[results objectAtIndex:x] objectForKey:@"kind"] isEqualToString:@"album"]) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[results objectAtIndex:x] objectForKey:@"name"],[NSString stringWithFormat:@"By %@", [[results objectAtIndex:x] objectForKey:@"artist"]],[[results objectAtIndex:x] objectForKey:@"image"],@"noimage_album.png",
																																 [NSString stringWithFormat:@"lastfm-album://%@/%@", [[[results objectAtIndex:x] objectForKey:@"artist"] URLEscaped], [[[results objectAtIndex:x] objectForKey:@"name"] URLEscaped]], nil] 
																												forKeys:[NSArray arrayWithObjects:@"title", @"artist", @"image", @"placeholder",@"url", nil]]];
			}
			if([[[results objectAtIndex:x] objectForKey:@"kind"] isEqualToString:@"track"]) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[results objectAtIndex:x] objectForKey:@"name"],[[results objectAtIndex:x] objectForKey:@"artist"],(scale==1.0f)?[[NSBundle mainBundle] pathForResource:@"searchresults_track" ofType:@"png"]:[[NSBundle mainBundle] pathForResource:@"searchresults_track@2x" ofType:@"png"],@"searchresults_track.png",
																																 [NSString stringWithFormat:@"lastfm-track://%@/%@", [[[results objectAtIndex:x] objectForKey:@"artist"] URLEscaped], [[[results objectAtIndex:x] objectForKey:@"name"] URLEscaped]], [[results objectAtIndex:x] objectForKey:@"duration"], nil] 
																												forKeys:[NSArray arrayWithObjects:@"title", @"artist", @"image", @"placeholder",@"url", @"duration", nil]]];
			}
		}
	}
	_data = stations;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
- (NSArray *)data {
	return _data;
}
- (void)clear {
	[_data release];
	_data = nil;
	
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	ArtworkCell *cell = nil;
	
	if([[_data objectAtIndex:[indexPath row]] isKindOfClass:[NSDictionary class]]) {
		cell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"title"]];
		if (cell == nil) {
			cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"title"]] autorelease];
		}
	}
	if(cell == nil)
		cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ArtworkCell"] autorelease];
	
	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if([[_data objectAtIndex:[indexPath row]] isKindOfClass:[NSDictionary class]]) {
		cell.title.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"title"];
		if([[_data objectAtIndex:[indexPath row]] objectForKey:@"artist"]) {
			cell.subtitle.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"artist"];
		}
		cell.shouldCacheArtwork = YES;
		if([[[_data objectAtIndex:[indexPath row]] objectForKey:@"image"] isEqualToString:@"-"]) {
			cell.noArtwork = YES;
		} else {
			cell.placeholder = [[_data objectAtIndex:[indexPath row]] objectForKey:@"placeholder"];
			cell.imageURL = [[_data objectAtIndex:[indexPath row]] objectForKey:@"image"];
		}
		if([[_data objectAtIndex:[indexPath row]] objectForKey:@"duration"] &&
		   [[[_data objectAtIndex:[indexPath row]] objectForKey:@"duration"] intValue] > 0) {
			cell.title.text = [NSString stringWithFormat: @"%@ (%i:%.2i)",  cell.title.text, [[[_data objectAtIndex:[indexPath row]] objectForKey:@"duration"] intValue] / 60,
																				[[[_data objectAtIndex:[indexPath row]] objectForKey:@"duration"] intValue] % 60];
			
		}
		cell.shouldFillHeight = YES;
	}		
	if(cell.accessoryType == UITableViewCellAccessoryNone) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
	return cell;
}
- (void)dealloc {
	[super dealloc];
	[_data release];
}
@end

@implementation RadioSearchDataSource
- (void)search:(NSString *)query {
	if(_data) {
		[_data release];
        _data = nil;
    }
	
	NSArray *results = [[[LastFMService sharedInstance] search:query] retain];
	
	NSMutableArray *stations = [[NSMutableArray alloc] init];
	
	if([results count]) {
		for(int x=0; x<[results count]; x++) {
			if([[[results objectAtIndex:x] objectForKey:@"kind"] isEqualToString:@"tag"]) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%@ Tag Radio", [[results objectAtIndex:x] objectForKey:@"name"]],@"-",
																																 [NSString stringWithFormat:@"lastfm://globaltags/%@", [[[results objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] 
																												forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url", nil]]];
			}
			if([[[results objectAtIndex:x] objectForKey:@"kind"] isEqualToString:@"artist"]) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%@ Radio", [[results objectAtIndex:x] objectForKey:@"name"]],[[results objectAtIndex:x] objectForKey:@"image"],
																																 [NSString stringWithFormat:@"lastfm://artist/%@/similar", [[[results objectAtIndex:x] objectForKey:@"name"] URLEscaped]], nil] 
																												forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url", nil]]];
			}
		}
	}
	_data = stations;
	[results release];
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	if([[_data objectAtIndex:[indexPath row]] isKindOfClass:[NSDictionary class]]) {
		NSString *station = [[_data objectAtIndex:[indexPath row]] objectForKey:@"url"];
		NSLog(@"Station: %@", station);
		[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:station]];
	} else if([[_data objectAtIndex:[indexPath section]] isKindOfClass:[NSString class]] && [[_data objectAtIndex:[indexPath section]] isEqualToString:@"logout"]) {
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) logoutButtonPressed:nil];
	}
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
	if([newIndexPath row] > 0) {
		[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	}
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.1];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	return nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	ArtworkCell *cell = nil;
	
	if([[_data objectAtIndex:[indexPath row]] isKindOfClass:[NSDictionary class]]) {
		cell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"title"]];
		if (cell == nil) {
			cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"title"]] autorelease];
		}
	}
	if(cell == nil)
		cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ArtworkCell"] autorelease];
	
	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryNone;
	
	if([[_data objectAtIndex:[indexPath row]] isKindOfClass:[NSDictionary class]]) {
		cell.title.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"title"];
		if([[_data objectAtIndex:[indexPath row]] objectForKey:@"artist"]) {
			cell.subtitle.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"artist"];
		}
		cell.shouldCacheArtwork = YES;
		if([[[_data objectAtIndex:[indexPath row]] objectForKey:@"image"] isEqualToString:@"-"]) {
			cell.noArtwork = YES;
		} else {
			cell.imageURL = [[_data objectAtIndex:[indexPath row]] objectForKey:@"image"];
		}
		cell.shouldFillHeight = YES;
	}		
	UIImageView *img = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"streaming.png"]];
	img.opaque = YES;
	cell.accessoryView = img;
	[img release];
	return cell;
}
- (void)dealloc {
	[super dealloc];
	[_data release];
}
@end
