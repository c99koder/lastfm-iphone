/* ChartsViewController.h - Charts views and controllers
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
#import "PlaylistsViewController.h"
#import "LastFMService.h"
#import <AddressBookUI/AddressBookUI.h>
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

@interface RecentChartViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource> {
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
