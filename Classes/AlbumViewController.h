/* AlbumViewController.h - Display an album
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
#import "Three20/Three20.h"
#import "TagEditorViewController.h"

@interface AlbumViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource, TagEditorViewControllerDelegate> {
	NSString *_artist;
	NSString *_album;
	NSArray *_data;
	NSArray *_tags;
	NSArray *_tracks;
	NSDictionary *_metadata;
	TTStyledTextLabel *_tagsView;
}
- (id)initWithAlbum:(NSString *)album byArtist:(NSString *)artist;
- (void)rebuildMenu;
@end
