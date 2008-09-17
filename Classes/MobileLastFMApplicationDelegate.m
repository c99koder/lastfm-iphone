/* MobileLastFMApplication.m - Main application controller
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

#import "NSString+MD5.h"
#import "MobileLastFMApplicationDelegate.h"
#import "ProfileViewController.h"
#import "RadioListViewController.h"
#import "PlaybackViewController.h"
#include "version.h"
#include <SystemConfiguration/SCNetworkReachability.h>
#import "NSString+URLEscaped.h"
#import "NSData+Compress.h"

void powerCallback(void *refCon, io_service_t service, natural_t messageType, void *messageArgument) {	
	[(MobileLastFMApplicationDelegate *)refCon powerMessageReceived: messageType withArgument: messageArgument];
}

NSString *kUserAgent;

@implementation MobileLastFMApplicationDelegate

@synthesize window;
@synthesize firstRunView;
@synthesize playbackViewController;
@synthesize rootViewController;

-(void)powerMessageReceived:(natural_t)messageType withArgument:(void *)messageArgument {
	switch (messageType) {
		case kIOMessageSystemWillSleep:
			IOAllowPowerChange(root_port, (long)messageArgument);  
			break;
		case kIOMessageCanSystemSleep:
			if([[LastFMRadio sharedInstance] state] != RADIO_IDLE)
				IOCancelPowerChange(root_port, (long)messageArgument);
			else
				IOAllowPowerChange(root_port, (long)messageArgument);  
			break; 
		case kIOMessageSystemHasPoweredOn:
			break;
	}
}
- (void)applicationWillTerminate:(UIApplication *)application {
	
	if([[LastFMRadio sharedInstance] state] != RADIO_IDLE)
		[[LastFMRadio sharedInstance] stop];
	
	[_scrobbler saveQueue];
}
-(void)_cleanCache {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[NSThread setThreadPriority:0.1];
	
	NSDirectoryEnumerator *e = [[NSFileManager defaultManager] enumeratorAtPath:NSTemporaryDirectory()];
	NSString *file;
	
	NSLog(@"Checking for stale cache files in the background...\n");
	while((file = [e nextObject])) {
		NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:file];
		NSDictionary *attr = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES];
		if([attr objectForKey:NSFileType] == NSFileTypeRegular && 
			 ![file isEqualToString:@"recent.db"] &&
			 ![file isEqualToString:@"queue.plist"] &&
			 ([[attr objectForKey:NSFileModificationDate] timeIntervalSinceNow] * -1) > 7*DAYS) {
			NSLog(@"Removing stale cache file: %@ (%f days old)\n", file, ([[attr objectForKey:NSFileModificationDate] timeIntervalSinceNow] * -1) / DAYS);
			[[NSFileManager defaultManager] removeItemAtPath:path error:nil];
		}
	}
	NSLog(@"Finished checking for stale cache files.\n");
	[pool release];
}
- (id)init {
	if (self = [super init]) {
		kUserAgent = [[NSString alloc] initWithFormat:@"MobileLastFM/%@ (%@; %@; %@ %@)", VERSION, [UIDevice currentDevice].model, [[[NSUserDefaults standardUserDefaults] objectForKey: @"AppleLanguages"] objectAtIndex:0], [UIDevice currentDevice].systemName, [UIDevice currentDevice].systemVersion];
		NSLog(@"%@", kUserAgent);
		[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
																														 [NSNumber numberWithFloat: 0.8], @"volume",
																														 @"YES", @"scrobbling",
																														 @"YES", @"disableautolock",
																														 @"YES", @"showontour",
																														 nil]];
		if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"scrobbling"] isKindOfClass:[NSString class]])
			[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"scrobbling"];
		[NSThread detachNewThreadSelector:@selector(_cleanCache) toTarget:self withObject:nil];
	}
	return self;
}
- (void)_logout {
	if([[LastFMRadio sharedInstance] state] != RADIO_IDLE)
		[[LastFMRadio sharedInstance] stop];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lastfm_user"];
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"lastfm_session"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	[LastFMService sharedInstance].session = nil;
	[[LastFMRadio sharedInstance] purgeRecentURLs];
	[_scrobbler cancelTimer];
	[_scrobbler release];
	_scrobbler = nil;
	[self showFirstRunView:YES];
}
- (void)logoutButtonPressed:(id)sender {
	UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"LOGOUT_TITLE", @"Logout confirmation title")
																									 message:NSLocalizedString(@"LOGOUT_BODY",@"Logout confirmation")
																									delegate:self
																				 cancelButtonTitle:NSLocalizedString(@"Cancel", @"cancel")
																				 otherButtonTitles:NSLocalizedString(@"Logout", @"Logout"), nil] autorelease];
	[alert show];
}
- (void)applicationWillResignActive:(UIApplication *)application {
	_locked = YES;
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
	_locked = NO;
	if(_pendingAlert)
		[_pendingAlert show];
}
- (void)sendCrashReport {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *url = [NSString stringWithFormat:@"http://oops.last.fm/logsubmission/add?username=%@&platform=%@&clientname=iPhoneFM&clientversion=%@",
									 [[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"] URLEscaped],
									 [[UIDevice currentDevice].model URLEscaped],
									 VERSION];

	NSMutableData *body = [NSMutableData data];
	[body appendData:[[NSString stringWithFormat:@"--8e61d618ca16\r\nContent-Disposition: form-data; name=\"usernotes\"\r\n\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[[NSString stringWithFormat:@"--8e61d618ca16\r\nContent-Disposition: form-data; name=\"logs\"\r\n\r\ncrash.log\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[[NSString stringWithFormat:@"--8e61d618ca16\r\nContent-Disposition: form-data; name=\"crash.log\"\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[[NSData dataWithContentsOfFile:CACHE_FILE(@"crash.log")] compressWithLevel:9]];
	[body appendData:[[NSString stringWithFormat:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
	[body appendData:[[NSString stringWithFormat:@"--8e61d618ca16--"] dataUsingEncoding:NSUTF8StringEncoding]];

	NSData *theResponseData;
	NSHTTPURLResponse *theResponse = NULL;
	NSError *theError = NULL;
	NSMutableURLRequest *theRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:[((MobileLastFMApplicationDelegate *)[UIApplication sharedApplication].delegate) hasWiFiConnection]?40:60];
	[theRequest setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
	[theRequest setValue:@"multipart/form-data;boundary=8e61d618ca16" forHTTPHeaderField:@"Content-Type"];
	[theRequest setHTTPMethod:@"POST"];
	[theRequest setHTTPBody:body];
	
	theResponseData = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&theError];

	if([theResponse statusCode] == 200) {
		[[NSFileManager defaultManager] removeItemAtPath:CACHE_FILE(@"crash.log") error:nil];
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"crashed"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[self displayError:NSLocalizedString(@"CRASH_REPORT_SUCCESS", @"Crash report sucessfully sent") withTitle:NSLocalizedString(@"CRASH_REPORT_SUCCESS_TITLE", @"Crash report sucessfully sent title")];
	} else {
		[self displayError:NSLocalizedString(@"CRASH_REPORT_FAIL", @"Crash report failed to send") withTitle:NSLocalizedString(@"CRASH_REPORT_SUCCESS_TITLE", @"Crash report failed to send title")];
	}
	
	[pool release];
}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Logout", @"Logout")])
		[self performSelectorOnMainThread:@selector(_logout) withObject:nil waitUntilDone:YES];
	if([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Cancel", @"Cancel")])
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"crashed"];
	if([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:NSLocalizedString(@"Send", @"Send")])
		[NSThread detachNewThreadSelector:@selector(sendCrashReport) toTarget:self withObject:nil];
	if(_pendingAlert) {
		[_pendingAlert release];
		_pendingAlert = nil;
	}
}
- (UITabBarController *)profileViewForUser:(NSString *)username {
	UITabBarController *tabBarController = [[UITabBarController alloc] init];
	tabBarController.title = username;
	RadioListViewController *r = [[RadioListViewController alloc] initWithUsername:username];
	UITabBarItem *t = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Radio", @"Radio tab label") image:[UIImage imageNamed:@"radio_icon_tab.png"] tag:0];
	r.tabBarItem = t;
	[t release];
	
	ProfileViewController *p = [[ProfileViewController alloc] initWithUsername:username];
	t = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Profile", @"Profile tab label") image:[UIImage imageNamed:@"profile_icon_tab.png"] tag:1];
	p.tabBarItem = t;
	[t release];

	/*UINavigationController *radioNavController = [[UINavigationController alloc] initWithRootViewController:r];
	radioNavController.tabBarItem = t;
	radioNavController.navigationBar.barStyle = UIBarStyleBlackOpaque;*/

	/*UINavigationController *profileNavController = [[UINavigationController alloc] initWithRootViewController:p];
	profileNavController.tabBarItem = t;
	profileNavController.navigationBar.barStyle = UIBarStyleBlackOpaque;*/

	tabBarController.viewControllers = [NSArray arrayWithObjects:r, p, nil];
	//[radioNavController release];
	//[profileNavController release];

	/*if(subview) {
		tabBarController.hidesBottomBarWhenPushed = YES;
		UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"Back Button")
																																		 style:UIBarButtonItemStylePlain 
																																		target:self
																																		action:@selector(hidePlaybackView)];	
		for(UINavigationController *n in tabBarController.viewControllers) { 
			n.topViewController.navigationItem.leftBarButtonItem = backButton;
		}
		
		[backButton release];
	} else {
		for(UINavigationController *n in tabBarController.viewControllers) { 
			n.topViewController.navigationItem.leftBarButtonItem = logoutButton;
		}
		
		[logoutButton release];
	}*/
	
	[r release];
	[p release];
	
	return tabBarController;
}
- (void)showProfileView:(BOOL)animated {
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	if(!_scrobbler) {
		_scrobbler = [[Scrobbler alloc] init];
	}
	NSDictionary *info = [[LastFMService sharedInstance] profileForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	if([[info objectForKey:@"country"] length]) {
		[[NSUserDefaults standardUserDefaults] setObject:[info objectForKey:@"country"] forKey:@"country"];
	}
	if([[info objectForKey:@"icon"] length]) {
		if([[info objectForKey:@"icon"] isEqualToString:@"http://cdn.last.fm/depth/global/icon_user.gif"]) {
			[[NSUserDefaults standardUserDefaults] setObject:@"0" forKey:@"lastfm_subscriber"];
		} else {
			[[NSUserDefaults standardUserDefaults] setObject:@"1" forKey:@"lastfm_subscriber"];
		}
	}
	
	UITabBarController *profile = [self profileViewForUser:[[NSUserDefaults standardUserDefaults] objectForKey:@"lastfm_user"]];
	UIBarButtonItem *logoutButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Logout", @"Logout Button")
																																	 style:UIBarButtonItemStylePlain 
																																	target:self
																																	action:@selector(logoutButtonPressed:)];	
	profile.navigationItem.leftBarButtonItem = logoutButton;
	[logoutButton release];
	[rootViewController release];
	rootViewController = [[UINavigationController alloc] initWithRootViewController:profile];
	rootViewController.navigationBar.barStyle = UIBarStyleBlackOpaque;
	
	if(animated) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:_mainView cache:YES];
		[UIView setAnimationDuration:0.4];
	}
	[[_mainView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[_mainView addSubview:[rootViewController view]];
	if(animated)
		[UIView commitAnimations];

	[LastFMService sharedInstance].session = [[NSUserDefaults standardUserDefaults] objectForKey: @"lastfm_session"];
	[firstRunView release];
	firstRunView = nil;
	if(_launchURL) {
		[self playRadioStation:_launchURL animated:YES];
		[_launchURL release];
		_launchURL = nil;
	}

	if([[NSUserDefaults standardUserDefaults] objectForKey:@"crashed"]) {
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"CRASH_REPORT_TITLE", @"Crash reporter title")
																										 message:NSLocalizedString(@"CRASH_REPORT_BODY",@"Crash reporter body")
																										delegate:self
																					 cancelButtonTitle:NSLocalizedString(@"Cancel", @"cancel")
																					 otherButtonTitles:NSLocalizedString(@"Send", @"Send"), nil] autorelease];
		[alert show];
	}
}
-(void)showFirstRunView:(BOOL)animated {
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:YES];
	if(!firstRunView) {
		firstRunView = [[FirstRunViewController alloc] initWithNibName:@"FirstRunView" bundle:nil];
		firstRunView.view.frame = [UIScreen mainScreen].applicationFrame;
	}

	if(animated) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:_mainView cache:YES];
		[UIView setAnimationDuration:0.4];
	}
	[[_mainView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[_mainView addSubview:firstRunView.view];
	if(animated)
		[UIView commitAnimations];
}
- (void)_loadProfile {
	[self showProfileView:YES];
	[_loadingView removeFromSuperview];
}
- (void)applicationDidFinishLaunching:(UIApplication *)application {
	[[UIApplication sharedApplication] showNetworkPromptsIfNecessary:YES];
	IONotificationPortRef notificationPort;
  root_port = IORegisterForSystemPower(self, &notificationPort, powerCallback, &notifier);
  CFRunLoopAddSource(CFRunLoopGetCurrent(),IONotificationPortGetRunLoopSource(notificationPort),kCFRunLoopCommonModes);
	_mainView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[window addSubview:_mainView];

	for(NSObject *object in [[NSBundle mainBundle] loadNibNamed:@"PlaybackView" owner:self options:nil]) {
		if([object isKindOfClass:[PlaybackViewController class]]) {
			playbackViewController = [object retain];
			break;
		}
	}
	if(!playbackViewController) {
		NSLog(@"Failed to load playback view!\n");
	}	
	
	if([[[NSUserDefaults standardUserDefaults] objectForKey: @"lastfm_session"] length] > 0) {
		NSMutableArray *frames = [[NSMutableArray alloc] init];
		int i;
		for(i=1; i<=68; i++) {
			NSString *filename = [NSString stringWithFormat:@"logo_animation_cropped%04i.png", i];
			[frames addObject:[UIImage imageNamed:filename]];
		}
		_loadingViewLogo.animationImages = frames;
		[frames release];
		_loadingViewLogo.animationDuration = 2;
		[_loadingViewLogo startAnimating];
		_loadingView.frame = [UIScreen mainScreen].applicationFrame;
		[_mainView addSubview:_loadingView];
		[self performSelector:@selector(_loadProfile) withObject:nil afterDelay:2];
		_scrobbler = [[Scrobbler alloc] init];
	} else {
		[self showFirstRunView:NO];
	}
	
	[window makeKeyAndVisible];
}
- (IBAction)loveButtonPressed:(UIButton *)sender {
	NSDictionary *track = [self trackInfo];
	if(_scrobbler && track) {
		if(sender.alpha == 1) {
			[_scrobbler rateTrack:[track objectForKey:@"title"]
									 byArtist:[track objectForKey:@"creator"]
										onAlbum:[track objectForKey:@"album"]
							withStartTime:[[track objectForKey:@"startTime"] intValue]
							 withDuration:[[track objectForKey:@"duration"] intValue]
								 fromSource:[track objectForKey:@"source"]
										 rating:@"L"];
			sender.alpha = 0.4;
		} else {
			[_scrobbler rateTrack:[track objectForKey:@"title"]
									 byArtist:[track objectForKey:@"creator"]
										onAlbum:[track objectForKey:@"album"]
							withStartTime:[[track objectForKey:@"startTime"] intValue]
							 withDuration:[[track objectForKey:@"duration"] intValue]
								 fromSource:[track objectForKey:@"source"]
										 rating:@""];
			sender.alpha = 1;
		}
	}
}
- (IBAction)banButtonPressed:(UIButton *)sender {
	NSDictionary *track = [self trackInfo];
	if(_scrobbler && track) {
		[_scrobbler rateTrack:[track objectForKey:@"title"]
								 byArtist:[track objectForKey:@"creator"]
									onAlbum:[track objectForKey:@"album"]
						withStartTime:[[track objectForKey:@"startTime"] intValue]
						 withDuration:[[track objectForKey:@"duration"] intValue]
							 fromSource:[track objectForKey:@"source"]
									 rating:@"B"];
		sender.alpha = 0.4;
	}
	[[LastFMRadio sharedInstance] skip];
}
- (IBAction)skipButtonPressed:(id)sender {
	NSDictionary *track = [self trackInfo];
	if(_scrobbler && track) {
		[_scrobbler rateTrack:[track objectForKey:@"title"]
								 byArtist:[track objectForKey:@"creator"]
									onAlbum:[track objectForKey:@"album"]
						withStartTime:[[track objectForKey:@"startTime"] intValue]
						 withDuration:[[track objectForKey:@"duration"] intValue]
							 fromSource:[track objectForKey:@"source"]
									 rating:@"S"];
	}
	[[LastFMRadio sharedInstance] skip];
}
-(IBAction)stopButtonPressed:(id)sender {
	[[LastFMRadio sharedInstance] stop];
	[self hidePlaybackView];
}
-(BOOL)isPlaying {
	return [[LastFMRadio sharedInstance] state] != RADIO_IDLE;
}
-(NSDictionary *)trackInfo {
	if([[LastFMRadio sharedInstance] state] != RADIO_IDLE) {
		NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:[[LastFMRadio sharedInstance] trackInfo]];
		[info setObject:[NSString stringWithFormat:@"L%@", [info objectForKey:@"trackauth"]] forKey:@"source"];
		[info setObject:[[LastFMRadio sharedInstance] station] forKey:@"station"];
		[info setObject:[NSNumber numberWithDouble:[[LastFMRadio sharedInstance] startTime]] forKey:@"startTime"];
		return info;
	} else {
		return nil;
	}
}
-(int) radioState {
	return [[LastFMRadio sharedInstance] state];
}
-(int)trackPosition {
	if([[LastFMRadio sharedInstance] state] != RADIO_IDLE) {
		return [[LastFMRadio sharedInstance] trackPosition];
	} else {
		return 0;
	}
}
-(BOOL)hasNetworkConnection {
	SCNetworkReachabilityRef reach = SCNetworkReachabilityCreateWithName(kCFAllocatorSystemDefault, "ws.audioscrobbler.com");
	SCNetworkReachabilityFlags flags;
	SCNetworkReachabilityGetFlags(reach, &flags);
	BOOL ret = (kSCNetworkReachabilityFlagsReachable & flags) || (kSCNetworkReachabilityFlagsConnectionRequired & flags);
	CFRelease(reach);
	reach = nil;
	return ret;
}
-(BOOL)hasWiFiConnection {
	SCNetworkReachabilityRef reach = SCNetworkReachabilityCreateWithName(kCFAllocatorSystemDefault, "ws.audioscrobbler.com");
	SCNetworkReachabilityFlags flags;
	SCNetworkReachabilityGetFlags(reach, &flags);
	BOOL ret = (kSCNetworkFlagsReachable & flags) && !(kSCNetworkReachabilityFlagsIsWWAN & flags);
	CFRelease(reach);
	reach = nil;
	return ret;
}
-(NSURLRequest *)requestWithURL:(NSURL *)url { 
	NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url]; 
	[req setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
	[req setTimeoutInterval:[self hasWiFiConnection]?40:60];
	return req; 
} 
- (void)reportError:(NSError *)error {
	NSLog(@"Error encountered: %@\n", error);
	if([[LastFMService sharedInstance].error.domain isEqualToString:NSURLErrorDomain]) {
		[self displayError:NSLocalizedString(@"ERROR_NONETWORK", @"Network error") withTitle:NSLocalizedString(@"ERROR_NONETWORK_TITLE", @"Network error title")];
		return;
	} else if([[LastFMService sharedInstance].error.domain isEqualToString:LastFMServiceErrorDomain]) {
		switch([LastFMService sharedInstance].error.code) {
			case errorCodeInvalidAPIKey:
				[self displayError:NSLocalizedString(@"ERROR_UPGRADE", @"Upgrade required error") withTitle:NSLocalizedString(@"ERROR_UPGRADE_TITLE", @"Upgrade required error title")];
				return;
			case errorCodeAuthenticationFailed:
			case errorCodeInvalidSession:
				[self performSelectorOnMainThread:@selector(_logout) withObject:nil waitUntilDone:YES];
				[self displayError:NSLocalizedString(@"ERROR_SESSION", @"Invalid session error") withTitle:NSLocalizedString(@"ERROR_SESSION_TITLE", @"Invalid session error title")];
				return;
			case errorCodeSubscribersOnly:
				[self displayError:NSLocalizedString(@"ERROR_SUBSCRIPTION", @"Subscription required error") withTitle:NSLocalizedString(@"ERROR_SUBSCRIPTION_TITLE", @"Subscription required error title")];
				return;
		}
	}
	[self displayError:NSLocalizedString(@"ERROR_SERVER_UNAVAILABLE", @"Servers are temporarily unavailable") withTitle:NSLocalizedString(@"ERROR_SERVER_UNAVAILABLE_TITLE", @"Servers are temporarily unavailable title")];
}
- (BOOL)playRadioStation:(NSString *)station animated:(BOOL)animated {
	NSLog(@"Playing radio station: %@\n", station);
	if(!(([[LastFMRadio sharedInstance] state] != RADIO_IDLE) && [[[LastFMRadio sharedInstance] stationURL] isEqualToString:station])) {
		if([[LastFMRadio sharedInstance] state] != RADIO_IDLE) {
			[[LastFMRadio sharedInstance] stop];
		}
		if(![[LastFMRadio sharedInstance] selectStation:station]) {
			if([[LastFMService sharedInstance].error.domain isEqualToString:LastFMServiceErrorDomain] && [LastFMService sharedInstance].error.code >= 20)
				switch([LastFMService sharedInstance].error.code) {
					case errorCodeNotEnoughContent:
						[self displayError:NSLocalizedString(@"ERROR_INSUFFICIENT_CONTENT", @"Not enough content") withTitle:NSLocalizedString(@"ERROR_STATION_TITLE", @"Station unavailable title")];
						break;
					case errorCodeNotEnoughMembers:
						[self displayError:NSLocalizedString(@"ERROR_INSUFFICIENT_MEMBERS", @"Not enough members") withTitle:NSLocalizedString(@"ERROR_STATION_TITLE", @"Station unavailable title")];
						break;
					case errorCodeNotEnoughFans:
						[self displayError:NSLocalizedString(@"ERROR_INSUFFICIENT_FANS", @"Not enough fans") withTitle:NSLocalizedString(@"ERROR_STATION_TITLE", @"Station unavailable title")];
						break;
					case errorCodeNotEnoughNeighbours:
						[self displayError:NSLocalizedString(@"ERROR_INSUFFICIENT_NEIGHBOURS", @"Not enough neighbours") withTitle:NSLocalizedString(@"ERROR_STATION_TITLE", @"Station unavailable title")];
						break;
				}
			else
				[self reportError:[LastFMService sharedInstance].error];
			return FALSE;
		}
		if(![[LastFMRadio sharedInstance] play]) {
			return FALSE;
		}
	}
	if(animated) {
		[self showPlaybackView];
	}
	return TRUE;
}
-(void)showPlaybackView {
	[playbackViewController hideDetailsView];
	[rootViewController pushViewController:playbackViewController animated:YES];
}
-(void)hidePlaybackView {
	[rootViewController popViewControllerAnimated:YES];
	[_scrobbler flushQueue:nil];
}
-(void)displayError:(NSString *)error withTitle:(NSString *)title {
	_pendingAlert = [[UIAlertView alloc] initWithTitle:title message:error delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"OK") otherButtonTitles:nil];
	if(!_locked)
		[_pendingAlert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
}
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
	if([url.scheme isEqualToString:@"lastfm"]) {
		if([url.host isEqualToString:@"registration"]) {
			NSArray *args = [url.path componentsSeparatedByString:@"/"];
			[[NSUserDefaults standardUserDefaults] setObject:[args objectAtIndex:1] forKey:@"lastfm_user"];
			if([args count] == 3) {
				[[NSUserDefaults standardUserDefaults] setObject:[args objectAtIndex:2] forKey:@"lastfm_session"];
				[self showProfileView:NO];
			} else {
				[self showFirstRunView:NO];
			}
			[[NSUserDefaults standardUserDefaults] synchronize];
		} else {
			_launchURL = [[url absoluteString] retain];
		}
		return TRUE;
	} else {
		return FALSE;
	}
}
- (void)dealloc {
	[window release];
	[super dealloc];
}
@end
