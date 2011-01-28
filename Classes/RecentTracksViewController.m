//
//  RecentTracksViewController.m
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
#import "RecentTracksViewController.h"

@implementation RecentTracksViewController

- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStylePlain]) {
		_data = [[[LastFMService sharedInstance] recentlyPlayedTracksForUser:username] retain];
		self.title = @"Recent Tracks";
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
	cell.subtitle.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"artist"];
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ ", [[[_data objectAtIndex:[indexPath row]] objectForKey:@"uts"] StringFromUTS]];
	cell.detailTextLabel.textColor = [UIColor colorWithRed:0.34 green:0.48 blue:0.64 alpha:1.0];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
	cell.detailTextLabel.textAlignment = UITextAlignmentRight;
	cell.placeholder = @"noimage_album.png";
	cell.imageURL = [[_data objectAtIndex:[indexPath row]] objectForKey:@"image"];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  return cell;
}
-(void)_rowSelected:(NSIndexPath *)indexPath {
	NSString *url = [NSString stringWithFormat:@"lastfm-track://%@/%@", [[[_data objectAtIndex:[indexPath row]] objectForKey:@"artist"] URLEscaped], [[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"] URLEscaped]];
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
  [super dealloc];
}
@end

