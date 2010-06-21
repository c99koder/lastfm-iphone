//
//  Beacon.h r91
//  Pinch Media Analytics Library
//
//  Created by Jesse Rohland on 4/6/08.
//  Copyright 2008 PinchMedia. All rights reserved.
//
//  Full documentation is available here:
//  <http://resources.pinchmedia.com/docs/pinch_analytics/iphone_documentation>
//
//  Help is available via <support@pinchmedia.com> or on the forum:
//  <http://resources.pinchmedia.com/forum/topics/39018>

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

// This is the key we respect in the user's preferences (NSUserDefaults) See:
// <http://resources.pinchmedia.com/docs/pinch_analytics/iphone_documentation/Analytics_OptOut_Preference>
#define kEnablePinchMediaStatsCollection @"kEnablePinchMediaStatsCollection"

@interface Beacon : NSObject <CLLocationManagerDelegate> {}

// Initialize the Beacon. There is now an optional fourth parameter, enableDebugMode, which
// will cause Beacon to log verbose information about what's going on internally.
+ (Beacon *)initAndStartBeaconWithApplicationCode:(NSString *)theApplicationCode
								  useCoreLocation:(BOOL)useCoreLocation
									  useOnlyWiFi:(BOOL)useOnlyWiFi
								  enableDebugMode:(BOOL)enableDebugMode;

// This is the same as above, but disables Debug mode by default. Left in for backwards compatibility.
+ (Beacon *)initAndStartBeaconWithApplicationCode:(NSString *)theApplicationCode
								  useCoreLocation:(BOOL)useCoreLocation
									  useOnlyWiFi:(BOOL)useOnlyWiFi;


// Terminate the Beacon session. Make this the last call in your UIApplication delegate's
// -applicationWillTerminate: method. [Beacon endBeacon] and [[Beacon shared] endBeacon] are equivalent.
+ (void)endBeacon;
- (void)endBeacon;

// Singleton access. (Sample usage: [[Beacon shared] startSubBeaconWithName:@"Capybara Radiated Majesty"])
+ (Beacon *)shared;

// Start an un-timed sub-beacon.
- (void)startSubBeaconWithName:(NSString *)subBeaconName;
// Start a timed sub-beacon.
- (void)startTimedSubBeaconWithName:(NSString *)subBeaconName;
// Start a sub-beacon with optional timing.
- (void)startSubBeaconWithName:(NSString *)subBeaconName timeSession:(BOOL)timeSession;

// End a timed sub-beacon. If you don't terminate it, it will automatically be terminated at endBeacon.
- (void)endSubBeaconWithName:(NSString *)subBeaconName;

// If your app uses CoreLocation, you can init Beacon with useCoreLocation:NO and then pass
// us a CLLocation* object once you've received a didUpdateToLocation: message. See:
// <http://resources.pinchmedia.com/docs/pinch_analytics/iPhone_Documentation#optimize-corelocation>
- (void)setBeaconLocation:(CLLocation *)newLocation;

@end
