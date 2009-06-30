/* ChartsViewController.h - Charts views and controllers
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
#import <AddressBookUI/AddressBookUI.h>
#import <MessageUI/MessageUI.h>
#import "PlaylistsViewController.h"
#import "LastFMService.h"
#import "FriendsViewController.h"
#import "TagEditorViewController.h"
#import "PlaylistsViewController.h"

@interface TrackCell : UITableViewCell {
	UILabel *title;
	UILabel *subtitle;
	UILabel *date;
}
@property (nonatomic, retain) UILabel *title;
@property (nonatomic, retain) UILabel *subtitle;
@property (nonatomic, retain) UILabel *date;
@end

@interface TopChartViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource> {
	NSArray *_data;
}
- (id)initWithTitle:(NSString *)title;
- (void)setData:(NSArray *)data;
@end

@interface RecentChartViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource, MFMailComposeViewControllerDelegate> {
	NSMutableArray *_data;
	NSDictionary *_selectedTrack;
}
- (id)initWithTitle:(NSString *)title;
- (BOOL)canDeleteRows;
@end

#if 0
@interface RecentlyLovedChartViewController : RecentChartViewController<UIActionSheetDelegate> {
}
- (id)initWithUsername:(NSString *)username;
@end

@interface RecentlyBannedChartViewController : RecentChartViewController {
}
- (id)initWithUsername:(NSString *)username;
@end
#endif

@interface RecentlyPlayedChartViewController : RecentChartViewController<UIActionSheetDelegate,PlaylistsViewControllerDelegate,ABPeoplePickerNavigationControllerDelegate,FriendsViewControllerDelegate,TagEditorViewControllerDelegate> {
}
- (id)initWithUsername:(NSString *)username;
@end

@interface RecentRadioViewController : RecentChartViewController<UIActionSheetDelegate> {
	UIActivityIndicatorView *_progress;
}
- (id)init;
@end

@interface ChartsListViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource> {
	NSString *_username;
}
-(id)initWithUsername:(NSString *)username;
@end
