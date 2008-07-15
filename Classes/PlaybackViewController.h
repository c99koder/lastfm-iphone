/* PlaybackViewController.h - Display currently-playing song info
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

#import <UIKit/UIKit.h>
#import <AddressBookUI/AddressBookUI.h>
#import "LastFMService.h"
#import "ArtworkCell.h"
#import "FriendsViewController.h"

@interface PlaybackSubview : UIViewController {
	IBOutlet UINavigationBar *_bar;
	IBOutlet UIButton *_loveButton;
	IBOutlet UIButton *_banButton;
}
- (void)backButtonPressed:(id)sender;
- (void)volumeButtonPressed:(id)sender;
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

@interface TrackViewController : PlaybackSubview<ABPeoplePickerNavigationControllerDelegate,FriendsViewControllerDelegate,UIActionSheetDelegate> {
	IBOutlet UIImageView *_artworkView;
	IBOutlet UILabel *_trackTitle;
	IBOutlet UILabel *_artist;
	IBOutlet UILabel *_album;
	IBOutlet UILabel *_elapsed;
	IBOutlet UILabel *_remaining;
	IBOutlet UIProgressView *_progress;
	IBOutlet UIView *_bufferingView;
	IBOutlet UILabel *_bufferPercentage;
	IBOutlet UILabel *_station;
}
- (void)buyButtonPressed:(id)sender;
- (void)shareButtonPressed:(id)sender;
@end

@interface ArtistBioView : PlaybackSubview {
	IBOutlet UIWebView *_webView;
	NSString *_bio;
	NSLock *_lock;
}
- (void)refresh;
@end

@interface EventCell : UITableViewCell {
	UILabel *_title;
	UILabel *_venue;
	UILabel *_location;
}
- (void)setEvent:(NSDictionary *)event;
@end

@interface EventsListViewController : PlaybackSubview<UITableViewDelegate, UITableViewDataSource> {
	NSArray *_events;
	NSMutableArray *_eventDates;
	NSMutableArray *_attendingEvents;
	IBOutlet UITableView *_table;
	NSLock *_lock;
	NSString *_username;
}
- (id)initWithUsername:(NSString *)user;
- (NSString *)formatDate:(NSString *)date;
- (void)doneButtonPressed:(id)sender;
@end

@interface EventDetailViewController : UIViewController<UIPickerViewDelegate, UIPickerViewDataSource> {
	NSDictionary *event;
	IBOutlet UILabel *_eventTitle;
	IBOutlet UILabel *_artists;
	IBOutlet UILabel *_month;
	IBOutlet UILabel *_day;
	IBOutlet UILabel *_venue;
	IBOutlet UILabel *_address;
	IBOutlet UIImageView *_image;
	IBOutlet UIPickerView *_attendance;
	EventsListViewController *delegate;
}
@property (nonatomic, retain) NSDictionary *event;
@property (nonatomic, retain) EventsListViewController *delegate;
- (IBAction)doneButtonPressed:(id)sender;
- (IBAction)mapsButtonPressed:(id)sender;
- (int)attendance;
- (void)setAttendance:(int)status;
@end

@interface PlaybackViewController : UITabBarController<UIActionSheetDelegate> {
}
-(void)loveButtonPressed:(id)sender;
-(void)banButtonPressed:(id)sender;
-(void)stopButtonPressed:(id)sender;
-(void)skipButtonPressed:(id)sender;
@end
