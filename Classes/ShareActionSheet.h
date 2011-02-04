//
//  ShareActionSheet.h
//  MobileLastFM
//
//  Created by Jono Cole on 04/02/2011.
//  Copyright 2011 Last.fm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <AddressBook/ABPerson.h>
#import <AddressBookUI/AddressBookUI.h>
#import "FriendsViewController.h"

@interface ShareActionSheet : UIActionSheet<UIActionSheetDelegate,ABPeoplePickerNavigationControllerDelegate, FriendsViewControllerDelegate, MFMailComposeViewControllerDelegate> {
	NSString* _artist;
	NSString* _track;
	UIViewController* viewController;
}

- (id)initWithTrack:(NSString*)track forArtist:(NSString*)artist;
- (id)initWithArtist:(NSString*)artist;

@property (readwrite, assign) UIViewController* viewController;

@end
