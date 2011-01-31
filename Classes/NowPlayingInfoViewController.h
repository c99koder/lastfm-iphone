//
//  NowPlayingInfoViewController.h
//  MobileLastFM
//
//  Created by Sam Steele on 1/26/11.
//  Copyright 2011 Last.fm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AddressBookUI/AddressBookUI.h>
#import <MessageUI/MessageUI.h>
#import "FriendsViewController.h"
#import "TagEditorViewController.h"
#import "Three20/Three20.h"


@interface NowPlayingInfoViewController : UITableViewController<ABPeoplePickerNavigationControllerDelegate,FriendsViewControllerDelegate,UIActionSheetDelegate,TagEditorViewControllerDelegate,MFMailComposeViewControllerDelegate> {
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
