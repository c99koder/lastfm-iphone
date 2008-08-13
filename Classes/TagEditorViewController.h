//
//  TagEditorViewController.h
//  MobileLastFM
//
//  Created by Sam Steele on 8/13/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

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

@interface TagEditorViewController : UIViewController<UITableViewDataSource,UITableViewDelegate,UITabBarDelegate,UITextFieldDelegate> {
	IBOutlet TagEditorView *tagEditorView;
	IBOutlet UITabBar *tabBar;
	IBOutlet UITableView *table;
	IBOutlet UITextField *textField;
	NSArray *topTags;
	NSArray *myTags;
	id delegate;
}
@property (retain, nonatomic) NSArray *tags;
@property (retain, nonatomic) NSArray *topTags;
@property (retain, nonatomic) NSArray *myTags;
@property (retain, nonatomic) id delegate;
- (IBAction)tagButtonPressed:(id)sender;
- (IBAction)cancelButtonPressed:(id)sender;
- (IBAction)doneButtonPressed:(id)sender;
@end
