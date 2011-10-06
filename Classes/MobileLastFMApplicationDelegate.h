/* MobileLastFMApplicationDelegate.h - Main application controller
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
#import "LastFMRadio.h"
#import "Scrobbler.h"
#import "FirstRunViewController.h"
#import "PlaybackViewController.h"
#import "RadioListViewController.h"
#import "HomeViewController.h"

@interface MobileLastFMAppWindow : UIWindow {
}
@end

@interface MobileLastFMApplicationDelegate : NSObject<UIApplicationDelegate,UIActionSheetDelegate> {
  IBOutlet MobileLastFMAppWindow *window;
	Scrobbler *_scrobbler;
	FirstRunViewController *firstRunView;
	PlaybackViewController *playbackViewController;
	RadioListViewController *radioListViewController;
	UIView *_mainView;
	IBOutlet UIView *_loadingView;
	IBOutlet UIImageView *_loadingViewLogo;
	HomeViewController *rootViewController;
	NSString *_launchURL;
	UIAlertView *_pendingAlert;
	UIAlertView *_trialAlert;
	NSString *_trialAlertStation;
	BOOL _locked;
	BOOL _launched;
}

@property (nonatomic, retain) MobileLastFMAppWindow *window;
@property (readonly) FirstRunViewController *firstRunView;
@property (readonly) PlaybackViewController *playbackViewController;
@property (readonly) HomeViewController *rootViewController;

-(BOOL)hasNetworkConnection;
-(BOOL)hasWiFiConnection;
-(BOOL)playRadioStation:(NSString *)station animated:(BOOL)animated;
-(void)displayError:(NSString *)error withTitle:(NSString *)title;
-(BOOL)isPlaying;
-(BOOL)isPaused;
-(NSDictionary *)trackInfo;
-(int)trackPosition;
-(IBAction)loveButtonPressed:(UIButton *)sender;
-(IBAction)banButtonPressed:(UIButton *)sender;
-(IBAction)skipButtonPressed:(id)sender;
-(IBAction)pauseButtonPressed:(id)sender;
-(NSURLRequest *)requestWithURL:(NSURL *)url;
-(void)showPlaybackView;
-(void)hidePlaybackView;
-(void)showProfileView:(BOOL)animated;
-(void)showFirstRunView:(BOOL)animated;
-(void)reportError:(NSError *)error;
-(IBAction)logoutButtonPressed:(id)sender;
@end
