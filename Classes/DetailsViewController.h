/* DetailsViewController.h - Display currently-playing song details
 * 
 * Copyright 2009 Last.fm Ltd.
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
#import "CalendarViewController.h"

int tagSort(id tag1, id tag2, void *context);

@interface PlaybackSubview : UIViewController {
	IBOutlet UIView *_loadingView;
}
- (void)showLoadingView;
- (void)hideLoadingView;
@end

@interface SimilarArtistsViewController : PlaybackSubview<UITableViewDelegate, UITableViewDataSource> {
	NSArray *_data;
	NSMutableArray *_cells;
	IBOutlet UITableView *_table;
	NSLock *_lock;
}
@end

@interface TagsViewController : PlaybackSubview<UITableViewDelegate, UITableViewDataSource> {
	NSArray *_data;
	IBOutlet UITableView *_table;
	NSLock *_lock;
}
@end

@interface FansViewController : PlaybackSubview<UITableViewDelegate, UITableViewDataSource> {
	NSArray *_data;
	NSMutableArray *_cells;
	IBOutlet UITableView *_table;
	NSLock *_lock;
}
@end

@interface ArtistBioView : PlaybackSubview {
	IBOutlet UIWebView *_webView;
	NSString *_bio;
	NSString *_img, *_listeners, *_playcount;
	NSLock *_lock;
}
- (void)refresh;
@end

@interface EventCell : UITableViewCell {
	UILabel *_eventTitle;
	UILabel *_artists;
	UILabel *_venue;
	UILabel *_location;
}
- (void)setEvent:(NSDictionary *)event;
@end

@interface EventsViewController : PlaybackSubview<CalendarViewControllerDelegate,UITableViewDelegate,UITableViewDataSource> {
	IBOutlet CalendarViewController *_calendar;
	IBOutlet UITableView *_table;
	IBOutlet UIButton *_badge;
	IBOutlet UIImageView *_shadow;
	IBOutlet UILabel *_artistLabel;
	IBOutlet UISegmentedControl *segment;
	NSArray *_events;
	NSMutableArray *_eventDates;
	NSMutableArray *_eventDateCounts;
	NSMutableArray *_eventDateOffsets;
	NSMutableArray *_attendingEvents;
	NSMutableArray *_data;
	NSLock *_lock;
	NSString *_username;
}
- (id)initWithUsername:(NSString *)user;
- (id)initWithUsername:(NSString *)user withEvents:(NSArray *)events;
- (void)doneButtonPressed:(id)sender;
- (void)viewTypeToggled:(id)sender;
@end

@interface EventDetailViewController : UIViewController {
	NSDictionary *event;
	IBOutlet UILabel *_eventTitle;
	IBOutlet UILabel *_artists;
	IBOutlet UILabel *_month;
	IBOutlet UILabel *_day;
	IBOutlet UILabel *_venue;
	IBOutlet UILabel *_address;
	IBOutlet UIImageView *_image;
	IBOutlet UIButton *_willAttendBtn;
	IBOutlet UIButton *_mightAttendBtn;
	IBOutlet UIButton *_notAttendBtn;
	int attendance;
	EventsViewController *delegate;
}
@property (nonatomic, retain) NSDictionary *event;
@property (nonatomic, retain) EventsViewController *delegate;
@property int attendance;
- (IBAction)doneButtonPressed:(id)sender;
- (IBAction)mapsButtonPressed:(id)sender;
- (IBAction)willAttendButtonPressed:(id)sender;
- (IBAction)mightAttendButtonPressed:(id)sender;
- (IBAction)notAttendButtonPressed:(id)sender;
@end

@interface DetailsViewController : UIViewController {
	IBOutlet ArtistBioView *artistBio;
	IBOutlet SimilarArtistsViewController *similarArtists;
	IBOutlet EventsViewController *events;
	IBOutlet TagsViewController *tags;
	IBOutlet FansViewController *fans;
	IBOutlet UIView *detailView;
	IBOutlet UITabBar *tabBar;
	UILabel *_titleLabel;
}
-(void)setTitleLabelView:(UILabel *)label;
-(void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item;
-(void)jumpToEventsTab;
@end