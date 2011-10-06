/* FriendsViewController.h - Display Last.fm friends list
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
#import "LastFMService.h"

@class FriendsViewController;

@protocol FriendsViewControllerDelegate
-(void)friendsViewController:(FriendsViewController *)controller didSelectFriend:(NSString *)username;
-(void)friendsViewControllerDidCancel:(FriendsViewController *)controller;
@end

@interface FriendsViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource, UISearchDisplayDelegate> {
	NSString *_username;
	NSArray *_friendsListeningNow;
	NSArray *_eqFrames;
	NSMutableArray *_searchResults;
	NSArray *_data;
	id<FriendsViewControllerDelegate> delegate;
}
- (id)initWithUsername:(NSString *)username;
@property (nonatomic, retain) id<FriendsViewControllerDelegate> delegate;
@end

