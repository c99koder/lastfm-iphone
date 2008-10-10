/* MobileLastFMApplicationDelegate.h - Main application controller
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
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <IOKit/IOMessage.h>
#import "LastFMRadio.h"
#import "Scrobbler.h"
#import "FirstRunViewController.h"
#import "PlaybackViewController.h"
#import "SearchViewController.h"
#import "AdMobDelegateProtocol.h"

@interface UIApplication (Undocumented)
-(void)showNetworkPromptsIfNecessary:(BOOL)fp8;
-(void)setUsesBackgroundNetwork:(BOOL)fp8;
@end

@interface MobileLastFMApplicationDelegate : NSObject<UIApplicationDelegate,UIActionSheetDelegate,AdMobDelegate> {
  IBOutlet UIWindow *window;
	Scrobbler *_scrobbler;
	FirstRunViewController *firstRunView;
	PlaybackViewController *playbackViewController;
	UIView *_mainView;
	IBOutlet UIView *_loadingView;
	IBOutlet UIImageView *_loadingViewLogo;
	UINavigationController *rootViewController;
	NSString *_launchURL;
	UIAlertView *_pendingAlert;
	BOOL _locked;
	io_connect_t root_port;
	io_object_t notifier;
}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) FirstRunViewController *firstRunView;
@property (nonatomic, retain) PlaybackViewController *playbackViewController;
@property (nonatomic, retain) UINavigationController *rootViewController;

-(UITabBarController *)profileViewForUser:(NSString *)username;
-(void)powerMessageReceived:(natural_t)messageType withArgument:(void *) messageArgument;
-(BOOL)hasNetworkConnection;
-(BOOL)hasWiFiConnection;
-(BOOL)playRadioStation:(NSString *)station animated:(BOOL)animated;
-(void)displayError:(NSString *)error withTitle:(NSString *)title;
-(BOOL)isPlaying;
-(NSDictionary *)trackInfo;
-(int)trackPosition;
-(IBAction)loveButtonPressed:(UIButton *)sender;
-(IBAction)banButtonPressed:(UIButton *)sender;
-(IBAction)skipButtonPressed:(id)sender;
-(IBAction)stopButtonPressed:(id)sender;
-(NSURLRequest *)requestWithURL:(NSURL *)url;
-(void)showPlaybackView;
-(void)hidePlaybackView;
-(void)showProfileView:(BOOL)animated;
-(void)showFirstRunView:(BOOL)animated;
-(void)reportError:(NSError *)error;
-(IBAction)logoutButtonPressed:(id)sender;
-(void)sendCrashReport;
@end
