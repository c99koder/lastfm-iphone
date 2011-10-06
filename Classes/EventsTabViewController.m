/* EventsViewController.m - Display various kinds of events for a user
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

#import "EventsTabViewController.h"
#import "EventDetailsViewController.h"
#import "UIViewController+NowPlayingButton.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "UIColor+LastFMColors.h"
#import <QuartzCore/QuartzCore.h>

UIImage *eventDateBGImage = nil;

@implementation MiniEventCell

@synthesize title, location, month, day, attendees;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
	if (self = [super initWithStyle:style reuseIdentifier:identifier]) {
		
		if(!eventDateBGImage)
			eventDateBGImage = [[UIImage imageNamed:@"date.png"] retain];
		
		_datebg = [[UIImageView alloc] initWithImage:eventDateBGImage];
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
		title.highlightedTextColor = [UIColor whiteColor];
		title.backgroundColor = [UIColor clearColor];
		title.font = [UIFont boldSystemFontOfSize:16];
		title.opaque = YES;
		[self.contentView addSubview:title];
		
		location = [[UILabel alloc] init];
		location.textColor = [UIColor grayColor];
		location.highlightedTextColor = [UIColor whiteColor];
		location.backgroundColor = [UIColor clearColor];
		location.font = [UIFont systemFontOfSize:14];
		location.clipsToBounds = YES;
		location.opaque = YES;
		[self.contentView addSubview:location];
		
		attendees = [[UILabel alloc] init];
		attendees.textColor = [UIColor grayColor];
		attendees.highlightedTextColor = [UIColor whiteColor];
		attendees.backgroundColor = [UIColor clearColor];
		attendees.font = [UIFont systemFontOfSize:14];
		attendees.clipsToBounds = YES;
		attendees.opaque = YES;
		[self.contentView addSubview:attendees];
		
		_attendeeIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"friendsevent.png"]];
		[self.contentView addSubview:_attendeeIcon];
		
		self.selectionStyle = UITableViewCellSelectionStyleBlue;
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
	
	title.frame = CGRectMake(_datebg.frame.origin.x + _datebg.frame.size.width + 6, frame.origin.y + 4, frame.size.width - _datebg.frame.size.width - 12, 22);
	float locationHeight = [location.text sizeWithFont:location.font constrainedToSize:CGSizeMake(frame.size.width - _datebg.frame.size.width - 12, frame.size.height - 24) lineBreakMode:location.lineBreakMode].height;
	if( [attendees.text length] ) {
		attendees.hidden = NO;
		_attendeeIcon.hidden = NO;
		locationHeight = 18;
	} else {
		attendees.hidden = YES;
		_attendeeIcon.hidden = YES;
	}
	
	location.frame = CGRectMake(_datebg.frame.origin.x + _datebg.frame.size.width + 6, frame.origin.y + 24, frame.size.width - _datebg.frame.size.width - 12, locationHeight);

	_attendeeIcon.frame = CGRectMake(location.frame.origin.x, location.frame.origin.y + location.frame.size.height + 2, _attendeeIcon.image.size.width, _attendeeIcon.image.size.height);
	attendees.frame = CGRectMake(location.frame.origin.x + _attendeeIcon.frame.size.width + 3, location.frame.origin.y + location.frame.size.height, location.frame.size.width, location.frame.size.height);
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
	[attendees release];
	[_attendeeIcon release];
	[_datebg release];
	[super dealloc];
}
@end

@implementation EventsTabViewController
- (void)_refresh {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSArray *events = [[[LastFMService sharedInstance] eventsForUser:_username] retain];
	NSArray *recs = [[[LastFMService sharedInstance] recommendedEventsForUser:_username] retain];
	NSArray *friendsEvents = [[[LastFMService sharedInstance] eventsForFriendsOfUser:_username] retain];

	if(![[NSThread currentThread] isCancelled]) {
		@synchronized(self) {
			[_events release];
			_events = events;
			[_recs release];
			_recs = recs;
			[_friendsEvents release];
			_friendsEvents = friendsEvents;
			[_refreshThread release];
			_refreshThread = nil;
		}
		[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
	} else {
		[events release];
		[recs release];
		[friendsEvents release];
	}
	[pool release];
}
- (id)initWithUsername:(NSString *)username {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_username = [username retain];
		self.title = @"Events";
		self.tabBarItem.image = [UIImage imageNamed:@"tabbar_events.png"];
	}
	return self;
}
- (void)viewDidUnload {
	[super viewDidUnload];
	NSLog(@"Releasing events data");
	[_events release];
	_events = nil;
	[_recs release];
	_recs = nil;
	[_friendsEvents release];
	_friendsEvents = nil;
}
- (void)viewDidLoad {
	self.tableView.backgroundColor = [UIColor lfmTableBackgroundColor];
	[LastFMService sharedInstance].cacheOnly = YES;
	[self _refresh];
	[LastFMService sharedInstance].cacheOnly = NO;
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
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if(![_username isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]]) {
		return 1;
	} else {
		if([_friendsEvents count])
			return 4;
		else
			return 3;
	}
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if(section == 0) {
		if([_username isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]])
			return @"Events I’m Attending";
		else
			return @"Upcoming Events";
	} else if(section == 1) {
		return @"Recommended Events";
	} else {
		return nil;
	}
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if(section == 0)
		if([_events count])
			return ([_events count] > 3)?4:[_events count];
		else
			return 1;
	else if(section == 1)
		if([_recs count])
			return ([_recs count] > 3)?4:[_recs count];
		else
			return 1;
	else
		return 1;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if(([indexPath section] == 0  && [indexPath row] == 3) || ([indexPath section] == 1 && [indexPath row] == 3)) {
		return 46;
	}
	if([indexPath section] == 0)
		if([_events count])
			return 64;
		else
			return 40;
	else if([indexPath section] == 1)
		if([_recs count])
			return 64;
		else
			return 70;
	else
	return 46;
}
-(void)_rowSelected:(NSIndexPath *)newIndexPath {
	switch([newIndexPath section]) {
		case 0:
		{
			if([_events count]) {
				if([newIndexPath row]==3) {
					EventListViewController *controller = [[EventListViewController alloc] initWithEvents:_events];
					controller.title = @"Events";
					[self.navigationController pushViewController:controller animated:YES];
					[controller release];
				} else {
					EventDetailsViewController *details = [[EventDetailsViewController alloc] initWithEvent:[_events objectAtIndex:[newIndexPath row]]];
					[self.navigationController pushViewController:details animated:YES];
					[details release];
				}
			}
			break;
		}
		case 1:
		{
			if([_recs count]) {
				if([newIndexPath row]==3) {
					EventListViewController *controller = [[EventListViewController alloc] initWithEvents:_recs];
					controller.title = @"Recommended Events";
					[self.navigationController pushViewController:controller animated:YES];
					[controller release];
				} else {
					EventDetailsViewController *details = [[EventDetailsViewController alloc] initWithEvent:[_recs objectAtIndex:[newIndexPath row]]];
					[self.navigationController pushViewController:details animated:YES];
					[details release];
				}
			}
			break;
		}
		case 2:
			if (nil == _locationManager)
				_locationManager = [[CLLocationManager alloc] init];
			
			_locationManager.delegate = self;
			_locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
			
			// Set a movement threshold for new events
			_locationManager.distanceFilter = 500;
			
			[_locationManager startUpdatingLocation];
			return;
			break;
		case 3:
		{
			EventListViewController *controller = [[EventListViewController alloc] initWithEvents:_friendsEvents];
			if(controller) {
				controller.title = @"Friends’ Events";
				[self.navigationController pushViewController:controller animated:YES];
				[controller release];
			}			
			
		}
	}
	[[self tableView] reloadData];
}
// Delegate method from the CLLocationManagerDelegate protocol.
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
					 fromLocation:(CLLocation *)oldLocation
{
	if(_locationManager != nil) {
			NSLog(@"latitude %+.6f, longitude %+.6f\n",
						newLocation.coordinate.latitude,
						newLocation.coordinate.longitude);
		[_locationManager stopUpdatingLocation];
		NSArray *data = [[LastFMService sharedInstance] eventsForLatitude:newLocation.coordinate.latitude longitude:newLocation.coordinate.longitude radius:50];
		EventListViewController *controller = [[EventListViewController alloc] initWithEvents:data];
		if(controller) {
			controller.title = @"Events Near Me";
			((EventListViewController*)controller).footerText = @"Based on a 50km/31 mile radius from your current location.";
			[self.navigationController pushViewController:controller animated:YES];
			[controller release];
		}
		[_locationManager autorelease];
		_locationManager = nil;
		[[self tableView] reloadData];
	}
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	if([newIndexPath section] == 0 && [_events count] == 0)
		return;
	if([newIndexPath section] == 1 && [_recs count] == 0)
		return;
	[[tableView cellForRowAtIndexPath: newIndexPath] showProgress:YES];
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[self performSelector:@selector(_rowSelected:) withObject:newIndexPath afterDelay:0.5];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"simplecell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"simplecell"] autorelease];
	}
	
	[cell showProgress: NO];
	
	if(([indexPath section] == 0 && [indexPath row] == 3) || ([indexPath section] == 1 && [indexPath row] == 3)) {
		cell.textLabel.text = @"More";
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		return cell;
	}
	
	switch([indexPath section]) {
		case 0:
		{
			if([_events count] == 0) {
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
				if([_username isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]])
					hintCell.textLabel.text = @"When you say you're coming to an event, it will appear here.";
				else
					hintCell.textLabel.text = @"When this user is coming to an event, it will appear here.";
				return hintCell;
			}
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
		}
		case 1:
		{
			if([_recs count] == 0) {
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
				hintCell.textLabel.text = @"These are based on your music taste. Install the Last.fm Scrobbler on your computer to import your listening history.";
				return hintCell;
			}
			MiniEventCell *eventCell = (MiniEventCell *)[tableView dequeueReusableCellWithIdentifier:@"minieventcell"];
			if (eventCell == nil) {
				eventCell = [[[MiniEventCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"minieventcell"] autorelease];
			}
			
			NSDictionary *event = [_recs objectAtIndex:[indexPath row]];
			
			NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
			[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
			[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"]; //"Fri, 21 Jan 2011 21:00:00"
			NSDate *date = [formatter dateFromString:[event objectForKey:@"startDate"]];
			[formatter setLocale:[NSLocale currentLocale]];
			
			eventCell.title.text = [event objectForKey:@"title"];
			[formatter setDateStyle:NSDateFormatterNoStyle];
			[formatter setTimeStyle:NSDateFormatterShortStyle];
			eventCell.location.text = [NSString stringWithFormat:@"%@, %@\n%@", [formatter stringFromDate:date], [event objectForKey:@"venue"], [event objectForKey:@"city"]];
			eventCell.location.lineBreakMode = UILineBreakModeWordWrap;
			eventCell.location.numberOfLines = 0;
			
			[formatter setDateFormat:@"MMM"];
			eventCell.month.text = [[formatter stringFromDate:date] uppercaseString];
			
			[formatter setDateFormat:@"d"];
			eventCell.day.text = [formatter stringFromDate:date];
			
			[formatter release];
			eventCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			
			[eventCell showProgress:NO];
			
			return eventCell;
		}
		case 2:
			cell.textLabel.text = @"Upcoming Events Near Me";
			break;
		case 3:
			cell.textLabel.text = @"My Friends’ Events";
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
	if(_refreshThread) {
		[_refreshThread cancel];
		[_refreshThread release];
	}
	[_username release];
	[_events release];
	[_recs release];
	[_friendsEvents release];
}
@end

@implementation EventListViewController

- (id)initWithEvents:(NSArray *)events {
	
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_events = [events retain];
	}
	return self;
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self showNowPlayingButton:[(MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate isPlaying]];
	[self.tableView reloadData];
}
- (void)viewDidLoad {
	self.tableView.backgroundColor = [UIColor lfmTableBackgroundColor];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_events count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 64;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	EventDetailsViewController *details = [[EventDetailsViewController alloc] initWithEvent:[_events objectAtIndex:[newIndexPath row]]];
	[self.navigationController pushViewController:details animated:YES];
	[details release];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

	MiniEventCell *eventCell = (MiniEventCell *)[tableView dequeueReusableCellWithIdentifier:@"minieventcell"];
	if (eventCell == nil) {
		eventCell = [[[MiniEventCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"minieventcell"] autorelease];
	}
	
	NSDictionary *event = [_events objectAtIndex:[indexPath row]];
	eventCell.title.text = [event objectForKey:@"headliner"];
	if( [event objectForKey: @"attendees"] ) {
		NSObject* attendees = [event objectForKey: @"attendees"];
		NSString* attendeeString;
		if( [attendees isKindOfClass:[NSString class]] )
			attendeeString = (NSString*)attendees;
		else if( [(NSArray*)attendees count] <= 2 )
			attendeeString = [((NSArray*)attendees) componentsJoinedByString: @", " ];
		else {
			NSRange range;
			range.location = 0;
			range.length = 2;
			NSArray* firstAttendees = [(NSArray*)attendees subarrayWithRange:range];
			attendeeString = [NSString stringWithFormat: @"%@ (and %i more)", [firstAttendees componentsJoinedByString: @", "], [(NSArray*)attendees count] - 2];
		}
		eventCell.location.lineBreakMode = UILineBreakModeTailTruncation;
		eventCell.location.numberOfLines = 1;
		eventCell.location.text = [NSString stringWithFormat:@"%@", [event objectForKey:@"venue"]];
		eventCell.attendees.text = [NSString stringWithFormat:@"%@", attendeeString];		
	} else {
		eventCell.location.lineBreakMode = UILineBreakModeWordWrap;
		eventCell.location.numberOfLines = 0;
		eventCell.location.text = [NSString stringWithFormat:@"%@\n%@, %@", [event objectForKey:@"venue"], [event objectForKey:@"city"], [event objectForKey:@"country"]];
	}
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"]; //"Fri, 21 Jan 2011 21:00:00"
	NSDate *date = [formatter dateFromString:[event objectForKey:@"startDate"]];
	[formatter setLocale:[NSLocale currentLocale]];
	
	[formatter setDateFormat:@"MMM"];
	eventCell.month.text = [formatter stringFromDate:date];
	
	[formatter setDateFormat:@"d"];
	eventCell.day.text = [formatter stringFromDate:date];
	
	[formatter release];
	eventCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	[eventCell showProgress:NO];
	
	return eventCell;
}
- (UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	if( !footerText || [footerText length] == 0 ) return nil;
	UILabel* label = [[[UILabel alloc] init] autorelease];
	label.text = footerText;
	label.frame = CGRectMake(10, 6, 300, 40);
	label.backgroundColor = [UIColor clearColor];
	label.textColor = [UIColor colorWithRed:(76.0f / 255.0f) green:(86.0f / 255.0f) blue:(108.0f / 255.0f) alpha:1.0];
	label.shadowColor = [UIColor whiteColor];
	label.shadowOffset = CGSizeMake(0.0, 1.0);
	label.font = [UIFont systemFontOfSize:14];
	label.numberOfLines = 2;
	label.textAlignment = UITextAlignmentCenter;
	label.lineBreakMode = UILineBreakModeWordWrap;
	
	UIView *footer = [[UIView alloc] init];
	[footer addSubview:label];
	return [footer autorelease];
}
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	if( !footerText || [footerText length] == 0 ) return 0.0f;
	return 50.0f;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[footerText release];
	[_events release];
}
- (NSString*)footerText {
	return footerText;
}
- (void)setFooterText:(NSString *)string {
	footerText = [string retain];
	[self.tableView reloadData];
}
@end
