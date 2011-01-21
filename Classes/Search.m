//
//  Search.m
//  MobileLastFM
//
//  Created by Sam Steele on 12/1/10.
//  Copyright 2010 Last.fm. All rights reserved.
//

#import "Search.h"
#import "LastFMService.h"
#import "ArtworkCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+URLEscaped.h"
#import "UIApplication+openURLWithWarning.h"
#import "UITableViewCell+ProgressIndicator.h"

@implementation GlobalSearchDataSource
- (void)search:(NSString *)query {
	if(_data)
		[_data release];
	
	[_results release];
	_results = [[[LastFMService sharedInstance] search:query] retain];
	
	NSMutableArray *stations = [[NSMutableArray alloc] init];
	
	if([_results count]) {
		for(int x=0; x<[_results count]; x++) {
			if([[[_results objectAtIndex:x] objectForKey:@"kind"] isEqualToString:@"tag"]) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_results objectAtIndex:x] objectForKey:@"name"],[[NSBundle mainBundle] pathForResource:@"search-results_tag" ofType:@"png"],
																																 [NSString stringWithFormat:@"lastfm-tag://%@", [[[_results objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] 
																												forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url", nil]]];
			}
			if([[[_results objectAtIndex:x] objectForKey:@"kind"] isEqualToString:@"artist"]) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_results objectAtIndex:x] objectForKey:@"name"],[[_results objectAtIndex:x] objectForKey:@"image"],
																																 [NSString stringWithFormat:@"lastfm-artist://%@", [[[_results objectAtIndex:x] objectForKey:@"name"] URLEscaped]], nil] 
																												forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url", nil]]];
			}
			if([[[_results objectAtIndex:x] objectForKey:@"kind"] isEqualToString:@"album"]) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_results objectAtIndex:x] objectForKey:@"name"],[NSString stringWithFormat:@"By %@", [[_results objectAtIndex:x] objectForKey:@"artist"]],[[_results objectAtIndex:x] objectForKey:@"image"],
																																 [NSString stringWithFormat:@"lastfm-album://%@/%@", [[[_results objectAtIndex:x] objectForKey:@"artist"] URLEscaped], [[[_results objectAtIndex:x] objectForKey:@"name"] URLEscaped]], nil] 
																												forKeys:[NSArray arrayWithObjects:@"title", @"artist", @"image", @"url", nil]]];
			}
			if([[[_results objectAtIndex:x] objectForKey:@"kind"] isEqualToString:@"track"]) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[_results objectAtIndex:x] objectForKey:@"name"],[[_results objectAtIndex:x] objectForKey:@"artist"],[[NSBundle mainBundle] pathForResource:@"search-results_track" ofType:@"png"],
																																 [NSString stringWithFormat:@"lastfm-track://%@/%@", [[[_results objectAtIndex:x] objectForKey:@"artist"] URLEscaped], [[[_results objectAtIndex:x] objectForKey:@"name"] URLEscaped]], nil] 
																												forKeys:[NSArray arrayWithObjects:@"title", @"artist", @"image", @"url", nil]]];
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
			[cell hideArtwork:YES];
		} else {
			cell.imageURL = [[_data objectAtIndex:[indexPath row]] objectForKey:@"image"];
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
	[_results release];
}
@end

@implementation RadioSearchDataSource
- (void)search:(NSString *)query {
	if(_data)
		[_data release];
	
	[_results release];
	_results = [[[LastFMService sharedInstance] search:query] retain];
	
	NSMutableArray *stations = [[NSMutableArray alloc] init];
	
	if([_results count]) {
		for(int x=0; x<[_results count]; x++) {
			if([[[_results objectAtIndex:x] objectForKey:@"kind"] isEqualToString:@"tag"]) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%@ Tag Radio", [[_results objectAtIndex:x] objectForKey:@"name"]],@"-",
																																 [NSString stringWithFormat:@"lastfm://globaltags/%@", [[[_results objectAtIndex:x] objectForKey:@"name"] URLEscaped]],nil] 
																												forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url", nil]]];
			}
			if([[[_results objectAtIndex:x] objectForKey:@"kind"] isEqualToString:@"artist"]) {
				[stations addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%@ Radio", [[_results objectAtIndex:x] objectForKey:@"name"]],[[_results objectAtIndex:x] objectForKey:@"image"],
																																 [NSString stringWithFormat:@"lastfm://artist/%@/similar", [[[_results objectAtIndex:x] objectForKey:@"name"] URLEscaped]], nil] 
																												forKeys:[NSArray arrayWithObjects:@"title", @"image", @"url", nil]]];
			}
		}
	}
	_data = stations;
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
			[cell hideArtwork:YES];
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
	[_results release];
}
@end
