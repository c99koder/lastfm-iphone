//
//  WeeklyArtistsViewController.m
//  MobileLastFM
//
//  Created by Sam Steele on 1/26/11.
//  Copyright 2011 Last.fm. All rights reserved.
//

#import "LastFMService.h"
#import "ArtworkCell.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+LastFMTimeExtensions.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "UIApplication+openURLWithWarning.h"
#import "NSString+URLEscaped.h"
#import "WeeklyArtistsViewController.h"

@implementation WeeklyArtistsViewController

- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStylePlain]) {
		_data = [[[LastFMService sharedInstance] weeklyArtistsForUser:username] retain];
		_images = [[NSMutableDictionary alloc] init];
		for(int x = 0; x < [_data count]; x++) {
			NSDictionary *info = [[LastFMService sharedInstance] metadataForArtist:[[_data objectAtIndex:x] objectForKey:@"name"] inLanguage:@"en"];
			[_images setObject:[info objectForKey:@"image"] forKey:[[_data objectAtIndex:x] objectForKey:@"name"]];
		}
		self.title = @"Top Weekly Artists";
	}
	return self;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 52;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	ArtworkCell *cell = (ArtworkCell*)[tableView dequeueReusableCellWithIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"uts"]];
	if (cell == nil) {
		cell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"uts"]] autorelease];
	}
	[cell showProgress:NO];
	cell.title.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"name"];
	cell.placeholder = @"noimage_artist.png";
	cell.imageURL = [_images objectForKey:[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"]];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  return cell;
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	NSString *url = [NSString stringWithFormat:@"lastfm-artist://%@", [[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"] URLEscaped]];
	[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:url]];
	[self.tableView reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[tableView deselectRowAtIndexPath:newIndexPath animated:NO];
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.1];
}
- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
	[super didReceiveMemoryWarning];
	
	// Relinquish ownership any cached data, images, etc. that aren't in use.
}
- (void)viewDidUnload {
	// Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
	// For example: self.myOutlet = nil;
}
- (void)dealloc {
	[_data release];
	[_images release];
  [super dealloc];
}
@end

