/* PlaybackViewController.h - Display currently-playing song info
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
#import <AddressBookUI/AddressBookUI.h>
#import <MessageUI/MessageUI.h>
#import "LastFMService.h"
#import "ArtworkCell.h"
#import "FriendsViewController.h"
#import "TagEditorViewController.h"
#import "PlaylistsViewController.h"
#import "ArtistViewController.h"

int tagSort(id tag1, id tag2, void *context);

@interface PlaybackSubview : UIViewController {
	IBOutlet UIView *_loadingView;
}
- (void)showLoadingView;
- (void)hideLoadingView;
@end

@interface TrackPlaybackViewController : PlaybackSubview {
	IBOutlet UIImageView *_artworkView;
	IBOutlet UILabel *_trackTitle;
	IBOutlet UILabel *_artist;
	IBOutlet UILabel *_elapsed;
	IBOutlet UILabel *_remaining;
	IBOutlet UIProgressView *_progress;
	IBOutlet UILabel *_bufferPercentage;
	IBOutlet UIImageView *_fullscreenMetadataView;
	IBOutlet UIButton *_badge;
	UIImage *artwork;
	UIImageView *_noArtworkView;
	NSLock *_lock;
	NSTimer *_timer;
	BOOL _showedMetadata;
}
-(void)resignActive;
-(void)becomeActive;
@property (nonatomic, readonly) UIImage *artwork;
@end

@interface PlaybackViewController : UIViewController<ABPeoplePickerNavigationControllerDelegate,FriendsViewControllerDelegate,UIActionSheetDelegate,TagEditorViewControllerDelegate,PlaylistsViewControllerDelegate,MFMailComposeViewControllerDelegate> {
	IBOutlet UILabel *_titleLabel;
	IBOutlet UIToolbar *toolbar;
	IBOutlet UIView *contentView;
	IBOutlet UISegmentedControl *detailType;
	IBOutlet TrackPlaybackViewController *trackView;
	IBOutlet UIView *volumeView;
	IBOutlet UIView *detailsBtnContainer;
	IBOutlet UIButton *detailsBtn;
	IBOutlet UIButton *loveBtn;
	IBOutlet UIButton *banBtn;
	
	ArtistViewController *artistViewController;
}
-(void)backButtonPressed:(id)sender;
-(void)detailsButtonPressed:(id)sender;
-(void)actionButtonPressed:(id)sender;
-(void)loveButtonPressed:(id)sender;
-(void)banButtonPressed:(id)sender;
-(void)stopButtonPressed:(id)sender;
-(void)skipButtonPressed:(id)sender;
-(void)onTourButtonPressed:(id)sender;
-(void)hideDetailsView;
-(void)resignActive;
-(void)becomeActive;
-(BOOL)releaseDetailsView;
@end
