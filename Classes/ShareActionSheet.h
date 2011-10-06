/* ShareActionSheet.h - Display an share action sheet
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
#import <MessageUI/MessageUI.h>
#import <AddressBook/ABPerson.h>
#import <AddressBookUI/AddressBookUI.h>
#import "FriendsViewController.h"

@interface ShareActionSheet : UIActionSheet<UIActionSheetDelegate,ABPeoplePickerNavigationControllerDelegate, FriendsViewControllerDelegate, MFMailComposeViewControllerDelegate> {
	NSString* _artist;
	NSString* _track;
	NSString* _album;
	NSDictionary *_event;
	UIViewController* viewController;
	UIStatusBarStyle barStyle;
}

- (id)initWithTrack:(NSString*)track byArtist:(NSString*)artist;
- (id)initWithAlbum:(NSString*)track byArtist:(NSString*)artist;
- (id)initWithArtist:(NSString*)artist;
- (id)initWithEvent:(NSDictionary*)event;

@property (readwrite, assign) UIViewController* viewController;

@end
