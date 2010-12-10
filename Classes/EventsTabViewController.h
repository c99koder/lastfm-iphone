/* EventsTabViewController.h - Display various kinds of events for a user
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

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "LastFMService.h"

@interface MiniEventCell : UITableViewCell {
	UIImageView *_datebg;
	UILabel *title;
	UILabel *location;
	UILabel *month;
	UILabel *day;
}
@property (nonatomic, retain) UILabel *title;
@property (nonatomic, retain) UILabel *location;
@property (nonatomic, retain) UILabel *month;
@property (nonatomic, retain) UILabel *day;
@end

@interface EventListViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource> {
	NSArray *_events;
}
- (id)initWithEvents:(NSArray *)events;
@end

@interface EventsTabViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate> {
	CLLocationManager *_locationManager;
	NSString *_username;
	NSArray *_events;
	NSArray *_recs;
}
- (id)initWithUsername:(NSString *)username;
@end
