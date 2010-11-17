/* MobileLastFMApplication.m - Main application controller
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

#import "NSString+MD5.h"
#import "MobileLastFMApplicationDelegate.h"
#import "ProfileViewController.h"
#import "RadioListViewController.h"
#import "PlaybackViewController.h"
#import "EventsTabViewController.h"
#include "version.h"
#include <SystemConfiguration/SCNetworkReachability.h>
#import "NSString+URLEscaped.h"
#import "NSData+Compress.h"
#import "TagRadioViewController.h"
#if !(TARGET_IPHONE_SIMULATOR)
#import "Beacon.h"
#endif

NSString *kUserAgent;

@implementation MobileLastFMApplicationDelegate

@synthesize window;
@synthesize firstRunView;
@synthesize playbackViewController;
@synthesize rootViewController;

- (void)applicationWillTerminate:(UIApplication *)application {
#if !(TARGET_IPHONE_SIMULATOR)
	[[Beacon shared] endBeacon];
#endif
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
																														 @"NO", @"showneighborradio",
																														 @"64", @"bitrate",
																														 nil]];
		if(![[[NSUserDefaults standardUserDefaults] objectForKey:@"scrobbling"] isKindOfClass:[NSString class]])
			[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"scrobbling"];
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:@"removeLovedTracks"];
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
	if(playbackViewController != nil)
		[playbackViewController resignActive];
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
	_locked = NO;
	if(_pendingAlert)
		[_pendingAlert show];
	if(_hidPlaybackDueToLowMemory) {
		for(NSObject *object in [[NSBundle mainBundle] loadNibNamed:@"PlaybackView" owner:self options:nil]) {
			if([object isKindOfClass:[PlaybackViewController class]]) {
				playbackViewController = [object retain];
				break;
			}
		}
		if(!playbackViewController) {
			NSLog(@"Failed to load playback view!\n");
		}
		[rootViewController pushViewController:playbackViewController animated:NO];
		_hidPlaybackDueToLowMemory = NO;
	}
	if(playbackViewController != nil)
		[playbackViewController becomeActive];
}
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
	if(playbackViewController != nil) {
		NSLog(@"Low memory, releasing details view controller");
		if([playbackViewController releaseDetailsView])
			return;
	}
	NSLog(@"Low memory, cancelling prebuffering");
	if([[LastFMRadio sharedInstance] cancelPrebuffering])
		return;
	
	if(_locked && playbackViewController) {
		NSLog(@"Low memory, popping playback view as last resort");
		[rootViewController popViewControllerAnimated:NO];
		[playbackViewController release];
		playbackViewController = nil;
		_hidPlaybackDueToLowMemory = YES;
	}
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
	
	[NSURLConnection sendSynchronousRequest:theRequest returningResponse:&theResponse error:&theError];

	if([theResponse statusCode] == 200 || [theResponse statusCode] == 404) {
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
	if([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Read About the Changes"])
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.last.fm/stationchanges2010"]];
	if([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Continue to Station"]) {
		[self showPlaybackView];
		[self performSelector:@selector(_playRadioStation:) withObject:_dmcaAlertStation afterDelay:2];
	}
	if([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Don't Warn Again"]) {
		[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"hidedmcawarning"];
		[self _playRadioStation:_dmcaAlertStation animated:YES];
	}
	if([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Remove Station"]) {
		if([_dmcaAlertStation hasPrefix:@"lastfm://usertags/"]) {
			[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"removeUserTags"];
		} else if([_dmcaAlertStation hasPrefix:@"lastfm://playlist/"]) {
			[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"removePlaylists"];
		} else if([_dmcaAlertStation hasSuffix:@"/loved"]) {
			[[NSUserDefaults standardUserDefaults] setObject:@"YES" forKey:@"removeLovedTracks"];
		}
		[radioListViewController rebuildMenu];
		if([[rootViewController topViewController] isKindOfClass:[TagRadioViewController class]]) {
			[rootViewController popViewControllerAnimated:YES];
		}
	}

	if(_pendingAlert) {
		[_pendingAlert release];
		_pendingAlert = nil;
	}
	if(_dmcaAlert) {
		[_dmcaAlert release];
		_dmcaAlert = nil;
		[_dmcaAlertStation release];
		_dmcaAlertStation = nil;
	}
}
- (UITabBarController *)profileViewForUser:(NSString *)username {
	UITabBarController *tabBarController = [[UITabBarController alloc] init];
	tabBarController.title = username;
	radioListViewController = [[RadioListViewController alloc] initWithUsername:username];
	UITabBarItem *t = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Radio", @"Radio tab label") image:[UIImage imageNamed:@"radio_icon_tab.png"] tag:0];
	radioListViewController.tabBarItem = t;
	[t release];
	
	ProfileViewController *p = [[ProfileViewController alloc] initWithUsername:username];
	t = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Profile", @"Profile tab label") image:[UIImage imageNamed:@"profile_icon_tab.png"] tag:1];
	p.tabBarItem = t;
	[t release];

	EventsTabViewController *e = [[EventsTabViewController alloc] initWithUsername:username];
	t = [[UITabBarItem alloc] initWithTitle:@"Events" image:[UIImage imageNamed:@"events.png"] tag:2];
	e.tabBarItem = t;
	[t release];
	
	tabBarController.viewControllers = [NSArray arrayWithObjects:radioListViewController, p, e, nil];
	[radioListViewController release];
	[p release];
	[e release];
	
	return [tabBarController autorelease];
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

	/*if([[NSUserDefaults standardUserDefaults] objectForKey:@"crashed"]) {
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"CRASH_REPORT_TITLE", @"Crash reporter title")
																										 message:NSLocalizedString(@"CRASH_REPORT_BODY",@"Crash reporter body")
																										delegate:self
																					 cancelButtonTitle:NSLocalizedString(@"Cancel", @"cancel")
																					 otherButtonTitles:NSLocalizedString(@"Send", @"Send"), nil] autorelease];
		[alert show];
	}*/
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
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#if !(TARGET_IPHONE_SIMULATOR)
	[Beacon initAndStartBeaconWithApplicationCode:PINCHMEDIA_ID useCoreLocation:NO useOnlyWiFi:NO];
