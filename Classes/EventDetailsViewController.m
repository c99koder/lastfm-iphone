/* EventDetailsViewController.m - Display event details
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
#import "UIApplication+openURLWithWarning.h"
#import <QuartzCore/QuartzCore.h>

@implementation EventDetailCell

@synthesize title, address, location, month, day;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
	if (self = [super initWithStyle:style reuseIdentifier:identifier]) {
		UIView* backView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
		self.backgroundColor = [UIColor clearColor];
		self.backgroundView = backView;
		
		if(!eventDateBGDetailImage)
			eventDateBGDetailImage = [[UIImage imageNamed:@"date-detail_view.png"] retain];
		
		_datebg = [[UIImageView alloc] initWithImage:eventDateBGDetailImage];
		_datebg.contentMode = UIViewContentModeScaleAspectFill;
		_datebg.clipsToBounds = YES;
		[_datebg.layer setBorderColor: [[UIColor clearColor] CGColor]];
		[_datebg.layer setBorderWidth: 0.0];
		[self.contentView addSubview:_datebg];
		
		month = [[UILabel alloc] init];
		month.textColor = [UIColor whiteColor];
		month.backgroundColor = [UIColor clearColor];
		month.textAlignment = UITextAlignmentCenter;
		month.font = [UIFont boldSystemFontOfSize:11];
		[_datebg addSubview: month];
		
		day = [[UILabel alloc] init];
		day.textColor = [UIColor blackColor];
		day.backgroundColor = [UIColor clearColor];
		day.textAlignment = UITextAlignmentCenter;
		day.font = [UIFont boldSystemFontOfSize:28];
		[_datebg addSubview: day];
		
		title = [[UILabel alloc] init];
		title.textColor = [UIColor blackColor];
		title.highlightedTextColor = [UIColor clearColor];
		title.backgroundColor = [UIColor clearColor];
		title.font = [UIFont boldSystemFontOfSize:16];
		title.opaque = YES;
		[self.contentView addSubview:title];
		
		location = [[UILabel alloc] init];
		location.textColor = [UIColor blackColor];
		location.highlightedTextColor = [UIColor clearColor];
		location.backgroundColor = [UIColor clearColor];
		location.font = [UIFont boldSystemFontOfSize:16];
		location.clipsToBounds = YES;
		location.opaque = YES;
		[self.contentView addSubview:location];
		
		self.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	return self;
}
- (void)layoutSubviews {
	[super layoutSubviews];
	
	CGRect frame = [self.contentView bounds];
	if(self.accessoryView != nil)
		frame.size.width = frame.size.width - [self.accessoryView bounds].size.width;
	
	_datebg.frame = CGRectMake(frame.origin.x+8, frame.origin.y+8, 40, 48);
	month.frame = CGRectMake(0,6,40,10);
	day.frame = CGRectMake(0,13,40,38);
	
	title.frame = CGRectMake(_datebg.frame.origin.x + _datebg.frame.size.width + 10, _datebg.frame.origin.y, frame.size.width - _datebg.frame.size.width - 6, 22);
	location.frame = CGRectMake(_datebg.frame.origin.x + _datebg.frame.size.width + 10, _datebg.frame.origin.y + 20, frame.size.width - _datebg.frame.size.width - 6, 
															[location.text sizeWithFont:location.font constrainedToSize:CGSizeMake(frame.size.width - _datebg.frame.size.width - 6, frame.size.height - 20) lineBreakMode:location.lineBreakMode].height);
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
- (int)isAttendingEvent:(NSString *)event_id {
	for(NSDictionary *event in _attendingEvents) {
		if([[event objectForKey:@"id"] isEqualToString:event_id]) {
			return [[event objectForKey:@"status"] intValue];
		}
	}
	return eventStatusNotAttending;
}
- (id)initWithEvent:(NSDictionary *)event {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_event = [event retain];
		_attendingEvents = [[[LastFMService sharedInstance] eventsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] retain];

		self.title = [_event objectForKey:@"title"];
	}
	return self;
}
- (NSString*)formatDate:(NSDate *)date {
	NSString* today = [[[NSDate date] description]substringToIndex:10];
	NSString* tomorrow = [[[NSDate dateWithTimeIntervalSinceNow: 86400]description] substringToIndex:10];
	
	if( [[[date description] substringToIndex: 10] isEqualToString:today]) {
		NSCalendar* calendar = [NSCalendar currentCalendar];
		NSDateComponents* components = [calendar components: (kCFCalendarUnitHour) fromDate: date];
		if( [components hour] > 17)
			return @"Tonight";
		else
			return @"Today";
	}
	
	if( [[[date description] substringToIndex:10] isEqualToString: tomorrow])
		return @"Tomorrow";
	
	return @"";
}
- (NSString*)formatArtistsFromEvent:(NSDictionary *)event {
	NSArray* artists;
	if( [[event objectForKey:@"artists"] isKindOfClass:[NSArray class]] )
		artists = [event objectForKey:@"artists"];
	else 
		artists = [NSArray arrayWithObject: [event objectForKey: @"artists"]];
	
	NSString* text = [[artists subarrayWithRange:NSMakeRange(0, MIN(4, [artists count]))] componentsJoinedByString: @", "];
	if ( [artists count] > 4 ) {
		return [NSString stringWithFormat: @"%@\n(and %i more)…", text, [artists count] - 4];
	} else {
		return text;
	}
}
- (NSString*)formatAddressFromEvent:(NSDictionary *)event {
	return [NSString stringWithFormat: @"%@\n%@\n%@", [_event objectForKey: @"street"], [_event objectForKey: @"city"], [_event objectForKey: @"postalcode"]];
}
- (void)_updateEvent:(NSDictionary *)event {
	[_event release];
	_event = [event retain];
	_attendingEvents = [[[LastFMService sharedInstance] eventsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] retain];
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 4;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger rows = 1;

	if( section == 2 ) {
		if( [[_event objectForKey: @"phonenumber"] length] )
			++rows;
		
		if( [[_event objectForKey: @"website"] length] )
			++rows;
	}
	
	return rows;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	int section = [indexPath section];
	
	if(section == 0)
		return 58;
	
	if( section == 1)
	{
		NSString* text = [self formatArtistsFromEvent: _event];
		int height = [text sizeWithFont: [UIFont boldSystemFontOfSize:[UIFont systemFontSize]] constrainedToSize: CGSizeMake(190, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap].height;
		return height + 30;
	}
	
	if( section == 2 )
	{
		if( [indexPath row] == 0 ) {
			NSString* text = [self formatAddressFromEvent: _event];
			int height = [text sizeWithFont: [UIFont boldSystemFontOfSize:[UIFont systemFontSize]] constrainedToSize: CGSizeMake(190, MAXFLOAT) lineBreakMode:UILineBreakModeWordWrap].height;
			return height + 25;
		}
	}

	return 46;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	int section = [newIndexPath section];
	
	switch ( section ) {
		case 0: //Header cell
			break;
			
		case 1: //Artist list
		{
			if( [[_event objectForKey:@"artists"] isKindOfClass:[NSArray class]] ) {
				NSArray* artists = [_event objectForKey:@"artists"];
				EventArtistsViewController *artistsVC = [[EventArtistsViewController alloc] initWithArtists:artists];
				[self.navigationController pushViewController:artistsVC animated:YES];
				[artistsVC release];
			} else {
				ArtistViewController* artistVC = [[ArtistViewController alloc] initWithArtist:[_event objectForKey:@"artists"]];
				[self.navigationController pushViewController: artistVC animated: YES];
				[artistVC release];
			}

			break;
		}
			
		case 2: //Venue details section
		{
			int row = [newIndexPath row];
			if( row >= 1 && ![[_event objectForKey:@"phonenumber"] length]) {
				row++;
			}
			if( row >= 2 && ![[_event objectForKey:@"website"] length]) {
				row++;
			}
			
			if( row == 0 ) {
				NSMutableString *query =[[NSMutableString alloc] init];
				if([[_event objectForKey:@"venue"] length]) {
					[query appendFormat:@"%@,", [_event objectForKey:@"venue"]];
				}
				if([[_event objectForKey:@"street"] length]) {
					[query appendFormat:@"%@,", [_event objectForKey:@"street"]];
				}
				if([[_event objectForKey:@"city"] length]) {
					[query appendFormat:@" %@,", [_event objectForKey:@"city"]];
				}
				if([[_event objectForKey:@"postalcode"] length]) {
					[query appendFormat:@" %@", [_event objectForKey:@"postalcode"]];
				}
				if([[_event objectForKey:@"country"] length]) {
					[query appendFormat:@" %@", [_event objectForKey:@"country"]];
				}
				[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:[NSString stringWithFormat:@"http://maps.google.com/?f=q&q=%@&ie=UTF8&om=1&iwloc=addr", [query URLEscaped]]]];
				[query release];
				break;
			}
			if( row == 1 ) {
				NSString* str = [NSString stringWithFormat:@"tel://%@", [_event objectForKey:@"phonenumber"]];
				NSString* trimmedStr = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
				NSURL* url = [NSURL URLWithString: trimmedStr];
				[[UIApplication sharedApplication] openURL:url];
				break;
			}
			if( row == 2) {
				NSURL* url = [NSURL URLWithString:[_event objectForKey:@"website"]];
				if( ![[url scheme] length] )
						url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", [_event objectForKey: @"website"]]];
				[[UIApplication sharedApplication] openURLWithWarning: url];
				break;
			}
		}
			
		case 3: //Attending
		{
			EventAttendViewController *attend = [[EventAttendViewController alloc] initWithEvent:_event];
			[self.navigationController pushViewController:attend animated:YES];
			[attend release];
			break;	
		}
			
		default:
			break;
	}
	
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[tableView reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = nil;

	int section = [indexPath section];

	
	switch(section) {
		case 0:
		{
			EventDetailCell *eventCell = (EventDetailCell *)[tableView dequeueReusableCellWithIdentifier:@"eventdetailcell"];
			if (eventCell == nil) {
				eventCell = [[[EventDetailCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"eventdetailcell"] autorelease];
			}
			
			NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
			[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"]; //"Fri, 21 Jan 2011 21:00:00"
			NSDate *date = [formatter dateFromString:[_event objectForKey:@"startDate"]];
			[formatter setLocale:[NSLocale currentLocale]];
			
			[formatter setDateFormat:@"MMM"];
			eventCell.month.text = [[formatter stringFromDate:date] uppercaseString];
			
			[formatter setDateFormat:@"d"];
			eventCell.day.text = [formatter stringFromDate:date];
			
			[formatter setDateFormat: @"EEEE, dd MMM"];
			NSString* formattedDate = [self formatDate:date];
			if( [formattedDate length] > 0 ) {
				eventCell.title.text = [NSString stringWithFormat: @"%@ (%@)", formattedDate, [formatter stringFromDate: date]];
			} else {
				eventCell.title.text = [NSString stringWithFormat: @"%@", [formatter stringFromDate: date]];
			}

			[formatter setDateStyle:NSDateFormatterNoStyle];
			[formatter setTimeStyle:NSDateFormatterShortStyle];
			eventCell.location.text = [NSString stringWithFormat: @"%@, %@", [_event objectForKey: @"venue"], [formatter stringFromDate: date]];
			
			[formatter release];
			
			eventCell.accessoryType = UITableViewCellAccessoryNone;
			
			return eventCell;
		}
		case 1:
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier: nil] autorelease];
			cell.textLabel.text = @"Playing";
			cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
			cell.detailTextLabel.text = [self formatArtistsFromEvent: _event];
			cell.detailTextLabel.numberOfLines = 0;
			cell.detailTextLabel.lineBreakMode = UILineBreakModeWordWrap;
			break;
		case 2:
		{
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier: nil] autorelease];
			int row = [indexPath row];
			if( row == 0 ) {
				cell.textLabel.text = NSLocalizedString( @"Address", @"Address label" );
				cell.detailTextLabel.text = [self formatAddressFromEvent: _event];
				cell.detailTextLabel.numberOfLines = 0;
				cell.detailTextLabel.lineBreakMode = UILineBreakModeWordWrap;
				break;
			}
			if( row == 1 && [[_event objectForKey: @"phonenumber"] length] ) {
				cell.textLabel.text = NSLocalizedString( @"Phone", @"Phone label" );
				cell.detailTextLabel.text = [_event objectForKey: @"phonenumber"];
				break;
			}
			
			if( row >= 1 && [[_event objectForKey: @"website"] length] ) {
				cell.textLabel.text = NSLocalizedString( @"Website", @"Website label" );
				cell.detailTextLabel.text = [_event objectForKey: @"website"];				
			}
			break;
		}
		case 3:
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
			cell.textLabel.text = NSLocalizedString( @"Are you attending?", @"Are you attending?" );
			int eventAttendance = [self isAttendingEvent:[_event objectForKey:@"id"]];
			switch (eventAttendance) {
				case eventStatusAttending:
					cell.detailTextLabel.text = NSLocalizedString(@"Yes", @"Yes, attending event");
					break;
					
				case eventStatusMaybeAttending:
					cell.detailTextLabel.text = NSLocalizedString(@"Maybe", @"Maybe, possibly attending event");
					break;
					
				case eventStatusNotAttending:
					cell.detailTextLabel.text = NSLocalizedString(@"No", @"No, Not attending");
					break;

			}
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
	[[LastFMService sharedInstance] attendEvent:[[_event objectForKey:@"id"] intValue] status:[newIndexPath row]];
	if([LastFMService sharedInstance].error) {
		[((MobileLastFMApplicationDelegate *)([UIApplication sharedApplication].delegate)) reportError:[LastFMService sharedInstance].error];
	} else {
		NSMutableDictionary *event = [NSMutableDictionary dictionaryWithDictionary:_event];
		[event setObject:[NSNumber numberWithInt:[newIndexPath row]] forKey:@"status"];
		[_event release];
		_event = [event retain];
		NSArray *controllers = self.navigationController.viewControllers;
		[(EventDetailsViewController *)[controllers objectAtIndex:[controllers count]-2] _updateEvent:event];
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
	
	[cell showProgress: NO];
	
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
	
	NSArray *controllers = self.navigationController.viewControllers;
	int status = [(EventDetailsViewController *)[controllers objectAtIndex:[controllers count]-2] isAttendingEvent:[_event objectForKey:@"id"]];

	if(status == [indexPath row])
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
	if(self.navigationController == ((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController.selectedViewController) {
		ArtistViewController *artist = [[ArtistViewController alloc] initWithArtist:[_artists objectAtIndex:[newIndexPath row]]];
		[self.navigationController pushViewController:artist animated:YES];
		[artist release];
	}
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"simplecell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"simplecell"] autorelease];
	}
	cell.textLabel.text = [_artists objectAtIndex:[indexPath row]];
	if(self.navigationController == ((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController.selectedViewController)
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	else
		cell.accessoryType = UITableViewCellAccessoryNone;
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
