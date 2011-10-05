/* EventDetailsViewController.h - Display event details
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

#import <UIKit/UIKit.h>
#import <EventKit/EventKit.h>
#import <EventKitUI/EventKitUI.h>
#import "LastFMService.h"
#import "ArtworkCell.h"

@interface EventDetailCell : ArtworkCell {
	UILabel *location;
	UILabel *date;
	UILabel *score;
	UILabel *scoreLabel;
	UILabel *days;
	UILabel *daysLabel;
}
@property (nonatomic, retain) UILabel *location;
@property (nonatomic, retain) UILabel *date;
@property (nonatomic, retain) UILabel *score;
@property (nonatomic, retain) UILabel *days;
@end

@interface EventAttendViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource> {
	NSDictionary *_event;
}
- (id)initWithEvent:(NSDictionary *)event;
@end

@interface EventArtistsViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource> {
	NSArray *_artists;
	NSArray *_recs;
	NSArray *data;
}
- (id)initWithArtists:(NSArray *)artists recs:(NSArray *)recs;
@end

@interface EventDetailsViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource,EKEventEditViewDelegate> {
	bool _loaded;
	NSDictionary *_event;
	NSArray *_attendingEvents;
	NSArray *_recommendedLineup;
	NSArray *_attendees;
}
- (id)initWithEvent:(NSDictionary *)event;
@end
