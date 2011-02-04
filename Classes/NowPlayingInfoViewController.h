/* NowPlayingInfoViewController.h - Info about the currently-playing track
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
#import <AddressBookUI/AddressBookUI.h>
#import <MessageUI/MessageUI.h>
#import "FriendsViewController.h"
#import "TagEditorViewController.h"
#import "Three20/Three20.h"


@interface NowPlayingInfoViewController : UITableViewController<TagEditorViewControllerDelegate> {
	NSDictionary *_trackInfo;
	NSString *_artistImageURL;
	TTStyledTextLabel *_trackStatsView;
	TTStyledTextLabel *_artistStatsView;
	TTStyledTextLabel *_trackTagsView;
	TTStyledTextLabel *_artistBioView;
	BOOL _loaded;
}
- (id)initWithTrackInfo:(NSDictionary *)trackInfo;
@end
