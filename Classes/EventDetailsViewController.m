/* EventsViewController.m - Display various kinds of events for a user
 * 
 * Copyright 2010 Last.fm Ltd.
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

#import "EventDetailsViewController.h"
#import "ArtistViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "DetailsViewController.h"
#import <QuartzCore/QuartzCore.h>

extern UIImage *eventDateBGImage;

@implementation EventDetailCell

@synthesize title, address, location, month, day;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
	if (self = [super initWithStyle:style reuseIdentifier:identifier]) {
		
		if(!eventDateBGImage)
			eventDateBGImage = [UIImage imageNamed:@"date.png"];
		
		_datebg = [[UIImageView alloc] initWithImage:eventDateBGImage];
		_datebg.contentMode = UIViewContentModeScaleAspectFill;
		_datebg.clipsToBounds = YES;
		[_datebg.layer setBorderColor: [[UIColor blackColor] CGColor]];
		[_datebg.layer setBorderWidth: 1.0];
		[self.contentView addSubview:_datebg];
		
		month = [[UILabel alloc] init];
		month.textColor = [UIColor whiteColor];
		month.backgroundColor = [UIColor clearColor];
		month.textAlignment = UITextAlignmentCenter;
		month.font = [UIFont boldSystemFontOfSize:14];
		month.shadowColor = [UIColor blackColor];
		month.shadowOffset = CGSizeMake(0.0, 1.0);
		[_datebg addSubview: month];
		
		day = [[UILabel alloc] init];
		day.textColor = [UIColor blackColor];
		day.backgroundColor = [UIColor clearColor];
		day.textAlignment = UITextAlignmentCenter;
		day.font = [UIFont boldSystemFontOfSize:28];
		[_datebg addSubview: day];
		
		title = [[UILabel alloc] init];
		title.textColor = [UIColor blackColor];
		title.highlightedTextColor = [UIColor whiteColor];
		title.backgroundColor = [UIColor clearColor];
		title.font = [UIFont boldSystemFontOfSize:16];
		[self.contentView addSubview:title];
		
		location = [[UILabel alloc] init];
		location.textColor = [UIColor grayColor];
		location.highlightedTextColor = [UIColor whiteColor];
		location.backgroundColor = [UIColor clearColor];
		location.font = [UIFont systemFontOfSize:14];
		[self.contentView addSubview:location];
		
		self.selectionStyle = UITableViewCellSelectionStyleBlue;
	}
	return self;
}
- (void)layoutSubviews {
	[super layoutSubviews];
	
	CGRect frame = [self.contentView bounds];
	if(self.accessoryView != nil)
		frame.size.width = frame.size.width - [self.accessoryView bounds].size.width;
	
	_datebg.frame = CGRectMake(frame.origin.x+4, frame.origin.y+4, 40, 48);
	month.frame = CGRectMake(0,2,40,10);
	day.frame = CGRectMake(0,12,40,38);
	
	title.frame = CGRectMake(_datebg.frame.origin.x + _datebg.frame.size.width + 4, frame.origin.y, frame.size.width - _datebg.frame.size.width - 6, 22);
	location.frame = CGRectMake(_datebg.frame.origin.x + _datebg.frame.size.width + 4, frame.origin.y + 20, frame.size.width - _datebg.frame.size.width - 6, 
															[location.text sizeWithFont:location.font constrainedToSize:CGSizeMake(frame.size.width - _datebg.frame.size.width - 6, frame.size.height) lineBreakMode:location.lineBreakMode].height);
}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	[super setSelected:selected animated:animated];
	if(self.selectionStyle != UITableViewCellSelectionStyleNone) {
		title.highlighted = selected;
		location.highlighted = selected;
	}
}
- (void)dealloc {
	[title release];
	[location release];
	[day release];
	[month release];
	[_datebg release];
	[super dealloc];
}
@end

@implementation EventDetailsViewController
- (id)initWithEvent:(NSDictionary *)event {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_event = [event retain];
		self.title = [_event objectForKey:@"title"];
		NSLog(@"%@", _event);
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if([[_event objectForKey:@"artists"] isKindOfClass:[NSArray class]] && [[_event objectForKey:@"artists"] count] > 0) {
		return 5;
	} else {
		return 4;
	}
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	/*if(section == 1) {
		if([[_event objectForKey:@"artists"] isKindOfClass:[NSArray class]] && [[_event objectForKey:@"artists"] count] > 0) {
			return 1;
		} else {
			return 0;
		}
	}*/
	return 1;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	int section = [indexPath section];
	
	if(section >= 1 && !([[_event objectForKey:@"artists"] isKindOfClass:[NSArray class]] && [[_event objectForKey:@"artists"] count] > 0)) {
		section++;
	}
	
	if(section == 0)
		return 58;
	else if(section == 2)
		return 76;
	else
		return 46;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	UINavigationController *controller = nil;
	NSArray *data = nil;
	int section = [newIndexPath section];
	
	if(section >= 1 && !([[_event objectForKey:@"artists"] isKindOfClass:[NSArray class]] && [[_event objectForKey:@"artists"] count] > 0)) {
		section++;
	}
		 
	switch(section) {
		case 0:
			//
			break;
		case 1:
		{
			EventArtistsViewController *artists = [[EventArtistsViewController alloc] initWithArtists:[_event objectForKey:@"artists"]];
			[((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController pushViewController:artists animated:YES];
			[artists release];
			break;
		}
		case 2:
			break;
		case 4:
		{
			EventAttendViewController *attend = [[EventAttendViewController alloc] initWithEvent:_event];
			[((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController pushViewController:attend animated:YES];
			[attend release];
			break;
		}
	}
	
	if(controller) {
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:controller animated:YES];
		[controller release];
	}
	[[self tableView] reloadData];
	[[self tableView] deselectRowAtIndexPath:newIndexPath animated:YES];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"simplecell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"simplecell"] autorelease];
	}
	int section = [indexPath section];
	
	if(section >= 1 && !([[_event objectForKey:@"artists"] isKindOfClass:[NSArray class]] && [[_event objectForKey:@"artists"] count] > 0)) {
		section++;
	}
		 
	switch(section) {
		case 0:
		{
			ArtworkCell *artistCell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:@"artworkcell"];
			if (artistCell == nil) {
				artistCell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"artworkcell"] autorelease];
			}
			
			artistCell.title.text = [_event objectForKey:@"headliner"];
			artistCell.subtitle.text = [_event objectForKey:@"title"];
			artistCell.selectionStyle = UITableViewCellSelectionStyleNone;
			artistCell.imageURL = [_event objectForKey:@"image"];
			artistCell.shouldRoundTop = YES;
			artistCell.shouldRoundBottom = YES;
			artistCell.shouldCacheArtwork = YES;
			
			return artistCell;
		}
		case 1:
			cell.textLabel.text = @"Supporting Artists";
			break;
		case 2:
		{
			EventDetailCell *eventCell = (EventDetailCell *)[tableView dequeueReusableCellWithIdentifier:@"eventdetailcell"];
			if (eventCell == nil) {
				eventCell = [[[EventDetailCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"eventdetailcell"] autorelease];
			}
			
			eventCell.title.text = [_event objectForKey:@"venue"];
			NSMutableString *address = [[NSMutableString alloc] init];
			if([[_event objectForKey:@"street"] length]) {
				[address appendFormat:@"%@\n", [_event objectForKey:@"street"]];
			}
			if([[_event objectForKey:@"city"] length]) {
				[address appendFormat:@"%@ ", [_event objectForKey:@"city"]];
			}
			if([[_event objectForKey:@"postalcode"] length]) {
				[address appendFormat:@"%@", [_event objectForKey:@"postalcode"]];
			}
			if([[_event objectForKey:@"country"] length]) {
				[address appendFormat:@"\n%@", [_event objectForKey:@"country"]];
			}

			eventCell.location.text = address;
			eventCell.location.lineBreakMode = UILineBreakModeWordWrap;
			eventCell.location.numberOfLines = 0;
			NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
			[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"]; //"Fri, 21 Jan 2011 21:00:00"
			NSDate *date = [formatter dateFromString:[_event objectForKey:@"startDate"]];
			[formatter setLocale:[NSLocale currentLocale]];
			
			[formatter setDateFormat:@"MMM"];
			eventCell.month.text = [formatter stringFromDate:date];
			
			[formatter setDateFormat:@"d"];
			eventCell.day.text = [formatter stringFromDate:date];
			
			[formatter release];
			
			return eventCell;
		}
		case 3:
			cell.textLabel.text = @"Show on map";
			break;
		case 4:
			cell.textLabel.text = @"Are you going?";
			if([[_event objectForKey:@"status"] intValue] != 0)
				cell.detailTextLabel.text = @"Maybe";
			else
				cell.detailTextLabel.text = @"Yes";
			break;
	}
	[cell showProgress: NO];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_event release];
}
@end

