/* TrackViewController.h - Display a track
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
#import "Three20/Three20.h"
#import "LastFMService.h"
#import "TagEditorViewController.h"
#import "FriendsViewController.h"

@interface TrackViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource, TagEditorViewControllerDelegate, UIWebViewDelegate> {
	NSString *_artist;
	NSString *_track;
	NSArray *_data;
	NSArray *_tags;
	NSDictionary *_metadata;
	TTStyledTextLabel *_bioView;
	TTStyledTextLabel *_tagsView;
	BOOL _loved;
	BOOL _addedToLibrary;
}
- (id)initWithTrack:(NSString *)track byArtist:(NSString *)artist;
- (void)rebuildMenu;
@end
