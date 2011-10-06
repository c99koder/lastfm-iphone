/* TagViewController.h - Display a tag
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
#import "Three20/Three20.h"
#import "LastFMService.h"

@interface TagViewController : UITableViewController<UITableViewDelegate, UITableViewDataSource> {
	NSString *_tag;
	NSArray *_data;
	NSArray *_tracks;
	NSArray *_albums;
	NSArray *_artists;
	NSArray *_tags;
	NSDictionary *_metadata;
	TTStyledTextLabel *_bioView;
	TTStyledTextLabel *_tagsView;
	BOOL _tracksDidLoad;
	BOOL _albumsDidLoad;
	BOOL _artistsDidLoad;
	BOOL _similarTagsDidLoad;
}
- (id)initWithTag:(NSString *)tag;
- (void)rebuildMenu;
@end
