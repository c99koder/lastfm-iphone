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

#import <QuartzCore/QuartzCore.h>
#import "EventDetailsViewController.h"
#import "UITableViewCell+ProgressIndicator.h"
#import "MobileLastFMApplicationDelegate.h"
#include "version.h"
#import "NSString+URLEscaped.h"
#import "UIColor+LastFMColors.h"
#import "ButtonsCell.h"
#import "ShareActionSheet.h"
#import "ArtistViewController.h"
#import "PosterViewController.h"
#import "UIApplication+openURLWithWarning.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "FlurryAnalytics.h"
#endif

@implementation EventDetailCell

@synthesize location, date, score, days;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
	if (self = [super initWithStyle:style reuseIdentifier:identifier]) {
		title.textColor = [UIColor blackColor];
		title.highlightedTextColor = [UIColor clearColor];
		title.backgroundColor = [UIColor clearColor];
		title.font = [UIFont boldSystemFontOfSize:16];
		
		date = [[UILabel alloc] init];
		date.textColor = [UIColor blackColor];
		date.highlightedTextColor = [UIColor clearColor];
		date.backgroundColor = [UIColor clearColor];
		date.font = [UIFont boldSystemFontOfSize:14];
		date.clipsToBounds = YES;
		[self.contentView addSubview:date];
		
		score = [[UILabel alloc] init];
		score.textColor = [UIColor redColor];
		score.highlightedTextColor = [UIColor clearColor];
		score.backgroundColor = [UIColor clearColor];
		score.textAlignment = UITextAlignmentCenter;
		score.font = [UIFont boldSystemFontOfSize:26];
		score.clipsToBounds = YES;
		[self.contentView addSubview:score];
		
		scoreLabel = [[UILabel alloc] init];
		scoreLabel.textColor = [UIColor redColor];
		scoreLabel.highlightedTextColor = [UIColor clearColor];
		scoreLabel.textAlignment = UITextAlignmentCenter;
		scoreLabel.backgroundColor = [UIColor clearColor];
		scoreLabel.font = [UIFont boldSystemFontOfSize:12];
		scoreLabel.clipsToBounds = YES;
		scoreLabel.text = @"Compatibility";
		[self.contentView addSubview:scoreLabel];
		
		days = [[UILabel alloc] init];
		days.textColor = [UIColor dateColor];
		days.highlightedTextColor = [UIColor clearColor];
		days.backgroundColor = [UIColor clearColor];
		days.textAlignment = UITextAlignmentCenter;
		days.font = [UIFont boldSystemFontOfSize:26];
		days.clipsToBounds = YES;
		[self.contentView addSubview:days];
		
		daysLabel = [[UILabel alloc] init];
		daysLabel.textColor = [UIColor dateColor];
		daysLabel.highlightedTextColor = [UIColor clearColor];
		daysLabel.textAlignment = UITextAlignmentCenter;
		daysLabel.backgroundColor = [UIColor clearColor];
		daysLabel.font = [UIFont boldSystemFontOfSize:12];
		daysLabel.clipsToBounds = YES;
		daysLabel.text = @"Days To Go";
		[self.contentView addSubview:daysLabel];
		
		location = [[UILabel alloc] init];
		location.textColor = [UIColor blackColor];
		location.highlightedTextColor = [UIColor clearColor];
		location.backgroundColor = [UIColor clearColor];
		location.font = [UIFont boldSystemFontOfSize:14];
		location.clipsToBounds = YES;
		location.numberOfLines = 0;
		location.lineBreakMode = UILineBreakModeWordWrap;
		[self.contentView addSubview:location];
		
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		self.backgroundView = [[[UIView alloc] init] autorelease];
	}
	return self;
}
- (void)layoutSubviews {
	[super layoutSubviews];
	
	CGRect frame = [self.contentView bounds];
	if(self.accessoryView != nil)
		frame.size.width = frame.size.width - [self.accessoryView bounds].size.width;
	
	_artwork.frame = CGRectMake(frame.origin.x, frame.origin.y, 90, frame.size.height);
	
	title.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 10, _artwork.frame.origin.y, frame.size.width - _artwork.frame.size.width - 6, 18);
	date.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 10, _artwork.frame.origin.y + 18, frame.size.width - _artwork.frame.size.width - 6, 16);
	float locationHeight = [location.text sizeWithFont:location.font constrainedToSize:CGSizeMake(frame.size.width - _artwork.frame.origin.x - _artwork.frame.size.width - 10, 16*2) lineBreakMode:location.lineBreakMode].height;
	location.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 10, _artwork.frame.origin.y + 34, frame.size.width - _artwork.frame.origin.x - _artwork.frame.size.width - 10, locationHeight);
	
	if(score.hidden == YES) {
		scoreLabel.hidden = YES;
		days.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 10, frame.size.height - 14 - 28, 80, 28);
		daysLabel.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 10, frame.size.height - 14, 80, 14);
	} else {
		scoreLabel.hidden = NO;
		score.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 10, frame.size.height - 14 - 28, 80, 28);
		scoreLabel.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 10, frame.size.height - 14, 80, 14);
		days.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 100, frame.size.height - 14 - 28, 80, 28);
		daysLabel.frame = CGRectMake(_artwork.frame.origin.x + _artwork.frame.size.width + 100, frame.size.height - 14, 80, 14);
	}
}
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	[super setSelected:selected animated:animated];
	if(self.selectionStyle != UITableViewCellSelectionStyleNone) {
		title.highlighted = selected;
		location.highlighted = selected;
	}
}
- (void)dealloc {
	[location release];
	[score release];
	[date release];
	[scoreLabel release];
	[super dealloc];
}
@end