#endif
	_mainView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[window addSubview:_mainView];

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
	return YES;
}
- (IBAction)loveButtonPressed:(UIButton *)sender {
#if !(TARGET_IPHONE_SIMULATOR)
	[[Beacon shared] startSubBeaconWithName:@"love" timeSession:NO];
#endif
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
#if !(TARGET_IPHONE_SIMULATOR)
	[[Beacon shared] startSubBeaconWithName:@"ban" timeSession:NO];
#endif
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
#if !(TARGET_IPHONE_SIMULATOR)
	[[Beacon shared] startSubBeaconWithName:@"skip" timeSession:NO];
#endif
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
- (BOOL)_playRadioStation:(NSString *)station {
	if(![[LastFMRadio sharedInstance] play]) {
		return FALSE;
	}
	return TRUE;
}
- (BOOL)playRadioStation:(NSString *)station animated:(BOOL)animated {
	NSLog(@"Playing radio station: %@\n", station);
	
	if(!_dmcaAlert && !(([[LastFMRadio sharedInstance] state] != RADIO_IDLE) && [[[LastFMRadio sharedInstance] stationURL] isEqualToString:station])) {
		if([[LastFMRadio sharedInstance] state] != RADIO_IDLE) {
			[[LastFMRadio sharedInstance] stop];
		}
		if(![[LastFMRadio sharedInstance] selectStation:station]) {
			if([[LastFMService sharedInstance].error.domain isEqualToString:LastFMServiceErrorDomain] && [LastFMService sharedInstance].error.code >= 20) {
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
					case errorCodeDeprecated:
						if([station hasPrefix:@"lastfm://usertags/"]) {
							_dmcaAlert = [[UIAlertView alloc] initWithTitle:@"Station No Longer Available" 
																											message:@"Due to recent station changes, 'personal tag' radio is no longer available.\n\n(Don't worry, your tags haven't changed)." 
																										 delegate:self cancelButtonTitle:@"Remove Station" otherButtonTitles:nil];
						} else if([station hasPrefix:@"lastfm://playlist/"]) {
							_dmcaAlert = [[UIAlertView alloc] initWithTitle:@"Station No Longer Available"
																											message:@"Due to recent station changes, playlists are no longer available.\n\n(Don't worry, the list of tracks in your playlists haven't changed)." 
																										 delegate:self cancelButtonTitle:@"Remove Station" otherButtonTitles:nil];
						} else if([station hasSuffix:@"/loved"]) {
							_dmcaAlert = [[UIAlertView alloc] initWithTitle:@"Station No Longer Available" 
																											message:@"Due to recent station changes, 'loved tracks' radio is no longer available.\n\n(Don't worry, your list of loved tracks hasn't changed)." 
																										 delegate:self cancelButtonTitle:@"Remove Station" otherButtonTitles:nil];
						}
						if(_dmcaAlert) {
							_dmcaAlertStation = [station retain];
							[_dmcaAlert show];
						}
						break;
				}
				return FALSE;
			}
			else
				[self reportError:[LastFMService sharedInstance].error];
			return FALSE;
		}
	}

	if(![(NSString *)[[NSUserDefaults standardUserDefaults] objectForKey:@"hidedmcawarning"] isEqualToString:@"YES"]
		 && ([station hasPrefix:@"lastfm://usertags/"] || [station hasPrefix:@"lastfm://playlist/"] || [station hasSuffix:@"/loved"])) {
		_dmcaAlert = [[UIAlertView alloc] initWithTitle:@"This Station is Changing" 
																						message:@"This station will soon be discontinued due to changes coming to Last.fm radio." 
																					 delegate:self cancelButtonTitle:@"Continue to Station" otherButtonTitles:@"Read About the Changes", @"Don't Warn Again", nil];
	}
	
	if(playbackViewController == nil) {
		for(NSObject *object in [[NSBundle mainBundle] loadNibNamed:@"PlaybackView" owner:self options:nil]) {
			if([object isKindOfClass:[PlaybackViewController class]]) {
				playbackViewController = [object retain];
				break;
			}
		}
		if(!playbackViewController) {
			NSLog(@"Failed to load playback view!\n");
		}
	}
	
	if(_dmcaAlert) {
		_dmcaAlertStation = [station retain];
		[_dmcaAlert show];
		return TRUE;
	} else {
		BOOL result = [self _playRadioStation:station];
		if(result && animated) {
			[self showPlaybackView];
		}
		return result;
	}
}
-(void)showPlaybackView {
	if(playbackViewController == nil) {
		for(NSObject *object in [[NSBundle mainBundle] loadNibNamed:@"PlaybackView" owner:self options:nil]) {
			if([object isKindOfClass:[PlaybackViewController class]]) {
				playbackViewController = [object retain];
				break;
			}
		}
		if(!playbackViewController) {
			NSLog(@"Failed to load playback view!\n");
		}
	}

	[playbackViewController hideDetailsView];
	[rootViewController pushViewController:playbackViewController animated:YES];
}
-(void)hidePlaybackView {
	[rootViewController popViewControllerAnimated:YES];
	[_scrobbler flushQueue:nil];
	[playbackViewController release];
	playbackViewController = nil;
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
