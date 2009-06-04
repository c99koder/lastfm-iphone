/* TagEditorViewController.h - Displays and manages a modal tag editor view
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

@class TagEditorViewController;

@interface TagView : UIImageView {
	NSString *tag;
}
@property (readonly, nonatomic) NSString *tag;
- (id)initWithTag:(NSString *)tag;
@end

@interface TagEditorView : UIScrollView {
	NSMutableArray *tags;
	IBOutlet UITextField *textField;
	TagView *lastTag;
	IBOutlet UILabel *instructions;
	TagEditorViewController *delegate;
}
- (void)addTag:(NSString *)tag animated:(BOOL)animated;
- (void)removeTag:(TagView *)tag;
- (BOOL)hasTag:(NSString *)tag;
- (NSArray *)tags;
- (void)setTags:(NSArray *)tags;
@end

@protocol TagEditorViewControllerDelegate
- (void)tagEditorDidCancel;
- (void)tagEditorAddArtistTags:(NSArray *)artistTags albumTags:(NSArray *)albumTags trackTags:(NSArray *)trackTags;
- (void)tagEditorRemoveArtistTags:(NSArray *)artistTags albumTags:(NSArray *)albumTags trackTags:(NSArray *)trackTags;
@end

@interface TagEditorViewController : UIViewController<UITableViewDataSource,UITableViewDelegate,UITabBarDelegate,UITextFieldDelegate> {
	IBOutlet TagEditorView *tagEditorView;
	IBOutlet UITabBar *tabBar;
	IBOutlet UITableView *table;
	IBOutlet UITextField *textField;
	IBOutlet UISegmentedControl *tagType;
	NSArray *artistTopTags, *albumTopTags, *trackTopTags;
	NSArray *myTags;
	NSArray *topTags;
	NSMutableDictionary *artistTagActions, *albumTagActions, *trackTagActions;
	NSMutableDictionary *tagActions;
	id<TagEditorViewControllerDelegate> delegate;
}
@property (retain, nonatomic) NSArray *artistTopTags;
@property (retain, nonatomic) NSArray *albumTopTags;
@property (retain, nonatomic) NSArray *trackTopTags;
@property (retain, nonatomic) NSArray *myTags;
@property (retain, nonatomic) id<TagEditorViewControllerDelegate> delegate;
- (IBAction)tagButtonPressed:(id)sender;
- (IBAction)cancelButtonPressed:(id)sender;
- (IBAction)doneButtonPressed:(id)sender;
- (IBAction)tagTypeChanged:(id)sender;
- (void)tagAdded:(NSString *)tag;
- (void)tagRemoved:(NSString *)tag;
- (void)reload;
- (void)setAlbumTags:(NSArray *)tags;
- (void)setArtistTags:(NSArray *)tags;
- (void)setTrackTags:(NSArray *)tags;
@end
