/* TagEditorViewController.h - Displays and manages a modal tag editor view
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

@interface TagView : UIImageView {
	NSString *tag;
}
@property (readonly, nonatomic) NSString *tag;
- (id)initWithTag:(NSString *)tag;
@end

@interface TagEditorView : UIView {
	NSMutableArray *tags;
	IBOutlet UITextField *textField;
}
- (void)addTag:(NSString *)tag;
- (void)removeTag:(TagView *)tag;
- (NSArray *)tags;
@end

@protocol TagEditorViewControllerDelegate
- (void)tagEditorDidCancel;
- (void)tagEditorCommitTags:(NSArray *)tags;
@end

@interface TagEditorViewController : UIViewController<UITableViewDataSource,UITableViewDelegate,UITabBarDelegate,UITextFieldDelegate> {
	IBOutlet TagEditorView *tagEditorView;
	IBOutlet UITabBar *tabBar;
	IBOutlet UITableView *table;
	IBOutlet UITextField *textField;
	NSArray *topTags;
	NSArray *myTags;
	id<TagEditorViewControllerDelegate> delegate;
}
@property (retain, nonatomic) NSArray *tags;
@property (retain, nonatomic) NSArray *topTags;
@property (retain, nonatomic) NSArray *myTags;
@property (retain, nonatomic) id<TagEditorViewControllerDelegate> delegate;
- (IBAction)tagButtonPressed:(id)sender;
- (IBAction)cancelButtonPressed:(id)sender;
- (IBAction)doneButtonPressed:(id)sender;
@end
