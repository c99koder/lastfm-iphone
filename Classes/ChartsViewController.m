/* ChartsViewController.m - Charts views and controllers
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

#import "ChartsViewController.h"
#import "ArtworkCell.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "LastFMRadio.h"
#import "MobileLastFMApplicationDelegate.h"
#import "NSString+URLEscaped.h"

@implementation TrackCell

@synthesize title, subtitle, date;

- (id)init {
	if (self = [super initWithFrame:CGRectZero]) {
		title = [[UILabel alloc] init];
		title.textColor = [UIColor blackColor];
		title.highlightedTextColor = [UIColor whiteColor];
		title.backgroundColor = [UIColor clearColor];
		title.font = [UIFont boldSystemFontOfSize:16];
		[self.contentView addSubview:title];
		
		subtitle = [[UILabel alloc] init];
		subtitle.textColor = [UIColor grayColor];
		subtitle.highlightedTextColor = [UIColor whiteColor];
		subtitle.backgroundColor = [UIColor clearColor];
		subtitle.font = [UIFont systemFontOfSize:14];
		[self.contentView addSubview:subtitle];
		
		date = [[UILabel alloc] init];
		date.textColor = [UIColor blueColor];
		date.highlightedTextColor = [UIColor whiteColor];
		date.backgroundColor = [UIColor clearColor];
		date.font = [UIFont systemFontOfSize:14];

		self.selectionStyle = UITableViewCellSelectionStyleBlue;
}
	return self;
}
- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat dateWidth;
	
	if(self.showingDeleteConfirmation || self.accessoryView) {
		dateWidth = 0;
		[date removeFromSuperview];
	} else {
		dateWidth = [date.text sizeWithFont:date.font].width;
		[self.contentView addSubview: date];
	}
	
	CGRect frame = [self.contentView bounds];
	if([subtitle.text length]) {
		title.frame = CGRectMake(frame.origin.x + 8, frame.origin.y + 8, frame.size.width-dateWidth-16, 18);
		subtitle.frame = CGRectMake(frame.origin.x + 8, frame.origin.y + 28, frame.size.width, 16);
	} else {
		title.font = [UIFont boldSystemFontOfSize:18];
		title.frame = CGRectMake(frame.origin.x + 8, frame.origin.y + 18, frame.size.width-dateWidth-16, 20);
	}
	if([date.text length]) {
		date.frame = CGRectMake(frame.origin.x + frame.size.width - dateWidth - 8, frame.origin.y + 8, dateWidth, 16);
	}
}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	[super setSelected:selected animated:animated];
	title.highlighted = selected;
	subtitle.highlighted = selected;
	date.highlighted = selected;
}
- (void)dealloc {
	[super dealloc];
	[title release];
	[subtitle release];
	[date release];
}
@end

@implementation TopChartViewController
- (id)initWithTitle:(NSString *)title {
	if (self = [super initWithStyle:UITableViewStylePlain]) {
		self.title = title;
	}
	return self;
}
- (void)viewDidLoad {
	self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (void)setData:(NSArray *)data {
	[_data release];
	_data = [data retain];
	[self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 52;
}
-(void)_playRadio:(NSTimer *)timer {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:[timer userInfo] animated:YES];
		[[self tableView] reloadData];
	}
}
-(void)playRadioStation:(NSString *)url {
	//Hack to make the loading throbber appear before we block
	[NSTimer scheduledTimerWithTimeInterval:0.5
																	 target:self
																 selector:@selector(_playRadio:)
																 userInfo:url
																	repeats:NO];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	if([[_data objectAtIndex:[newIndexPath row]] objectForKey:@"streamable"]) {
		[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
		NSString *radioURL = [NSString stringWithFormat:@"lastfm://artist/%@/similarartists",
													[[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"name"] URLEscaped]];
		[self playRadioStation:radioURL];
	}
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	ArtworkCell *cell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"]];
	if (cell == nil) {
		cell = [[[ArtworkCell alloc] initWithFrame:CGRectZero reuseIdentifier:[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"]] autorelease];
	}
	cell.title.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"name"];
	cell.subtitle.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"artist"];
	cell.barWidth = [[[_data objectAtIndex:[indexPath row]] objectForKey:@"playcount"] floatValue] / [[[_data objectAtIndex:0] objectForKey:@"playcount"] floatValue];
	cell.imageURL = [[_data objectAtIndex:[indexPath row]] objectForKey:@"image"];
	cell.shouldCacheArtwork = YES;
	if([[_data objectAtIndex:[indexPath row]] objectForKey:@"streamable"]) {
		NSString *radioURL = [NSString stringWithFormat:@"lastfm://artist/%@/similarartists",
													[[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"] URLEscaped]];
		if([[LastFMRadio sharedInstance] state] != RADIO_IDLE &&
			 [[[LastFMRadio sharedInstance] stationURL] isEqualToString:radioURL]) {
			[self showNowPlayingButton:NO];
			UIButton *btn = [[UIButton alloc] initWithFrame: CGRectMake(0, 0, 64, 30)];
			[btn setBackgroundImage:[UIImage imageNamed:@"now_playing_list.png"] forState:UIControlStateNormal];
			btn.adjustsImageWhenHighlighted = YES;
			[btn addTarget:self action:@selector(nowPlayingButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
			cell.accessoryView = btn;
			[btn release];
		} else {
			[cell addStreamIcon];
		}
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[_data release];
	[super dealloc];
}
@end

@implementation RecentChartViewController
- (id)initWithTitle:(NSString *)title {
	if (self = [super init]) {
		self.title = title;
		if([self canDeleteRows]) self.navigationItem.rightBarButtonItem = self.editButtonItem;
	}
	return self;
}
- (void)viewDidLoad {
	self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
}
- (BOOL)canDeleteRows {
	return NO;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if([self canDeleteRows]) {
		[_data removeObjectAtIndex:[indexPath row]];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil] withRowAnimation:UITableViewRowAnimationLeft];
	}
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if(![self canDeleteRows]) [self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_data count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 52;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	_selectedTrack = [_data objectAtIndex: [newIndexPath row]];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (NSString *)formatDate:(NSString *)input {
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"dd MMM yyyy, HH:mm zzz"];
	NSDate *date = [formatter dateFromString:[input stringByAppendingString:@" GMT"]];
	[formatter setLocale:[NSLocale currentLocale]];
	NSDateComponents *components = [[NSCalendar currentCalendar] components:NSDayCalendarUnit|NSMonthCalendarUnit|NSYearCalendarUnit fromDate:[NSDate date]];
	[components setHour: 23];
	[components setMinute: 59];
	[components setSecond:59];
	NSDate *today = [[NSCalendar currentCalendar] dateFromComponents:components];
	NSTimeInterval seconds = [today timeIntervalSinceDate:date];
	
	if(seconds/HOURS < 24) {
		[formatter setTimeStyle:NSDateFormatterShortStyle];
		[formatter setDateStyle:NSDateFormatterNoStyle];
	} else if(seconds/DAYS < 2) {
		[formatter setDateFormat:NSLocalizedString(@"'Yesterday'", @"Yesterday date format string")];
	} else if(seconds/DAYS < 7) {
		[formatter setDateFormat:@"EEEE"];
	} else {
		[formatter setDateStyle:NSDateFormatterShortStyle];
	}
	
	NSString *output = [formatter stringFromDate:date];
	[formatter release];
	return output;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	TrackCell *cell = (TrackCell *)[tableView dequeueReusableCellWithIdentifier:@"trackcell"];
	if (cell == nil) {
		cell = [[[TrackCell alloc] init] autorelease];
	}
	
	cell.title.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"name"];
	cell.subtitle.text = [[_data objectAtIndex:[indexPath row]] objectForKey:@"artist"];
	if([[_data objectAtIndex:[indexPath row]] objectForKey:@"url"]) {
		if([[LastFMRadio sharedInstance] state] != RADIO_IDLE &&
			 [[[LastFMRadio sharedInstance] stationURL] isEqualToString:[[_data objectAtIndex:[indexPath row]] objectForKey:@"url"]]) {
			[self showNowPlayingButton:NO];
			if([self canDeleteRows]) self.navigationItem.rightBarButtonItem = self.editButtonItem;
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
	} else {
		cell.date.text = [self formatDate:[[_data objectAtIndex:[indexPath row]] objectForKey:@"date"]];
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[_data release];
	[super dealloc];
}
@end

@implementation RecentlyPlayedChartViewController
- (id)initWithUsername:(NSString *)username {
	if(self = [super initWithTitle:NSLocalizedString(@"Recently Played", @"Recently Played Tracks chart title")]) {
		_data = [[NSMutableArray arrayWithArray:[[LastFMService sharedInstance] recentlyPlayedTracksForUser:username]] retain];
		if([LastFMService sharedInstance].error) {
			[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
			[self release];
			return nil;
		}
	}
	return self;
}
-(void)_love:(NSTimer *)timer {
	[[LastFMService sharedInstance] loveTrack:[[timer userInfo] objectForKey:@"name"] byArtist:[[timer userInfo] objectForKey:@"artist"]];
	if([LastFMService sharedInstance].error) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
	}
}
-(void)_ban:(NSTimer *)timer {
	[[LastFMService sharedInstance] banTrack:[[timer userInfo] objectForKey:@"name"] byArtist:[[timer userInfo] objectForKey:@"artist"]];
	if([LastFMService sharedInstance].error) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
	}
}
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
	if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Love", @"Love Track")]) {
		[NSTimer scheduledTimerWithTimeInterval:0.5
																		 target:self
																	 selector:@selector(_love:)
																	 userInfo:_selectedTrack
																		repeats:NO];
	} else if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Ban", @"Ban Track")]) {
		[NSTimer scheduledTimerWithTimeInterval:0.5
																		 target:self
																	 selector:@selector(_ban:)
																	 userInfo:_selectedTrack
																		repeats:NO];
	} else if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Ban Track", @"Ban Track (long)")]) {
		if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
			[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK", @"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE", @"No network available title")];
		} else {
			UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Are you sure you want to mark this song as banned?", @"Ban Confirmation")
																												 delegate:self
																								cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
																					 destructiveButtonTitle:NSLocalizedString(@"Ban", @"Ban Track")
																								otherButtonTitles:nil];
			[sheet showInView:self.view];
			[sheet release];
		}
	} else if([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Love Track", @"Love Track (long)")]) {
		if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
			[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK", @"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE", @"No network available title")];
		} else {
			UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Are you sure you want to mark this song as loved?", @"Love Confirmation")
																															 delegate:self
																											cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
																								 destructiveButtonTitle:nil
																											otherButtonTitles:NSLocalizedString(@"Love", @"Love Track"), nil];
			[sheet showInView:self.view];
			[sheet release];
		}
	}
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[super tableView:tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath];
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
																													 delegate:self
																									cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
																						 destructiveButtonTitle:NSLocalizedString(@"Ban Track", @"Ban Track (long)")
																									otherButtonTitles:NSLocalizedString(@"Love Track", @"Love Track (long)"), nil];
	[sheet showInView:self.view];
	[sheet release];
	
}
@end

#if 0
@implementation RecentlyLovedChartViewController
- (id)initWithUsername:(NSString *)username {
	if(self = [super initWithTitle:NSLocalizedString(@"Recently Loved", @"Recently Loved Tracks chart title")]) {
		_data = [[NSMutableArray arrayWithArray:[[LastFMService sharedInstance] recentlyLovedTracksForUser:username]] retain];
		if([LastFMService sharedInstance].error) {
			[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
			[self release];
			return nil;
		}
	}
	return self;
}
- (BOOL)canDeleteRows {
	return YES;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	[[LastFMService sharedInstance] unLoveTrack:[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"]
																		 byArtist:[[_data objectAtIndex:[indexPath row]] objectForKey:@"artist"]];
	[super tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
}
@end

@implementation RecentlyBannedChartViewController
- (id)initWithUsername:(NSString *)username {
	if(self = [super initWithTitle:NSLocalizedString(@"Recently Banned", @"Recently Banned Tracks chart title")]) {
		_data = [[NSMutableArray arrayWithArray:[[LastFMService sharedInstance] recentlyBannedTracksForUser:username]] retain];
		if([LastFMService sharedInstance].error) {
			[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
			[self release];
			return nil;
		}
	}
	return self;
}
- (BOOL)canDeleteRows {
	return YES;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	[[LastFMService sharedInstance] unBanTrack:[[_data objectAtIndex:[indexPath row]] objectForKey:@"name"]
																		byArtist:[[_data objectAtIndex:[indexPath row]] objectForKey:@"artist"]];
	[super tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
}
@end
#endif

@implementation RecentRadioViewController
- (id)init {
	if(self = [super initWithTitle:NSLocalizedString(@"Recent Stations", @"Recent Radio Stations chart title")]) {
		_data = [[NSMutableArray arrayWithArray:[[LastFMRadio sharedInstance] recentURLs]] retain];
	}
	return self;
}
-(void)_playRadio:(NSTimer *)timer {
	if(![(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate hasNetworkConnection]) {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate displayError:NSLocalizedString(@"ERROR_NONETWORK",@"No network available") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE",@"No network available title")];
	} else {
		[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate playRadioStation:[timer userInfo] animated:YES];
		[[self tableView] reloadData];
	}
}
-(void)playRadioStation:(NSString *)url {
	//Hack to make the loading throbber appear before we block
	[NSTimer scheduledTimerWithTimeInterval:0.5
																	 target:self
																 selector:@selector(_playRadio:)
																 userInfo:url
																	repeats:NO];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[self playRadioStation:[[_data objectAtIndex:[newIndexPath row]] objectForKey:@"url"]];
}
- (BOOL)canDeleteRows {
	return YES;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	[[LastFMRadio sharedInstance] removeRecentURL:[[_data objectAtIndex:[indexPath row]] objectForKey:@"url"]];
	[super tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
}
@end

@implementation ChartsListViewController
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStylePlain]) {
		self.title = [NSString stringWithFormat:NSLocalizedString(@"%@'s Charts", @"Charts List Title"), username];
		UIBarButtonItem *backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Charts", @"Charts back button title") style:UIBarButtonItemStylePlain target:nil action:nil];
		self.navigationItem.backBarButtonItem = backBarButtonItem;
		[backBarButtonItem release];
		_username = [username retain];
	}
	return self;
}
- (void)viewDidLoad {
	self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 4;
}
- (void)_displayChart:(NSTimer *)timer {
	UITableViewController *chart = nil;
	NSArray *data = nil;
	
	switch ([[timer userInfo] row]) {
		case 0:
			chart = [[TopChartViewController alloc] initWithTitle:NSLocalizedString(@"Top Artists", @"Top Artists chart title")];
			data = [[LastFMService sharedInstance] topArtistsForUser:_username];
			break;
		case 1:
			chart = [[TopChartViewController alloc] initWithTitle:NSLocalizedString(@"Top Albums", @"Top Albums chart title")];
			data = [[LastFMService sharedInstance] topAlbumsForUser:_username];
			break;
		case 2:
			chart = [[TopChartViewController alloc] initWithTitle:NSLocalizedString(@"Top Tracks", @"Top Tracks chart title")];
			data = [[LastFMService sharedInstance] topTracksForUser:_username];
			break;
		case 3:
			chart = [[RecentlyPlayedChartViewController alloc] initWithUsername:_username];
			data = [[LastFMService sharedInstance] recentlyPlayedTracksForUser:_username];
			break;
#if 0
		case 4:
			chart = [[RecentlyLovedChartViewController alloc] initWithUsername:_username];
			break;
		case 5:
			chart = [[RecentlyBannedChartViewController alloc] initWithUsername:_username];
			break;
#endif
	}

	if([LastFMService sharedInstance].error || [data count] == 0) {
		[chart release];
		chart = nil;
		if([LastFMService sharedInstance].error)
			[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
		else
			[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) displayError:NSLocalizedString(@"ERROR_CHART_EMPTY", @"Empty chart error") withTitle:NSLocalizedString(@"ERROR_CHART_EMPTY_TITLE", @"Empty chart error title")];
	}
	
	if(chart) {
		if([[timer userInfo] row] < 3)
			[(TopChartViewController *)chart setData:data];
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:chart animated:YES];
		[chart release];
	}
	[[self tableView] reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	//Hack to make the loading throbber appear before we block
	[NSTimer scheduledTimerWithTimeInterval:0.5
																	 target:self
																 selector:@selector(_displayChart:)
																 userInfo:newIndexPath
																	repeats:NO];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"simplecell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"simplecell"] autorelease];
	}
	
	switch([indexPath row]) {
		case 0:
			cell.text = NSLocalizedString(@"Top Artists", @"Top Artists chart title");
			break;
		case 1:
			cell.text = NSLocalizedString(@"Top Albums", @"Top Albums chart title");
			break;
		case 2:
			cell.text = NSLocalizedString(@"Top Tracks", @"Top Tracks chart title");
			break;
		case 3:
			cell.text = NSLocalizedString(@"Recently Played", @"Recently Played Tracks chart title");
			break;
		case 4:
			cell.text = NSLocalizedString(@"Recently Loved", @"Recently Loved Tracks chart title");
			break;
		case 5:
			cell.text = NSLocalizedString(@"Recently Banned", @"Recently Banned Tracks chart title");
			break;
	}
	if(cell.accessoryView) {
		cell.accessoryView = nil;
	}
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[_username release];
	[super dealloc];
}
@end