@implementation EventDetailsViewController
- (void)share {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"share" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:@"event", @"type", nil, nil]];
#endif
	ShareActionSheet* action = [[ShareActionSheet alloc] initWithEvent:_event];
	if(self.navigationController == ((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController.selectedViewController) {
		action.viewController = self.tabBarController;
		[action showFromTabBar: self.tabBarController.tabBar];
	} else {
		action.viewController = self.navigationController;
		[action showInView: self.view];
	}
	[action release];
}
- (void)addToCalendar {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"add-to-calendar"];
#endif
	EKEventStore *eventStore = [[EKEventStore alloc] init];
	EKEvent *e = [EKEvent eventWithEventStore:eventStore];
	e.title = [_event objectForKey:@"title"];
	NSString *location = [_event objectForKey:@"venue"];
	if([[_event objectForKey:@"city"] length])
		location = [NSString stringWithFormat:@"%@, %@", location, [_event objectForKey:@"city"]];
	
	e.location = location;
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
	[formatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"]; //"Fri, 21 Jan 2011 21:00:00"
	NSDate *date = [formatter dateFromString:[_event objectForKey:@"startDate"]];
	e.startDate = date;
	e.endDate = [date dateByAddingTimeInterval:60 * 60];
	[formatter release];
	
	EKEventEditViewController *addController = [[EKEventEditViewController alloc] initWithNibName:nil bundle:nil];
	
	addController.editViewDelegate = self;
	addController.eventStore = eventStore;
	addController.event = e;

    [eventStore release];
    
	if(self.navigationController == ((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController.selectedViewController)
		[self presentModalViewController:addController animated:YES];
	else
		[self.navigationController pushViewController:addController animated:YES];
	[addController release];
}
- (int)isAttendingEvent:(NSString *)event_id {
	for(NSDictionary *event in _attendingEvents) {
		if([[event objectForKey:@"id"] isEqualToString:event_id]) {
			return [[event objectForKey:@"status"] intValue];
		}
	}
	return eventStatusNotAttending;
}
- (void)reload {
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (void)_loadEvent {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if([[_event objectForKey:@"score"] intValue] == 0 || [[_event objectForKey:@"startDate"] length] == 0) {
		NSDictionary *event = _event;
		_event = [[[LastFMService sharedInstance] detailsForEvent:[[event objectForKey:@"id"] intValue]] retain];
		[event release];
	}
	if([[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_session"] length]) {
		_attendingEvents = [[[LastFMService sharedInstance] eventsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] retain];
		_recommendedLineup = [[[LastFMService sharedInstance] recommendedLineupForEvent:[[_event objectForKey:@"id"] intValue]] retain];
	} else {
		_attendingEvents = nil;
		_recommendedLineup = nil;
	}
	_loaded = YES;
	[self performSelectorOnMainThread:@selector(reload) withObject:nil waitUntilDone:YES];
	[pool release];
}
- (id)initWithEvent:(NSDictionary *)event {
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		_loaded = NO;
		_event = [event retain];
		if([[event objectForKey:@"attendees"] isKindOfClass:[NSArray class]] || [[event objectForKey:@"attendees"] isKindOfClass:[NSString class]])
			_attendees = [[event objectForKey:@"attendees"] retain];
		else
			_attendees = nil;
		self.title = [_event objectForKey:@"title"];
		self.navigationItem.backBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:nil action:nil] autorelease];
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
	if([[_event objectForKey:@"street"] length])
		 return [NSString stringWithFormat: @"%@\n%@\n%@ %@\n%@", [_event objectForKey:@"venue"], [_event objectForKey: @"street"], [_event objectForKey: @"city"], [_event objectForKey: @"postalcode"], [_event objectForKey: @"country"]];
	 else
		 return [NSString stringWithFormat: @"%@\n%@ %@\n%@", [_event objectForKey:@"venue"], [_event objectForKey: @"city"], [_event objectForKey: @"postalcode"], [_event objectForKey: @"country"]];
}
- (void)_updateEvent:(NSDictionary *)event {
	[_event release];
	_event = [event retain];
	[LastFMService sharedInstance].cacheOnly = NO;
	_attendingEvents = [[[LastFMService sharedInstance] eventsForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]] retain];
}
- (void)viewDidLoad {
	self.tableView.backgroundColor = [UIColor lfmTableBackgroundColor];
	[NSThread detachNewThreadSelector:@selector(_loadEvent) toTarget:self withObject:nil];
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self reload];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	if(_loaded)
		return _attendees?6:5;
	else
		return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSInteger rows = 1;

	if(!_loaded)
		return 1;
	
	if(section == 2) {
		rows = [_recommendedLineup count] + 1;
		if(rows > 5)
			rows = 5;
	}
	
	if(section >= 3 && !_attendees)
		section++;
	
	if(section == 4 ) {
		if([[_event objectForKey: @"phonenumber"] length])
			++rows;
		
		if([[_event objectForKey: @"website"] length])
			++rows;
	}
	
	return rows;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	int section = [indexPath section];
	if(section >= 3 && !_attendees)
		section++;

	if(section == 0)
		return 120;
	
	if(section == 4) {
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
	if(section >= 3 && !_attendees)
		section++;
	
	switch ( section ) {
		case 0: //Header cell
		{
#if !(TARGET_IPHONE_SIMULATOR)
			[FlurryAnalytics logEvent:@"view-poster"];
#endif
			PosterViewController *p = [[PosterViewController alloc] initWithEvent:_event];
			[self.navigationController pushViewController:p animated:YES];
			[p release];
			break;
		}
			
		case 1: //Attending
		{
#if !(TARGET_IPHONE_SIMULATOR)
			[FlurryAnalytics logEvent:@"view-attendance"];
#endif
			EventAttendViewController *attend = [[EventAttendViewController alloc] initWithEvent:_event];
			[self.navigationController pushViewController:attend animated:YES];
			[attend release];
			break;	
		}

		case 2: //Artist list
		{
			if([newIndexPath row] == [_recommendedLineup count] || [newIndexPath row] == 4) {
#if !(TARGET_IPHONE_SIMULATOR)
				[FlurryAnalytics logEvent:@"view-lineup"];
#endif
				NSArray* artists = [_event objectForKey:@"artists"];
				EventArtistsViewController *artistsVC = [[EventArtistsViewController alloc] initWithArtists:artists recs:_recommendedLineup];
				[self.navigationController pushViewController:artistsVC animated:YES];
				[artistsVC release];
			} else {
				if(self.navigationController == ((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController.selectedViewController) {
#if !(TARGET_IPHONE_SIMULATOR)
					[FlurryAnalytics logEvent:@"view-artist"];
#endif
					ArtistViewController* artistVC = [[ArtistViewController alloc] initWithArtist:[[_recommendedLineup objectAtIndex:[newIndexPath row]] objectForKey:@"name"]];
					[self.navigationController pushViewController: artistVC animated: YES];
					[artistVC release];
				}
			}

			break;
		}
			
		case 4: //Venue details section
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
#if !(TARGET_IPHONE_SIMULATOR)
				[FlurryAnalytics logEvent:@"map"];
#endif
				[[UIApplication sharedApplication] openURLWithWarning:[NSURL URLWithString:[NSString stringWithFormat:@"http://maps.google.com/?f=q&q=%@&ie=UTF8&om=1&iwloc=addr", [query URLEscaped]]]];
				[query release];
				break;
			}
			if( row == 1 ) {
				NSString* str = [NSString stringWithFormat:@"tel://%@", [_event objectForKey:@"phonenumber"]];
				NSString* trimmedStr = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
				NSURL* url = [NSURL URLWithString: trimmedStr];
#if !(TARGET_IPHONE_SIMULATOR)
				[FlurryAnalytics logEvent:@"phone"];
#endif
				[[UIApplication sharedApplication] openURLWithWarning:url];
				break;
			}
			if( row == 2) {
				NSURL* url = [NSURL URLWithString:[_event objectForKey:@"website"]];
#if !(TARGET_IPHONE_SIMULATOR)
				[FlurryAnalytics logEvent:@"website"];
#endif
				if( ![[url scheme] length] )
						url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", [_event objectForKey: @"website"]]];
				[[UIApplication sharedApplication] openURLWithWarning: url];
				break;
			}
		}
			
		default:
			break;
	}
	
	[tableView deselectRowAtIndexPath:newIndexPath animated:YES];
	[tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if(section >= 3 && !_attendees)
		section++;

	if(section == 2)
		return @"Your Recommended Lineup";
	else if(section == 3)
		return @"Your Friends Attending";
	else
		return nil;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = nil;
	int section = [indexPath section];
	if(section >= 3 && !_attendees)
		section++;

	if(!_loaded) {
		UITableViewCell *loadingCell = [tableView dequeueReusableCellWithIdentifier:@"LoadingCell"];
		if(!loadingCell) {
			loadingCell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"LoadingCell"] autorelease];
			loadingCell.backgroundView = [[[UIView alloc] init] autorelease];
			loadingCell.backgroundColor = [UIColor clearColor];
			loadingCell.textLabel.text = @"\n\n\nLoading";
			loadingCell.textLabel.numberOfLines = 0;
			loadingCell.textLabel.textAlignment = UITextAlignmentCenter;
			loadingCell.textLabel.textColor = [UIColor blackColor];
			UIActivityIndicatorView *progress = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
			[progress startAnimating];
			CGRect frame = progress.frame;
			frame.origin.y = 20;
			frame.origin.x = 130;
			progress.frame = frame;
			[loadingCell.contentView addSubview: progress];
			[progress release];
		}
		return loadingCell;
	}
	
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
			
			[formatter setDateFormat:@"EEEE MMMM dd yyyy"];
			eventCell.date.text = [formatter stringFromDate:date];
			eventCell.title.text = [_event objectForKey:@"title"];
			eventCell.location.text = [NSString stringWithFormat: @"%@, %@\n%@", [_event objectForKey: @"venue"], [_event objectForKey:@"city"], [_event objectForKey:@"country"]];
            if([[_event objectForKey:@"score"] floatValue] > 0) {
                eventCell.score.text = [NSString stringWithFormat:@"%i%%", (int)([[_event objectForKey:@"score"] floatValue] * 100.0f)];
                eventCell.score.hidden = NO;
            } else {
                eventCell.score.hidden = YES;
            }
			int days = [date timeIntervalSinceDate:[NSDate date]]/60/60/24;
			eventCell.days.text = [NSString stringWithFormat:@"%i", days];
			[formatter release];
			
			[eventCell addBorder];
			eventCell.imageURL = [_event objectForKey:@"image"];
			
			eventCell.accessoryType = UITableViewCellAccessoryNone;
			
			return eventCell;
		}
		case 1:
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil] autorelease];
			cell.textLabel.text = @"Are you going?";
			int eventAttendance = [self isAttendingEvent:[_event objectForKey:@"id"]];
			switch (eventAttendance) {
				case eventStatusAttending:
					cell.detailTextLabel.text = NSLocalizedString(@"Yes", @"Yes, attending event");
					break;
					
				case eventStatusMaybeAttending:
					cell.detailTextLabel.text = NSLocalizedString(@"I'm Interested", @"Maybe, possibly attending event");
					break;
					
				case eventStatusNotAttending:
					cell.detailTextLabel.text = NSLocalizedString(@"No", @"No, Not attending");
					break;
					
			}
			break;
		case 2:
			if([indexPath row] == [_recommendedLineup count] || [indexPath row] == 4) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier: nil] autorelease];
				cell.textLabel.text = @"See Full Lineup";
			} else {
				ArtworkCell *artistCell = (ArtworkCell *)[tableView dequeueReusableCellWithIdentifier:[[_recommendedLineup objectAtIndex:[indexPath row]] objectForKey:@"name"]];
				if(artistCell == nil) {
					artistCell = [[[ArtworkCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:[[_recommendedLineup objectAtIndex:[indexPath row]] objectForKey:@"name"]] autorelease];
					artistCell.shouldCacheArtwork = YES;
					artistCell.shouldFillHeight = YES;
					if([indexPath row] == 0)
						artistCell.shouldRoundTop = YES;
					artistCell.title.text = [[_recommendedLineup objectAtIndex:[indexPath row]] objectForKey:@"name"];
					artistCell.imageURL = [[_recommendedLineup objectAtIndex:[indexPath row]] objectForKey:@"image"];
				}
				if(self.navigationController == ((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController.selectedViewController) {
					artistCell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
					artistCell.selectionStyle = UITableViewCellSelectionStyleBlue;
				} else {
					artistCell.accessoryType = UITableViewCellAccessoryNone;
					artistCell.selectionStyle = UITableViewCellSelectionStyleNone;
				}				return artistCell;
			}
			break;
		case 3:
		{
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier: nil] autorelease];
			if([_attendees isKindOfClass:[NSArray class]])
				cell.textLabel.text = [_attendees objectAtIndex:[indexPath row]];
			else
				cell.textLabel.text = (NSString *)_attendees;
			return cell;
		}
			break;
		case 4:
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
		case 5:
		{
			ButtonsCell *buttonscell = (ButtonsCell *)[tableView dequeueReusableCellWithIdentifier:@"ButtonsCell"];
			if(buttonscell == nil) {
				UIButton* share = [UIButton buttonWithType:UIButtonTypeRoundedRect];
				share.titleLabel.font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
				[share setTitle: @"Share" forState:UIControlStateNormal];
				[share addTarget:self action:@selector(share) forControlEvents:UIControlEventTouchUpInside];

				if(NSClassFromString(@"EKEventEditViewController") && (self.navigationController == ((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController.selectedViewController)) {
					UIButton* cal = [UIButton buttonWithType:UIButtonTypeRoundedRect];
					cal.titleLabel.font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
					[cal setTitle: @"Add To Calendar" forState:UIControlStateNormal];
					[cal addTarget:self action:@selector(addToCalendar) forControlEvents:UIControlEventTouchUpInside];
					buttonscell = [[[ButtonsCell alloc] initWithReuseIdentifier:@"ButtonsCell" buttons:cal, share, nil] autorelease];
				} else {
					buttonscell = [[[ButtonsCell alloc] initWithReuseIdentifier:@"ButtonsCell" buttons:share, nil] autorelease];
				}
			}
			return buttonscell;
		}
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
	[_attendingEvents release];
	[_recommendedLineup release];
}

#pragma mark -
#pragma mark EKEventEditViewDelegate

- (void)eventEditViewController:(EKEventEditViewController *)controller 
					didCompleteWithAction:(EKEventEditViewAction)action {
	[controller dismissModalViewControllerAnimated:YES];
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
- (void)viewDidLoad {
	self.tableView.backgroundColor = [UIColor lfmTableBackgroundColor];
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
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
#if !(TARGET_IPHONE_SIMULATOR)
	NSString *status = @"";
	switch([newIndexPath row]) {
		case 0:
			status = @"Yes";
			break;
		case 1:
			status = @"I'm Interested";
			break;
		case 2:
			status = @"No";
			break;
	}
	[FlurryAnalytics logEvent:@"attend" withParameters:[NSDictionary dictionaryWithObjectsAndKeys:
																								[_event objectForKey:@"title"], 
																								@"event",
																								status, 
																								@"status",
																								 nil]];
#endif
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
			cell.textLabel.text = @"I'm Interested";
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

- (id)initWithArtists:(NSArray *)artists recs:(NSArray *)recs {
	
	if (self = [super initWithStyle:UITableViewStyleGrouped]) {
		self.title = @"Lineup";
		if([artists isKindOfClass:[NSArray class]])
			_artists = [artists retain];
		else
			_artists = [[NSArray arrayWithObject:artists] retain];
		_recs = [recs retain];
		if([_recs count])
			data = _recs;
		else
			data = _artists;
	}
	return self;
}
- (void)viewDidLoad {
	self.tableView.backgroundColor = [UIColor lfmTableBackgroundColor];
	if([_recs count]) {
		UISegmentedControl *toggle = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Recommended", @"Full Lineup", nil]];
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
	} else {
		self.navigationItem.titleView = nil;
	}
}
- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	UISegmentedControl *toggle = (UISegmentedControl *)self.navigationItem.titleView;
	if([_recs count] && toggle.selectedSegmentIndex == 0)
		data = _recs;
	else
		data = _artists;
	[self.tableView reloadData];
	[self loadContentForCells:[self.tableView visibleCells]];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [data count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 52;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
#if !(TARGET_IPHONE_SIMULATOR)
	[FlurryAnalytics logEvent:@"view-artist"];
#endif
	if(self.navigationController == ((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController.selectedViewController) {
		NSString *a = nil;
		if([[data objectAtIndex:[indexPath row]] isKindOfClass:[NSDictionary class]])
			a = [[data objectAtIndex:[indexPath row]] objectForKey:@"name"];
		else
			a = [data objectAtIndex:[indexPath row]];
		
		ArtistViewController *artist = [[ArtistViewController alloc] initWithArtist:a];
		[self.navigationController pushViewController:artist animated:YES];
		[artist release];
	}
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"simplecell"];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"simplecell"] autorelease];
	}
	if([[data objectAtIndex:[indexPath row]] isKindOfClass:[NSDictionary class]])
		cell.textLabel.text = [[data objectAtIndex:[indexPath row]] objectForKey:@"name"];
	else
		cell.textLabel.text = [data objectAtIndex:[indexPath row]];
	if(self.navigationController == ((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate).rootViewController.selectedViewController) {
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	} else {
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	return cell;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)dealloc {
	[super dealloc];
	[_artists release];
	[_recs release];
}
@end
