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
#import "CalendarViewController.h"
#import "TagEditorViewController.h"
#import "PlaylistsViewController.h"

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

@interface TrackViewController : PlaybackSubview {
	IBOutlet UIImageView *_artworkView;
	IBOutlet UIImageView *_reflectedArtworkView;
	IBOutlet UIImageView *_reflectionGradientView;
	IBOutlet UILabel *_trackTitle;
	IBOutlet UILabel *_artist;
	IBOutlet UILabel *_elapsed;
	IBOutlet UILabel *_remaining;
	IBOutlet UIProgressView *_progress;
	IBOutlet UILabel *_bufferPercentage;
	IBOutlet UIView *_fullscreenMetadataView;
	IBOutlet UIButton *_badge;
	UIImage *artwork;
	NSLock *_lock;
}
-(IBAction)artworkButtonPressed:(id)sender;
@property (nonatomic, readonly) UIImage *artwork;
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

@interface PlaybackViewController : UIViewController<ABPeoplePickerNavigationControllerDelegate,FriendsViewControllerDelegate,UIActionSheetDelegate,TagEditorViewControllerDelegate,PlaylistsViewControllerDelegate> {
	IBOutlet UILabel *_titleLabel;
	IBOutlet UIToolbar *toolbar;
	IBOutlet UIView *contentView;
	IBOutlet UIView *detailsViewContainer;
	IBOutlet UIView *detailView;
	IBOutlet UISegmentedControl *detailType;
	IBOutlet TrackViewController *trackView;
	IBOutlet ArtistBioView *artistBio;
	IBOutlet SimilarArtistsViewController *similarArtists;
	IBOutlet EventsViewController *events;
	IBOutlet TagsViewController *tags;
	IBOutlet FansViewController *fans;
	IBOutlet UIView *volumeView;
	IBOutlet UIView *detailsBtnContainer;
	IBOutlet UIButton *detailsBtn;
	IBOutlet UIButton *loveBtn;
	IBOutlet UIButton *banBtn;
	IBOutlet UITabBar *tabBar;
}
-(void)backButtonPressed:(id)sender;
-(void)detailsButtonPressed:(id)sender;
-(void)actionButtonPressed:(id)sender;
-(void)loveButtonPressed:(id)sender;
-(void)banButtonPressed:(id)sender;
-(void)stopButtonPressed:(id)sender;
-(void)skipButtonPressed:(id)sender;
-(void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item;
-(void)onTourButtonPressed:(id)sender;
-(void)hideDetailsView;
@end