@implementation EventAttendViewController
- (id)initWithEvent:(NSDictionary *)event {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_event = [event retain];
		self.title = @"Are You Going?";
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
	return 3;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
		return 46;
}
-(void)_rowSelected:(NSIndexPath *)newIndexPath {
	UINavigationController *controller = nil;
	NSArray *data = nil;
	
	switch([newIndexPath section]) {
		case 0:
			//
			break;
		case 1:
			break;
		case 2:
			break;
	}
	
	if(controller) {
		[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController pushViewController:controller animated:YES];
		[controller release];
	}
	[[self tableView] reloadData];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.5];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"simplecell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"simplecell"] autorelease];
	}
	
	switch([indexPath row]) {
		case 0:
			cell.textLabel.text = @"Yes";
			break;
		case 1:
			cell.textLabel.text = @"Maybe";
			break;
		case 2:
			cell.textLabel.text = @"No";
			break;
	}
	
	if([[_event objectForKey:@"status"] intValue] == 0 && [indexPath row] == 0)
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	else if([[_event objectForKey:@"status"] intValue] != 0 && [indexPath row] == 1)
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
	else
		cell.accessoryType = UITableViewCellAccessoryNone;

	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_event release];
}
@end

@implementation EventArtistsViewController

- (id)initWithArtists:(NSArray *)artists {
	
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		self.title = @"Supporting Artists";
		_artists = [artists retain];
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_artists count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 52;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	ArtistViewController *artist = [[ArtistViewController alloc] initWithArtist:[_artists objectAtIndex:[newIndexPath row]]];
	[((MobileLastFMApplicationDelegate*)[UIApplication sharedApplication].delegate).rootViewController pushViewController:artist animated:YES];
	[artist release];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"simplecell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"simplecell"] autorelease];
	}
	cell.textLabel.text = [_artists objectAtIndex:[indexPath row]];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_artists release];
}
@end
